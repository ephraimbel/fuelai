import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isLatestAssistant: Bool
    let onFinishTyping: (() -> Void)?
    var onLogFood: ((String) -> Void)?
    var onDirectLog: ((String, Int, Double, Double, Double) -> Void)?
    var onApplyEdit: ((MealEditData) -> Void)?
    var onLogWithAnalysis: ((FoodAnalysis) -> Void)?

    @State private var appeared = false
    @State private var showTimestamp = false
    @State private var revealedCharacters = 0
    @State private var typingTask: Task<Void, Never>?
    @State private var showCards = false
    @State private var cursorVisible = true
    @State private var typingFinished = false

    private var isUser: Bool { message.role == .user }
    private var isTyping: Bool { isLatestAssistant && revealedCharacters < message.content.count }

    init(message: ChatMessage, isLatestAssistant: Bool = false, onFinishTyping: (() -> Void)? = nil, onLogFood: ((String) -> Void)? = nil, onDirectLog: ((String, Int, Double, Double, Double) -> Void)? = nil, onApplyEdit: ((MealEditData) -> Void)? = nil, onLogWithAnalysis: ((FoodAnalysis) -> Void)? = nil) {
        self.message = message
        self.isLatestAssistant = isLatestAssistant
        self.onFinishTyping = onFinishTyping
        self.onLogFood = onLogFood
        self.onDirectLog = onDirectLog
        self.onApplyEdit = onApplyEdit
        self.onLogWithAnalysis = onLogWithAnalysis
    }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
            if isUser {
                userBubble
            } else {
                assistantBubble
            }

            // Timestamp on tap
            if showTimestamp {
                Text(message.createdAt.timeString)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(FuelColors.stone.opacity(0.5))
                    .padding(.horizontal, isUser ? 4 : 44)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(.horizontal, FuelSpacing.lg)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : (isUser ? 20 : -20))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appeared)
        .onAppear {
            appeared = true
            if message.role == .assistant && isLatestAssistant {
                startTypewriter()
            } else {
                revealedCharacters = message.content.count
                typingFinished = true
                showCards = true
            }
        }
        .onDisappear {
            typingTask?.cancel()
            typingTask = nil
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.content
                FuelHaptics.shared.tap()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                withAnimation(FuelAnimation.snappy) {
                    showTimestamp.toggle()
                }
            } label: {
                Label(showTimestamp ? "Hide Time" : "Show Time", systemImage: "clock")
            }
        }
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        Text(message.content)
            .font(.system(size: 15.5, weight: .regular))
            .foregroundStyle(.white)
            .lineSpacing(3)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(FuelColors.inkSurface)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 4,
                    topTrailingRadius: 18
                )
            )
            .containerRelativeFrame(.horizontal, alignment: .trailing) { width, _ in
                width * 0.75
            }
    }

    // MARK: - Assistant Bubble

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            // Fuel avatar
            Image("FlameIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                // Message text
                VStack(alignment: .leading, spacing: 0) {
                    if typingFinished {
                        // Render with markdown after typing completes
                        markdownText(message.content)
                    } else {
                        Text(typewriterText)
                            .font(.system(size: 15.5, weight: .regular))
                            .foregroundStyle(FuelColors.ink)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Typing cursor
                    if isTyping {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(FuelColors.flame)
                            .frame(width: 2, height: 16)
                            .opacity(cursorVisible ? 1 : 0.1)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: FuelRadius.lg)
                        .fill(FuelColors.cloud)
                )

                // Cards
                if let cards = message.cards, !cards.isEmpty, showCards {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        ChatCardView(card: card, onLogFood: onLogFood, onDirectLog: onDirectLog, onApplyEdit: onApplyEdit, onLogWithAnalysis: onLogWithAnalysis)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.1),
                                value: showCards
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in
            width * 0.85
        }
    }

    // MARK: - Markdown Rendering

    @ViewBuilder
    private func markdownText(_ text: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.system(size: 15.5, weight: .regular))
                .foregroundStyle(FuelColors.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .tint(FuelColors.flame)
        } else {
            Text(text)
                .font(.system(size: 15.5, weight: .regular))
                .foregroundStyle(FuelColors.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Typewriter

    private var typewriterText: String {
        let count = message.content.count
        guard revealedCharacters < count else { return message.content }
        let safeOffset = min(revealedCharacters, count)
        let index = message.content.index(message.content.startIndex, offsetBy: safeOffset)
        return String(message.content[..<index])
    }

    private func startTypewriter() {
        revealedCharacters = 0
        typingFinished = false
        let totalChars = message.content.count
        guard totalChars > 0 else {
            typingFinished = true
            onFinishTyping?()
            return
        }

        let content = message.content
        let baseNanos: UInt64 = totalChars > 300 ? 6_000_000 : totalChars > 150 ? 10_000_000 : 18_000_000

        typingTask = Task { @MainActor in
            var charIndex = 0

            // Cursor blink loop
            let cursorTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    cursorVisible.toggle()
                }
            }

            while charIndex < totalChars {
                guard !Task.isCancelled else {
                    cursorTask.cancel()
                    return
                }

                let safeIdx = min(charIndex, totalChars - 1)
                let strIdx = content.index(content.startIndex, offsetBy: safeIdx)
                let currentChar = content[strIdx]

                var step = 1
                if currentChar.isWhitespace { step = 3 }

                charIndex = min(charIndex + step, totalChars)
                revealedCharacters = charIndex

                try? await Task.sleep(nanoseconds: baseNanos)
            }

            cursorTask.cancel()
            typingFinished = true

            // Brief pause before showing cards
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showCards = true
            }
            onFinishTyping?()
        }
    }
}
