// MARK: - MessagesViewModel.swift

import Foundation
import SwiftUI
import Combine

@MainActor
final class MessagesViewModel: ObservableObject {

    @Published var threads: [MessageThread] = []
    @Published var isLoading: Bool = false
    @Published var selectedThread: MessageThread? = nil
    @Published var errorMessage: String? = nil
    @Published var showComposeSheet: Bool = false

    let officerDirectory: [ThreadParticipant] = MockDSTService.loanOfficerDirectory()
    let connectableLeads: [LeadMessagingConnection] = MockDSTService.connectableLeads()

    var totalUnread: Int { threads.reduce(0) { $0 + $1.unreadCount } }
    var pendingConnectionCount: Int { max(connectableLeads.count - threads.filter { $0.participant.role != .system }.count, 0) }

    init() {
        Task { await loadThreads() }
    }

    func loadThreads() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 300_000_000)
        threads = MockDSTService.messageThreads().sorted {
            ($0.lastMessage?.sentAt ?? .distantPast) > ($1.lastMessage?.sentAt ?? .distantPast)
        }
        isLoading = false
    }

    func selectThread(_ thread: MessageThread) {
        selectedThread = threads.first(where: { $0.id == thread.id }) ?? thread
        markThreadAsRead(thread.id)
    }

    func markThreadAsRead(_ threadId: UUID) {
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
            messages: readMessages,
            linkedApplicationRef: updated.linkedApplicationRef,
            linkedLeadName: updated.linkedLeadName
        )
        selectedThread = threads[idx]
    }

    func updateThread(_ threadId: UUID, messages: [ChatMessage]) {
        guard let idx = threads.firstIndex(where: { $0.id == threadId }) else { return }
        let updated = threads[idx]

        threads[idx] = MessageThread(
            id: updated.id,
            participant: updated.participant,
            messages: messages,
            linkedApplicationRef: updated.linkedApplicationRef,
            linkedLeadName: updated.linkedLeadName
        )

        moveThreadToTop(threadId)

        if selectedThread?.id == threadId {
            selectedThread = threads.first(where: { $0.id == threadId })
        }
    }

    func createThread(lead: LeadMessagingConnection, participant: ThreadParticipant, openingMessage: String) {
        let threadId = UUID()
        let systemMessage = ChatMessage(
            id: UUID(),
            threadId: threadId,
            senderId: UUID(),
            senderRole: .system,
            content: "DST connected \(lead.leadName) (\(lead.applicationRef)) with \(participant.name).",
            sentAt: Date().addingTimeInterval(-60),
            isRead: true,
            attachmentRef: nil
        )

        var messages = [systemMessage]
        let trimmed = openingMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            messages.append(
                ChatMessage(
                    id: UUID(),
                    threadId: threadId,
                    senderId: UUID(),
                    senderRole: .dstAgent,
                    content: trimmed,
                    sentAt: Date(),
                    isRead: true,
                    attachmentRef: nil
                )
            )
        }

        let thread = MessageThread(
            id: threadId,
            participant: participant,
            messages: messages,
            linkedApplicationRef: lead.applicationRef,
            linkedLeadName: lead.leadName
        )

        threads.insert(thread, at: 0)
    }

    private func moveThreadToTop(_ threadId: UUID) {
        guard let index = threads.firstIndex(where: { $0.id == threadId }) else { return }
        let thread = threads.remove(at: index)
        threads.insert(thread, at: 0)
    }
}

@MainActor
final class ChatViewModel: ObservableObject {

    let thread: MessageThread
    private let onMessagesUpdated: ([ChatMessage]) -> Void

    @Published var messages: [ChatMessage]
    @Published var draftText: String = ""

    private let agentId = UUID()

    init(thread: MessageThread, onMessagesUpdated: @escaping ([ChatMessage]) -> Void = { _ in }) {
        self.thread = thread
        self.onMessagesUpdated = onMessagesUpdated
        self.messages = thread.messages
    }

    var navigationTitle: String { thread.participant.name }
    var navigationSubtitle: String { thread.participant.role.rawValue }
    var linkedLeadSummary: String? {
        guard let lead = thread.linkedLeadName, let ref = thread.linkedApplicationRef else { return nil }
        return "\(lead) · \(ref)"
    }

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

    func sendMessage() {
        guard canSend else { return }
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        draftText = ""

        let newMessage = ChatMessage(
            id: UUID(),
            threadId: thread.id,
            senderId: agentId,
            senderRole: .dstAgent,
            content: text,
            sentAt: Date(),
            isRead: true,
            attachmentRef: nil
        )

        withAnimation(.easeOut(duration: 0.2)) {
            messages.append(newMessage)
        }
        onMessagesUpdated(messages)
    }

    func sendAttachment(fileName: String) {
        let newMessage = ChatMessage(
            id: UUID(),
            threadId: thread.id,
            senderId: agentId,
            senderRole: .dstAgent,
            content: fileName,
            sentAt: Date(),
            isRead: true,
            attachmentRef: fileName
        )

        withAnimation(.easeOut(duration: 0.2)) {
            messages.append(newMessage)
        }
        onMessagesUpdated(messages)
    }
}
