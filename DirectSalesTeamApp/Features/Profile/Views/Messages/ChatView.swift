// MARK: - ChatView.swift

import SwiftUI
import PhotosUI

struct ChatView: View {

    @StateObject var vm: ChatViewModel
    @FocusState private var inputFocused: Bool
    @State private var selectedAttachment: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(vm.groupedMessages, id: \.date) { group in
                            DateSeparator(label: group.date)

                            ForEach(group.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                }
                .background(ChatBackdrop())
                .onAppear {
                    scrollToBottom(proxy: proxy, animated: false)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: inputFocused) { _, focused in
                    if focused { scrollToBottom(proxy: proxy) }
                }
            }

            composerBar
        }
        .background(Color(hex: "#111B21"))
        .navigationTitle(vm.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(vm.navigationTitle)
                        .font(.headline)
                    Text(vm.navigationSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.brandBlue)
                }
            }
        }
    }

    private var chatHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = vm.linkedLeadSummary {
                HStack(spacing: 8) {
                    Label("Connected", systemImage: "link.circle.fill")
                        .font(AppFont.captionMed())
                        .foregroundColor(Color(hex: "#B8E986"))
                    Text(summary)
                        .font(AppFont.caption())
                        .foregroundColor(.white.opacity(0.86))
                        .lineLimit(1)
                }
            }

            Text("Direct Sales Team and loan officer are now connected in this thread.")
                .font(AppFont.subhead())
                .foregroundColor(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Color(hex: "#15232C"))
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(
                selection: $selectedAttachment,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.10), in: Circle())
            }
            .onChange(of: selectedAttachment) { newItem in
                guard newItem != nil else { return }
                vm.sendAttachment(fileName: "Document Attachment")
                selectedAttachment = nil
            }

            TextField("Message...", text: $vm.draftText, axis: .vertical)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .focused($inputFocused)
                .lineLimit(1...5)
                .foregroundStyle(.white)

            Button(action: vm.sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        vm.canSend ? Color(hex: "#1F7A5A") : Color.white.opacity(0.12),
                        in: Circle()
                    )
            }
            .disabled(!vm.canSend)
            .animation(.easeInOut(duration: 0.15), value: vm.canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "#111B21"))
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    private let maxBubbleWidth: CGFloat = 290

    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer()
                bubble
            } else {
                bubble
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    private var bubble: some View {
        VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 6) {
            if message.attachmentRef != nil {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(message.isFromMe ? .white.opacity(0.9) : Color(hex: "#7ED6B1"))
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            } else {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 4) {
                Spacer(minLength: 0)
                Text(message.timeString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))

                if message.isFromMe {
                    Image(systemName: "checkmark.double")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#9DE1D0"))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: maxBubbleWidth, alignment: message.isFromMe ? .trailing : .leading)
        .background(bubbleBackground)
        .clipShape(bubbleShape)
    }

    private var bubbleBackground: Color {
        if message.isFromMe {
            return Color(hex: "#1F6F57")
        } else if message.senderRole == .system {
            return Color.white.opacity(0.12)
        } else {
            return Color(hex: "#202C33")
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: message.isFromMe ? 18 : 6,
            bottomTrailingRadius: message.isFromMe ? 6 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )
    }
}

struct DateSeparator: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.28), in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }
}

struct ChatBackdrop: View {
    private let patternIcons = ["star", "heart", "bolt", "circle", "paperplane", "bubble.left"]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0A1014"), Color(hex: "#101A20")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geo in
                let columns = 6
                let rows = 12
                let xStep = geo.size.width / CGFloat(columns)
                let yStep = geo.size.height / CGFloat(rows)

                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<columns, id: \.self) { column in
                        Image(systemName: patternIcons[(row + column) % patternIcons.count])
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.white.opacity(0.045))
                            .position(
                                x: CGFloat(column) * xStep + xStep * 0.55,
                                y: CGFloat(row) * yStep + yStep * 0.55
                            )
                    }
                }
            }
        }
    }
}
