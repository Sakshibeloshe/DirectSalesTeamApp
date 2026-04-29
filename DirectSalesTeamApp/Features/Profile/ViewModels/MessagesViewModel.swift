// MARK: - MessagesViewModel.swift

import Foundation
import SwiftUI
import Combine

@MainActor
@available(iOS 18.0, *)
final class MessagesViewModel: ObservableObject {

    @Published var threads: [MessageThread] = []
    @Published var isLoading: Bool = false
    @Published var selectedThread: MessageThread? = nil
    @Published var errorMessage: String? = nil
    @Published var showComposeSheet: Bool = false

    // Backend-driven compose data
    @Published var eligibleParticipants: [ThreadParticipant] = []

    private let chatService: ChatServiceProtocol
    private var chatRooms: [ChatRoom] = []
    private var messageStreamTasks: [String: Task<Void, Never>] = [:]
    private var lastMessageIDByRoom: [String: String] = [:]
    private var lastRoomEventAt: [String: Date] = [:]
    private var currentUserID: String = ""
    private var userRolesCache: [String: String] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let heartbeatTimeout: TimeInterval = 90
    private let maxReconnectDelaySeconds: UInt64 = 30

    var totalUnread: Int { threads.reduce(0) { $0 + $1.unreadCount } }

    init(
        chatService: ChatServiceProtocol = ChatService()
    ) {
        self.chatService = chatService
        self.currentUserID = getCurrentUserID()
        Task { async let threads = loadThreads(); async let users = loadEligibleUsers(); await threads; await users }
    }

    private func loadEligibleUsers() async {
        do {
            let users = try await chatService.listEligibleUsers(query: "", limit: 50, offset: 0)
            let participants = users.map { user in
                ThreadParticipant(
                    id: user.id,
                    name: user.displayName,
                    role: ParticipantRole.from(protoRole: user.role)
                )
            }
            for user in users {
                userRolesCache[user.id] = user.role
            }
            await MainActor.run {
                self.eligibleParticipants = participants
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load contacts: \(error.localizedDescription)"
            }
        }
    }

    private func getCurrentUserID() -> String {
        guard let accessToken = try? TokenStore.shared.accessToken(),
              let userID = JWTClaimsDecoder.subject(from: accessToken) else {
            return ""
        }
        return userID
    }

    deinit {
        messageStreamTasks.values.forEach { $0.cancel() }
    }

    func loadThreads() async {
        isLoading = true
        errorMessage = nil

        do {
            let rooms = try await chatService.listMyChatRooms(limit: 50, offset: 0)

            // Cancel streams for rooms no longer present
            let currentRoomIDs = Set(rooms.map(\.id))
            for roomID in messageStreamTasks.keys where !currentRoomIDs.contains(roomID) {
                messageStreamTasks[roomID]?.cancel()
                messageStreamTasks.removeValue(forKey: roomID)
            }

            chatRooms = rooms

            var convertedThreads: [MessageThread] = []
            for room in rooms {
                if let thread = await convertToMessageThread(room: room) {
                    convertedThreads.append(thread)
                }
            }
            threads = convertedThreads.sorted {
                ($0.lastMessage?.sentAt ?? .distantPast) > ($1.lastMessage?.sentAt ?? .distantPast)
            }

            for room in rooms {
                startStreaming(for: room)
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func startStreaming(for room: ChatRoom) {
        // Cancel existing stream for this room before starting a new one
        messageStreamTasks[room.id]?.cancel()

        let task = Task {
            var attempt = 0
            while !Task.isCancelled {
                let afterMessageID = await MainActor.run { self.lastMessageIDByRoom[room.id] }
                let stream = chatService.subscribeToRoomMessages(roomID: room.id, afterMessageID: afterMessageID)

                do {
                    self.lastRoomEventAt[room.id] = Date()
                    for try await event in stream {
                        if Task.isCancelled { break }
                        self.lastRoomEventAt[room.id] = Date()

                        if !event.isHeartbeat, let newMessage = event.message {
                            await MainActor.run {
                                self.mergeIncomingMessage(protoMessage: newMessage, roomID: room.id)
                            }
                        }

                        if let lastEventAt = self.lastRoomEventAt[room.id], Date().timeIntervalSince(lastEventAt) > self.heartbeatTimeout {
                            throw ChatError.networkError("Stream heartbeat timeout")
                        }
                    }
                    break
                } catch {
                    if Task.isCancelled { break }
                    await reconcileRoomMessages(roomID: room.id)
                    attempt += 1
                    let delaySeconds = min(UInt64(1 << min(attempt, 5)), maxReconnectDelaySeconds)
                    try? await Task.sleep(nanoseconds: (delaySeconds * 1_000_000_000) + UInt64.random(in: 0...500_000_000))
                }
            }
        }
        messageStreamTasks[room.id] = task
    }

    private func reconcileRoomMessages(roomID: String) async {
        do {
            let protoMessages = try await chatService.listRoomMessages(roomID: roomID, limit: 50, offset: 0)
            let convertedMessages = normalizeMessages(protoMessages.map(convertToChatMessage(protoMessage:)))
            await MainActor.run {
                self.updateThreadMessages(roomID: roomID, mergedWith: convertedMessages)
                self.lastMessageIDByRoom[roomID] = self.latestMessageID(from: self.threadMessages(roomID: roomID))
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func convertToMessageThread(room: ChatRoom) async -> MessageThread? {
        let participantID = room.otherUserID(currentUserID: currentUserID)
        let participantName: String
        let participantRole: ParticipantRole

        if let cached = eligibleParticipants.first(where: { $0.id == participantID }) {
            participantName = cached.name
            participantRole = cached.role
        } else {
            participantName = "User"
            participantRole = .loanOfficer
        }
        let participant = ThreadParticipant(id: participantID, name: participantName, role: participantRole)

        var messages: [ChatMessage] = []
        do {
            let protoMessages = try await chatService.listRoomMessages(
                roomID: room.id,
                limit: 50,
                offset: 0
            )
            messages = normalizeMessages(protoMessages.map(convertToChatMessage(protoMessage:)))
            lastMessageIDByRoom[room.id] = latestMessageID(from: messages)
        } catch {
            // Continue with empty messages on error
        }

        return MessageThread(
            id: room.id,
            participant: participant,
            messages: messages
        )
    }

    private func convertToChatMessage(protoMessage: ChatDomainMessage) -> ChatMessage {
        let senderRole: ParticipantRole
        if let cachedRole = userRolesCache[protoMessage.senderUserID] {
            senderRole = ParticipantRole.from(protoRole: cachedRole)
        } else {
            senderRole = protoMessage.senderUserID == currentUserID ? .dstAgent : .loanOfficer
        }

        return ChatMessage(
            id: protoMessage.id,
            threadId: protoMessage.roomID,
            senderId: protoMessage.senderUserID,
            senderRole: senderRole,
            content: protoMessage.body,
            sentAt: protoMessage.createdAt,
            isRead: true,
            attachmentRef: protoMessage.metadataJSON.isEmpty ? nil : protoMessage.metadataJSON
        )
    }

    private func normalizeMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        var byID: [String: ChatMessage] = [:]
        for message in messages {
            byID[message.id] = message
        }
        return byID.values.sorted {
            if $0.sentAt != $1.sentAt { return $0.sentAt < $1.sentAt }
            return $0.id < $1.id
        }
    }

    private func latestMessageID(from messages: [ChatMessage]) -> String? {
        normalizeMessages(messages).last?.id
    }

    private func threadMessages(roomID: String) -> [ChatMessage] {
        threads.first(where: { $0.id == roomID })?.messages ?? []
    }

    private func updateThreadMessages(roomID: String, mergedWith incoming: [ChatMessage]) {
        guard let threadIdx = threads.firstIndex(where: { $0.id == roomID }) else { return }
        let current = threads[threadIdx]
        let merged = normalizeMessages(current.messages + incoming)
        threads[threadIdx] = MessageThread(
            id: current.id,
            participant: current.participant,
            messages: merged
        )
        if selectedThread?.id == roomID {
            selectedThread = threads[threadIdx]
        }
    }

    private func mergeIncomingMessage(protoMessage: ChatDomainMessage, roomID: String) {
        if let idx = chatRooms.firstIndex(where: { $0.id == roomID }) {
            let updatedRoom = chatRooms[idx]
            chatRooms[idx] = ChatRoom(
                id: updatedRoom.id,
                roomType: updatedRoom.roomType,
                userAID: updatedRoom.userAID,
                userBID: updatedRoom.userBID,
                createdByUserID: updatedRoom.createdByUserID,
                createdAt: updatedRoom.createdAt,
                updatedAt: Date(),
                latestMessage: protoMessage
            )
        }

        let converted = convertToChatMessage(protoMessage: protoMessage)
        updateThreadMessages(roomID: roomID, mergedWith: [converted])
        lastMessageIDByRoom[roomID] = latestMessageID(from: threadMessages(roomID: roomID))
        moveThreadToTop(roomID)
    }

    func selectThread(_ thread: MessageThread) {
        selectedThread = threads.first(where: { $0.id == thread.id }) ?? thread
        markThreadAsRead(thread.id)
    }

    func markThreadAsRead(_ threadId: String) {
        guard let idx = threads.firstIndex(where: { $0.id == threadId }) else { return }
        let updated = threads[idx]

        let readMessages = updated.messages.map { message -> ChatMessage in
            var copy = message
            if copy.senderRole != .dstAgent {
                copy.isRead = true
            }
            return copy
        }

        threads[idx] = MessageThread(
            id: updated.id,
            participant: updated.participant,
            messages: readMessages
        )
        selectedThread = threads[idx]
    }

    func updateThread(_ threadId: String, messages: [ChatMessage]) {
        guard let idx = threads.firstIndex(where: { $0.id == threadId }) else { return }
        let updated = threads[idx]

        threads[idx] = MessageThread(
            id: updated.id,
            participant: updated.participant,
            messages: normalizeMessages(messages)
        )

        moveThreadToTop(threadId)

        if selectedThread?.id == threadId {
            selectedThread = threads.first(where: { $0.id == threadId })
        }
    }

    func createThread(participant: ThreadParticipant, openingMessage: String) async {
        do {
            let room = try await chatService.createOrGetDirectRoom(
                targetUserID: participant.id
            )

            // Avoid duplicate thread insertion
            if threads.contains(where: { $0.id == room.id }) {
                await MainActor.run {
                    if let existing = threads.first(where: { $0.id == room.id }) {
                        selectedThread = existing
                    }
                }
                return
            }

            if var thread = await convertToMessageThread(room: room) {
                let trimmed = openingMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    do {
                        let sentMessage = try await chatService.sendMessage(
                            roomID: room.id,
                            body: trimmed,
                            messageType: .text,
                            metadataJSON: nil
                        )
                        let chatMsg = convertToChatMessage(protoMessage: sentMessage)
                        thread = MessageThread(
                            id: thread.id,
                            participant: thread.participant,
                            messages: normalizeMessages(thread.messages + [chatMsg])
                        )
                    } catch {
                        await MainActor.run {
                            self.errorMessage = "Room created but message failed: \(error.localizedDescription)"
                        }
                    }
                }

                await MainActor.run {
                    self.threads.insert(thread, at: 0)
                    self.chatRooms.append(room)
                    self.selectedThread = self.threads.first(where: { $0.id == thread.id })
                }
                startStreaming(for: room)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func moveThreadToTop(_ threadId: String) {
        guard let index = threads.firstIndex(where: { $0.id == threadId }) else { return }
        let thread = threads.remove(at: index)
        threads.insert(thread, at: 0)
    }

    func refresh() {
        Task { await loadThreads() }
    }
}

@MainActor
@available(iOS 18.0, *)
final class ChatViewModel: ObservableObject {

    let thread: MessageThread
    private let onMessagesUpdated: ([ChatMessage]) -> Void
    private let chatService: ChatServiceProtocol
    let roomID: String
    private var messageStreamTask: Task<Void, Never>?
    private var currentUserID: String = ""
    private var userRolesCache: [String: String] = [:]
    private var lastMessageID: String? = nil
    private var messageOffset: Int = 0
    private let messagePageSize: Int = 50
    private var lastEventAt: Date = Date()
    private let heartbeatTimeout: TimeInterval = 90
    private let maxReconnectDelaySeconds: UInt64 = 30
    @Published var hasMoreMessages: Bool = true

    @Published var messages: [ChatMessage]
    @Published var draftText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let agentId = "agent-dst"

    init(thread: MessageThread, chatService: ChatServiceProtocol = ChatService(), onMessagesUpdated: @escaping ([ChatMessage]) -> Void = { _ in }) {
        self.thread = thread
        self.chatService = chatService
        self.onMessagesUpdated = onMessagesUpdated
        self.messages = thread.messages
        self.roomID = thread.id
        self.currentUserID = getCurrentUserID()
        loadMessages()
        startStreaming()
    }

    private func getCurrentUserID() -> String {
        guard let accessToken = try? TokenStore.shared.accessToken(),
              let userID = JWTClaimsDecoder.subject(from: accessToken) else {
            return ""
        }
        return userID
    }

    deinit {
        messageStreamTask?.cancel()
    }

    var navigationTitle: String { thread.participant.name }
    var navigationSubtitle: String { thread.participant.role.rawValue }

    var canSend: Bool { !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var groupedMessages: [(date: String, messages: [ChatMessage])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: messages) { message -> String in
            if calendar.isDateInToday(message.sentAt) { return "Today" }
            if calendar.isDateInYesterday(message.sentAt) { return "Yesterday" }
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: message.sentAt)
        }

        let order = ["Yesterday", "Today"]
        let sorted = grouped.sorted { a, b in
            let ai = order.firstIndex(of: a.key) ?? -1
            let bi = order.firstIndex(of: b.key) ?? -1
            if ai >= 0 && bi >= 0 { return ai < bi }
            if ai >= 0 { return false }
            if bi >= 0 { return true }
            return a.key < b.key
        }

        return sorted.map { (date: $0.key, messages: $0.value.sorted { $0.sentAt < $1.sentAt }) }
    }

    private func loadMessages() {
        isLoading = true
        errorMessage = nil
        messageOffset = 0

        Task {
            do {
                let protoMessages = try await chatService.listRoomMessages(
                    roomID: roomID,
                    limit: messagePageSize,
                    offset: 0
                )
                let convertedMessages = protoMessages.map { proto in
                    convertToChatMessage(protoMessage: proto)
                }
                let normalized = normalizeMessages(convertedMessages)
                lastMessageID = normalized.last?.id
                hasMoreMessages = protoMessages.count >= messagePageSize
                messageOffset = protoMessages.count
                await MainActor.run {
                    self.messages = normalized
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func loadOlderMessages() {
        guard !isLoading && hasMoreMessages else { return }
        isLoading = true

        Task {
            do {
                let protoMessages = try await chatService.listRoomMessages(
                    roomID: roomID,
                    limit: messagePageSize,
                    offset: messageOffset
                )
                let convertedMessages = protoMessages.map { proto in
                    convertToChatMessage(protoMessage: proto)
                }
                hasMoreMessages = protoMessages.count >= messagePageSize
                messageOffset += protoMessages.count
                await MainActor.run {
                    self.messages = self.normalizeMessages(self.messages + convertedMessages)
                    self.lastMessageID = self.messages.last?.id
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func startStreaming() {
        messageStreamTask?.cancel()
        messageStreamTask = Task {
            var attempt = 0
            while !Task.isCancelled {
                let stream = chatService.subscribeToRoomMessages(roomID: roomID, afterMessageID: lastMessageID)
                do {
                    self.lastEventAt = Date()
                    for try await event in stream {
                        if Task.isCancelled { break }
                        self.lastEventAt = Date()

                        if !event.isHeartbeat, let newMessage = event.message {
                            await MainActor.run {
                                let convertedMessage = self.convertToChatMessage(protoMessage: newMessage)
                                self.messages = self.normalizeMessages(self.messages + [convertedMessage])
                                self.lastMessageID = self.messages.last?.id
                                self.onMessagesUpdated(self.messages)
                            }
                        }

                        if Date().timeIntervalSince(self.lastEventAt) > self.heartbeatTimeout {
                            throw ChatError.networkError("Stream heartbeat timeout")
                        }
                    }
                    break
                } catch {
                    if Task.isCancelled { break }
                    await reconcileLatestMessages()
                    attempt += 1
                    let delaySeconds = min(UInt64(1 << min(attempt, 5)), maxReconnectDelaySeconds)
                    try? await Task.sleep(nanoseconds: (delaySeconds * 1_000_000_000) + UInt64.random(in: 0...500_000_000))
                }
            }
        }
    }

    private func reconcileLatestMessages() async {
        do {
            let protoMessages = try await chatService.listRoomMessages(roomID: roomID, limit: messagePageSize, offset: 0)
            let convertedMessages = protoMessages.map { convertToChatMessage(protoMessage: $0) }
            await MainActor.run {
                self.messages = self.normalizeMessages(self.messages + convertedMessages)
                self.lastMessageID = self.messages.last?.id
                self.onMessagesUpdated(self.messages)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func normalizeMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        var byID: [String: ChatMessage] = [:]
        for message in messages {
            byID[message.id] = message
        }
        return byID.values.sorted {
            if $0.sentAt != $1.sentAt { return $0.sentAt < $1.sentAt }
            return $0.id < $1.id
        }
    }

    private func convertToChatMessage(protoMessage: ChatDomainMessage) -> ChatMessage {
        let senderRole: ParticipantRole
        if let cachedRole = userRolesCache[protoMessage.senderUserID] {
            senderRole = ParticipantRole.from(protoRole: cachedRole)
        } else {
            senderRole = protoMessage.senderUserID == currentUserID ? .dstAgent : .loanOfficer
        }

        return ChatMessage(
            id: protoMessage.id,
            threadId: protoMessage.roomID,
            senderId: protoMessage.senderUserID,
            senderRole: senderRole,
            content: protoMessage.body,
            sentAt: protoMessage.createdAt,
            isRead: true,
            attachmentRef: protoMessage.metadataJSON.isEmpty ? nil : protoMessage.metadataJSON
        )
    }

    func sendMessage() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard canSend else { return }
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        draftText = ""

        Task {
            do {
                let sentMessage = try await chatService.sendMessage(
                    roomID: roomID,
                    body: text,
                    messageType: .text,
                    metadataJSON: nil
                )
                let convertedMessage = convertToChatMessage(protoMessage: sentMessage)
                await MainActor.run {
                    self.messages = self.normalizeMessages(self.messages + [convertedMessage])
                    self.lastMessageID = self.messages.last?.id
                    self.onMessagesUpdated(self.messages)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.draftText = text
                }
            }
        }
    }

    func sendAttachment(fileName: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            do {
                let sentMessage = try await chatService.sendMessage(
                    roomID: roomID,
                    body: fileName,
                    messageType: .text,
                    metadataJSON: "{\"attachment\": \"\(fileName)\"}"
                )
                let convertedMessage = convertToChatMessage(protoMessage: sentMessage)
                await MainActor.run {
                    self.messages = self.normalizeMessages(self.messages + [convertedMessage])
                    self.lastMessageID = self.messages.last?.id
                    self.onMessagesUpdated(self.messages)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func refresh() {
        loadMessages()
    }
}
