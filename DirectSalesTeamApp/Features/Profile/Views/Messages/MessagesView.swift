// MARK: - MessagesView.swift

import SwiftUI

struct MessagesView: View {

    @ObservedObject var vm: MessagesViewModel
    @State private var draftParticipant: ThreadParticipant?
    @State private var draftLead: LeadMessagingConnection?
    @State private var openingMessage: String = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.surfaceSecondary.ignoresSafeArea()
                DSTHeaderGradientBackground(height: 230)

                Group {
                    if vm.isLoading {
                        ProgressView("Loading messages…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.threads.isEmpty {
                        VStack(spacing: AppSpacing.md) {
                            messagesHero
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.top, AppSpacing.sm)
                            emptyState
                                .padding(.horizontal, AppSpacing.md)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        ScrollView {
                            VStack(spacing: AppSpacing.md) {
                                messagesHero
                                if !vm.connectableLeads.isEmpty {
                                    ConnectionHubCard(
                                        pendingConnections: vm.connectableLeads.count,
                                        onAddMessage: { vm.showComposeSheet = true }
                                    )
                                }
                                threadList
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.sm)
                            .padding(.bottom, AppSpacing.xl)
                        }
                    }
                }
                .background(Color.clear)
                .navigationTitle("Messages")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { vm.showComposeSheet = true } label: {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
                .sheet(isPresented: $vm.showComposeSheet) {
                    NewConversationSheet(
                        participants: vm.eligibleParticipants,
                        leads: vm.connectableLeads,
                        selectedParticipant: $draftParticipant,
                        selectedLead: $draftLead,
                        openingMessage: $openingMessage,
                        onCreate: {
                            guard let participant = draftParticipant else { return }
                            let lead = draftLead
                            let message = openingMessage
                            draftParticipant = nil
                            draftLead = nil
                            openingMessage = ""
                            vm.showComposeSheet = false
                            Task {
                                await vm.createThread(
                                    lead: lead,
                                    participant: participant,
                                    openingMessage: message
                                )
                            }
                        }
                    )
                }
                .alert("Messages Error", isPresented: Binding(
                    get: { vm.errorMessage != nil },
                    set: { if !$0 { vm.errorMessage = nil } }
                )) {
                    Button("Retry") { vm.refresh() }
                    Button("Dismiss", role: .cancel) { vm.errorMessage = nil }
                } message: {
                    Text(vm.errorMessage ?? "")
                }
            }
        }
    }

    private var messagesHero: some View {
        DSTSurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                DSTSectionTitle("Conversation Hub", subtitle: "Keep every borrower and officer exchange clear, contextual, and easy to continue.")
                HStack(spacing: AppSpacing.md) {
                    summaryMetric(title: "Threads", value: "\(vm.threads.count)", color: Color.textPrimary)
                    summaryMetric(title: "Unread", value: "\(vm.totalUnread)", color: Color.brandBlue)
                    Spacer()
                }
            }
        }
    }

    private func summaryMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppFont.title2())
                .foregroundColor(color)
            Text(title)
                .font(AppFont.caption())
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(Color.brandBlueSoft.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private var threadList: some View {
        VStack(spacing: 12) {
            ForEach(vm.threads) { thread in
                NavigationLink {
                    ChatView(
                        vm: ChatViewModel(
                            thread: thread,
                            onMessagesUpdated: { messages in
                                vm.updateThread(thread.id, messages: messages)
                            }
                        )
                    )
                    .onAppear { vm.selectThread(thread) }
                } label: {
                    ThreadRow(thread: thread)
                }
                .buttonStyle(.plain)
            }

            Text("Messages are end-to-end monitored for compliance")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 38))
                .foregroundStyle(Color.brandBlue)
            VStack(spacing: AppSpacing.xs) {
                Text("No messages yet")
                    .font(AppFont.headline())
                    .foregroundColor(Color.textPrimary)
                Text("Connect a lead to a loan officer and the conversation will appear here.")
                    .font(AppFont.subhead())
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
            }
            Button {
                NotificationCenter.default.post(name: Notification.Name("DSTSwitchTab"), object: 0)
            } label: {
                Text("Go to Leads")
                    .font(AppFont.subheadMed())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.brandBlue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(Color.borderLight, lineWidth: 1)
        )
        .cardShadow()
    }
}

struct ThreadRow: View {
    let thread: MessageThread

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                ThreadAvatar(participant: thread.participant)
                if thread.unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.brandBlue)
                            .frame(width: 20, height: 20)
                        Text("\(thread.unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: -4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(thread.participant.name)
                        .font(.headline)
                        .fontWeight(thread.unreadCount > 0 ? .bold : .semibold)
                    Spacer()
                    Text(thread.lastMessageTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(thread.participant.role.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(thread.participant.role.color)

                if let lead = thread.linkedLeadName, let ref = thread.linkedApplicationRef {
                    Text("\(lead) · \(ref)")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }

                if let last = thread.lastMessage {
                    Text(last.content)
                        .font(.subheadline)
                        .foregroundStyle(thread.unreadCount > 0 ? .primary : .secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.borderLight, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .cardShadow()
    }
}

struct ConnectionHubCard: View {
    let pendingConnections: Int
    let onAddMessage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connect Leads To Loan Officers")
                        .font(AppFont.headline())
                        .foregroundColor(Color.textPrimary)
                    Text(
                        pendingConnections > 0
                            ? "\(pendingConnections) leads still need a messaging connection."
                            : "All active leads already have a live officer connection."
                    )
                    .font(AppFont.subhead())
                    .foregroundColor(Color.textSecondary)
                }
                Spacer()
                Image(systemName: "person.2.wave.2.fill")
                    .foregroundColor(Color.brandBlue)
            }

            Button(action: onAddMessage) {
                HStack {
                    Image(systemName: "plus.bubble.fill")
                    Text("Add Message")
                        .font(AppFont.bodyMedium())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.mainBlue, Color.secondaryBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.borderLight, lineWidth: 1)
        )
    }
}

struct NewConversationSheet: View {
    let participants: [ThreadParticipant]
    let leads: [LeadMessagingConnection]
    @Binding var selectedParticipant: ThreadParticipant?
    @Binding var selectedLead: LeadMessagingConnection?
    @Binding var openingMessage: String
    let onCreate: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var selectedRoleNeedsApplication: Bool {
        guard let participant = selectedParticipant else { return false }
        return participant.role == .borrower
    }

    private var canCreate: Bool {
        guard let participant = selectedParticipant else { return false }
        if participant.role == .borrower {
            return selectedLead != nil
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Start conversation with") {
                    if participants.isEmpty {
                        Text("Loading contacts…")
                            .foregroundStyle(.secondary)
                    } else {
                        NavigationLink {
                            ParticipantPickerList(
                                participants: participants,
                                selectedParticipant: $selectedParticipant
                            )
                        } label: {
                            HStack {
                                Text("Contact")
                                Spacer()
                                if let p = selectedParticipant {
                                    Text("\(p.name) · \(p.role.rawValue)")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Select a contact")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if selectedRoleNeedsApplication {
                    Section("Linked Application") {
                        if leads.isEmpty {
                            Text("No applications available for this borrower")
                                .foregroundStyle(.secondary)
                        } else {
                            NavigationLink {
                                LeadPickerList(
                                    leads: leads,
                                    selectedLead: $selectedLead
                                )
                            } label: {
                                HStack {
                                    Text("Application")
                                    Spacer()
                                    if let l = selectedLead {
                                        Text("\(l.leadName) · \(l.loanType)")
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Select application")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Opening Message") {
                    TextField("Share context for the conversation…", text: $openingMessage, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate()
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
        }
        .onChange(of: selectedParticipant?.id) { _, _ in
                    selectedLead = nil
                }
    }
}

struct LeadPickerList: View {
    let leads: [LeadMessagingConnection]
    @Binding var selectedLead: LeadMessagingConnection?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(leads) { lead in
            Button {
                selectedLead = lead
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lead.leadName)
                            .font(.body)
                        Text(lead.loanType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selectedLead?.id == lead.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.mainBlue)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Select Application")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ParticipantPickerList: View {
    let participants: [ThreadParticipant]
    @Binding var selectedParticipant: ThreadParticipant?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(participants) { participant in
            Button {
                selectedParticipant = participant
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(participant.name)
                            .font(.body)
                        Text(participant.role.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selectedParticipant?.id == participant.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.mainBlue)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Select Contact")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThreadAvatar: View {
    let participant: ThreadParticipant

    var bgColor: Color {
        switch participant.role {
        case .loanOfficer: return Color(red: 0.82, green: 0.87, blue: 0.97)
        case .manager: return Color(red: 0.9, green: 0.83, blue: 0.97)
        case .system: return Color(.secondarySystemFill)
        case .dstAgent: return Color(.secondarySystemFill)
        case .borrower: return Color(red: 0.85, green: 0.95, blue: 0.92)
        }
    }

    var fgColor: Color {
        switch participant.role {
        case .loanOfficer: return Color(red: 0.28, green: 0.4, blue: 0.78)
        case .manager: return .purple
        case .system: return .secondary
        case .dstAgent: return .secondary
        case .borrower: return Color(red: 0.0, green: 0.45, blue: 0.39)
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(bgColor).frame(width: 50, height: 50)
            Text(participant.initials)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(fgColor)
        }
    }
}
