import SwiftUI
import Speech

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var messageText = ""
    @State private var showingPaywall = false
    @State private var isTypingResponse = false
    @FocusState private var isFocused: Bool
    @State private var sendTask: Task<Void, Never>?
    @State private var scrollTask: Task<Void, Never>?

    @State private var chatLogQuery: String?
    @State private var showingChatLog = false
    @State private var showingGuide = false
    @State private var chatLogAnalysis: FoodAnalysis?
    @State private var showingChatLogResults = false
    @State private var isLoggingFromChat = false
    @State private var speechService = SpeechService()

    private let suggestedPrompts = [
        ("calendar", "Plan my meals today"),
        ("mappin.circle.fill", "Help me order at Chipotle"),
        ("clock.fill", "Meal prep plan for the week"),
        ("refrigerator.fill", "I have chicken, rice & broccoli"),
        ("cart.fill", "Make me a grocery list"),
        ("bolt.fill", "Am I getting enough protein?"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            chatScrollArea

            // Upgrade banner for free users
            if !subscriptionService.isPremium {
                upgradeBanner
            }

            inputBar
        }
        .sheet(isPresented: $showingPaywall) {
            UpgradePaywallView(reason: .chatLimit)
                .environment(subscriptionService)
        }
        .sheet(isPresented: $showingGuide) {
            ChatGuideView()
        }
        .sheet(isPresented: $showingChatLogResults) {
            if let analysis = chatLogAnalysis {
                NavigationStack {
                    FoodResultsView(
                        analysis: analysis,
                        imageData: nil,
                        onLog: { adjusted in
                            logMealFromChat(adjusted)
                        },
                        onRetake: {
                            showingChatLogResults = false
                        },
                        isLogging: isLoggingFromChat,
                        retakeLabel: "Back"
                    )
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showingChatLogResults = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(FuelColors.stone)
                            }
                        }
                    }
                }
                .environment(appState)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    FuelHaptics.shared.tap()
                    // Dismiss keyboard immediately
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    // Switch tab — the ZStack animation modifier handles the transition
                    appState.selectedTab = .home
                } label: {
                    // Larger hit target for reliable taps
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FuelColors.stone)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Back to home")
            }
            ToolbarItem(placement: .principal) {
                Image("FuelAILogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !appState.chatMessages.isEmpty {
                    Button {
                        FuelHaptics.shared.tap()
                        let userId = appState.userProfile?.id
                        withAnimation(FuelAnimation.smooth) {
                            appState.chatMessages.removeAll()
                        }
                        if let userId {
                            Task { try? await appState.databaseService?.clearChatHistory(userId: userId) }
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FuelColors.stone)
                    }
                    .accessibilityLabel("New chat")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(
            ZStack {
                FuelColors.white.ignoresSafeArea()
                LinearGradient(
                    stops: [
                        .init(color: FuelColors.flame.opacity(0.18), location: 0),
                        .init(color: FuelColors.flame.opacity(0.10), location: 0.15),
                        .init(color: FuelColors.flame.opacity(0.04), location: 0.35),
                        .init(color: Color.clear, location: 0.5),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .task {
            if appState.chatMessages.isEmpty, let profile = appState.userProfile {
                let messages = try? await appState.databaseService?.getChatHistory(userId: profile.id)
                if let messages { appState.chatMessages = messages }
            }
            // Daily summary check
            await checkDailySummary()
        }
        .sheet(isPresented: $showingChatLog) {
            if let query = chatLogQuery {
                LogFlowView(initialSearchQuery: query)
                    .environment(appState)
                    .environment(subscriptionService)
            }
        }
        .onDisappear {
            isFocused = false
            sendTask?.cancel()
            scrollTask?.cancel()
            if speechService.isListening { speechService.stopListening() }
        }
    }

    // MARK: - Message Spacing

    private func messagePadding(for message: ChatMessage, at index: Int) -> CGFloat {
        guard index + 1 < appState.chatMessages.count else { return 0 }
        let next = appState.chatMessages[index + 1]
        return message.role == next.role ? FuelSpacing.sm : FuelSpacing.xl
    }

    // MARK: - Empty State

    private var chatScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if appState.chatMessages.isEmpty {
                        emptyState
                    } else {
                        Color.clear.frame(height: FuelSpacing.lg)

                        ForEach(Array(appState.chatMessages.enumerated()), id: \.element.id) { index, message in
                            let isLatest = message.role == .assistant
                                && index == appState.chatMessages.count - 1
                                && isTypingResponse

                            ChatBubbleView(
                                message: message,
                                isLatestAssistant: isLatest,
                                onFinishTyping: {
                                    isTypingResponse = false
                                    scrollToBottom(proxy: proxy)
                                },
                                onLogFood: { query in
                                    handleFoodLog(query: query)
                                },
                                onDirectLog: { name, cal, protein, carbs, fat in
                                    handleDirectLog(name: name, calories: cal, protein: protein, carbs: carbs, fat: fat)
                                },
                                onApplyEdit: { editData in
                                    handleMealEdit(editData: editData)
                                },
                                onLogWithAnalysis: { analysis in
                                    handleLogWithAnalysis(analysis)
                                }
                            )
                            .id(message.id)
                            .padding(.bottom, messagePadding(for: message, at: index))
                        }
                    }

                    if appState.isSendingMessage {
                        thinkingIndicator
                            .id("thinking")

                        Button {
                            FuelHaptics.shared.tap()
                            sendTask?.cancel()
                            appState.isSendingMessage = false
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Stop")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(FuelColors.stone)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(FuelColors.cardBackground)
                                    .shadow(color: FuelColors.cardShadow, radius: 6, y: 2)
                            )
                        }
                        .padding(.top, FuelSpacing.sm)
                    }

                    Color.clear.frame(height: FuelSpacing.sm)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, 4)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: appState.chatMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: appState.isSendingMessage) { _, isSending in
                if isSending {
                    withAnimation(FuelAnimation.smooth) {
                        proxy.scrollTo("thinking", anchor: .bottom)
                    }
                }
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    scrollTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer().frame(minHeight: 40)

            // Guide button
            Button {
                FuelHaptics.shared.tap()
                showingGuide = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FuelColors.flame)
                    Text("See what I can do")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FuelColors.ink)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(FuelColors.fog)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(FuelColors.cloud)
                )
            }
            .pressable()

            Spacer().frame(minHeight: 28)

            VStack(spacing: FuelSpacing.lg + 4) {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [FuelColors.flame.opacity(0.10), FuelColors.flame.opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 72
                            )
                        )
                        .frame(width: 144, height: 144)

                    // Inner circle
                    Circle()
                        .fill(FuelColors.flame.opacity(0.12))
                        .frame(width: 72, height: 72)

                    Image("FlameIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }

                VStack(spacing: FuelSpacing.sm) {
                    Text("How can I help?")
                        .font(.system(size: 24, weight: .bold, design: .default))
                        .foregroundStyle(FuelColors.ink)

                    Text("Ask about your nutrition, macros, or meal ideas")
                        .font(FuelType.body)
                        .foregroundStyle(FuelColors.stone)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer().frame(minHeight: 40)

            // Suggested prompts - 2x2 grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(suggestedPrompts.enumerated()), id: \.offset) { index, prompt in
                    Button {
                        FuelHaptics.shared.tap()
                        sendMessage(prompt.1)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: prompt.0)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FuelColors.flame)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(FuelColors.flame.opacity(0.08))
                                )

                            Text(prompt.1)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(FuelColors.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(FuelColors.cardBackground)
                                .shadow(color: FuelColors.cardShadow, radius: 8, y: 3)
                        )
                    }
                    .pressable()
                    .accessibilityLabel(prompt.1)
                    .staggeredAppear(index: index)
                }
            }
            .padding(.horizontal, FuelSpacing.lg)

            Spacer().frame(minHeight: FuelSpacing.lg)
        }
    }

    // MARK: - Thinking Indicator

    private var thinkingIndicator: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            Image("FlameIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)

            // Thinking bubble
            HStack(spacing: 5) {
                ThinkingDot(delay: 0)
                ThinkingDot(delay: 0.15)
                ThinkingDot(delay: 0.3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(FuelColors.cloud)
            )

            Spacer()
        }
        .padding(.horizontal, FuelSpacing.lg)
        .padding(.top, FuelSpacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thinking")
        .chatAppear()
    }

    // MARK: - Upgrade Banner

    private var upgradeBanner: some View {
        Button {
            FuelHaptics.shared.tap()
            showingPaywall = true
        } label: {
            HStack(spacing: FuelSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FuelColors.flame)

                Text("Upgrade to fuel+ for the full AI coach")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(FuelColors.stone)

                Spacer()

                Text("Upgrade")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FuelColors.flame)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(FuelColors.flame.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, FuelSpacing.lg)
        .padding(.top, 6)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)

            HStack(alignment: .bottom, spacing: 8) {
                // Text input
                TextField(speechService.isListening ? "Listening..." : "Message...", text: $messageText, axis: .vertical)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(FuelColors.ink)
                    .focused($isFocused)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(FuelColors.cloud)
                            .stroke(
                                speechService.isListening ? FuelColors.flame.opacity(0.5) :
                                isFocused ? FuelColors.mist : FuelColors.mist.opacity(0.5),
                                lineWidth: speechService.isListening ? 1.5 : 0.5
                            )
                    )
                    .onSubmit {
                        sendCurrentMessage()
                    }
                    .submitLabel(.send)

                // Mic button
                Button {
                    toggleVoiceInput()
                } label: {
                    Circle()
                        .fill(speechService.isListening ? FuelColors.flame : FuelColors.cloud)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: speechService.isListening ? "mic.fill" : "mic")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(speechService.isListening ? .white : FuelColors.stone)
                        )
                }
                .accessibilityLabel(speechService.isListening ? "Stop dictation" : "Start dictation")
                .animation(FuelAnimation.quick, value: speechService.isListening)

                // Send button
                Button {
                    sendCurrentMessage()
                } label: {
                    Circle()
                        .fill(canSend ? FuelColors.inkSurface : FuelColors.cloud)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(canSend ? .white : FuelColors.fog)
                        )
                }
                .disabled(!canSend)
                .accessibilityLabel("Send message")
                .animation(FuelAnimation.quick, value: canSend)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(
            Rectangle()
                .fill(FuelColors.white.opacity(0.9))
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .onChange(of: speechService.transcript) { _, newValue in
            if !newValue.isEmpty {
                messageText = newValue
            }
        }
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.isSendingMessage
    }

    // MARK: - Actions

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = appState.chatMessages.last {
            withAnimation(FuelAnimation.smooth) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func toggleVoiceInput() {
        if speechService.isListening {
            speechService.stopListening()
            FuelHaptics.shared.tap()
        } else {
            FuelHaptics.shared.tap()
            Task {
                let granted = await speechService.requestPermissions()
                guard granted else { return }
                speechService.startListening()
            }
        }
    }

    private func sendCurrentMessage() {
        // Stop listening if active before sending
        if speechService.isListening {
            speechService.stopListening()
        }
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !appState.isSendingMessage else { return }
        messageText = ""
        FuelHaptics.shared.send()
        sendMessage(text)
    }

    // MARK: - Local Fallback

    private func localFallback(for message: String, context: UserContext) -> String {
        let msg = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let remaining = context.targetCalories - context.todayCalories
        let proteinLeft = context.targetProtein - Int(context.todayProtein)
        let meals = context.recentMeals

        // Greetings
        let greetings = ["hi", "hey", "hello", "sup", "yo", "what's up", "hola", "gm"]
        if msg.count <= 12 && greetings.contains(where: { msg.hasPrefix($0) }) {
            if context.todayCalories > 0 {
                let greetingResponses = [
                    "You've logged \(context.todayCalories) of \(context.targetCalories) calories today. \(remaining > 0 ? "You have \(remaining) cal left — want help planning your next meal?" : "You're at your target for the day.")",
                    "Hey! You're at \(context.todayCalories) cal so far. \(remaining > 0 ? "\(remaining) cal to go — I can help you plan what's next." : "Right at your target — solid day.")",
                    "Looking good — \(context.todayCalories) cal logged. \(proteinLeft > 0 ? "You still need \(proteinLeft)g protein though." : "Protein is on track too.")",
                    "\(context.todayCalories) cal in so far today. \(remaining > 200 ? "Room for a good meal still." : remaining > 0 ? "Almost there for the day." : "You've hit your target!")",
                ]
                return greetingResponses.randomElement() ?? "I can help with that. What are you thinking about?"
            } else {
                let emptyResponses = [
                    "Nothing logged yet today. What did you have for your first meal?",
                    "Hey! Your log is empty — what have you eaten so far?",
                    "Good to see you! Start logging to track your progress today.",
                    "No meals logged yet. Tap + to get started, or tell me what you've eaten.",
                ]
                return emptyResponses.randomElement() ?? "I can help with that. What are you thinking about?"
            }
        }

        // Calorie / progress questions
        if msg.contains("calori") || msg.contains("how am i") || msg.contains("progress") || msg.contains("how much") || msg.contains("remaining") || msg.contains("left") || msg.contains("how's my") || msg.contains("week") || msg.contains("status") || msg.contains("update") || msg.contains("summary") || msg.contains("today") {
            if context.todayCalories == 0 {
                let emptyProgress = [
                    "You haven't logged anything today. Your target is \(context.targetCalories) cal. Log a meal to get started.",
                    "Nothing tracked yet. You're aiming for \(context.targetCalories) cal and \(context.targetProtein)g protein today. What have you eaten?",
                    "Your log is empty. Target: \(context.targetCalories) cal, \(context.targetProtein)g protein. Start tracking to see your progress.",
                ]
                return emptyProgress.randomElement() ?? "I can help with that. What are you thinking about?"
            }
            let calPct = Int(Double(context.todayCalories) / Double(context.targetCalories) * 100)
            let progressResponses = [
                "You're at \(context.todayCalories) of \(context.targetCalories) calories (\(calPct)%). \(remaining > 0 ? "\(remaining) cal remaining." : "You've hit your target.") Protein: \(Int(context.todayProtein))g of \(context.targetProtein)g.",
                "\(context.todayCalories) cal logged (\(calPct)% of target). \(remaining > 0 ? "\(remaining) left to go." : "At your target.") Macros: \(Int(context.todayProtein))g protein, \(Int(context.todayCarbs))g carbs, \(Int(context.todayFat))g fat.",
                "Today so far: \(context.todayCalories)/\(context.targetCalories) cal. Protein: \(Int(context.todayProtein))/\(context.targetProtein)g. \(remaining > 0 ? "You've got \(remaining) cal to work with." : "Calorie target reached.")",
                "Status check: \(calPct)% through your calories. \(proteinLeft > 0 ? "\(proteinLeft)g protein still needed." : "Protein target hit.") \(remaining > 200 ? "Room for more food." : remaining > 0 ? "Almost done for the day." : "You're all set.")",
            ]
            return progressResponses.randomElement() ?? "I can help with that. What are you thinking about?"
        }

        // Protein questions — handle both personal ("am I getting enough") and general ("good sources of protein")
        if msg.contains("protein") {
            // General knowledge: sources, foods high in protein, etc.
            if msg.contains("source") || msg.contains("high in") || msg.contains("rich in") || msg.contains("foods with") || msg.contains("best") || msg.contains("good") || msg.contains("list") || msg.contains("what has") || msg.contains("where can i get") {
                let personalNote = proteinLeft > 0 ? " You need \(proteinLeft)g more today." : ""
                return "Strong protein sources: chicken breast (31g per 100g), eggs (6g each), Greek yogurt (15-20g per cup), salmon (25g per 100g), lentils (18g per cup), cottage cheese (14g per half cup), tofu (10g per 100g).\(personalNote)"
            }
            // Personal progress
            if proteinLeft > 0 {
                return "You need \(proteinLeft)g more protein today. You're at \(Int(context.todayProtein))g of \(context.targetProtein)g. Greek yogurt, chicken, or eggs would close the gap."
            }
            return "You've hit your protein target — \(Int(context.todayProtein))g of \(context.targetProtein)g. Solid."
        }

        // Macro questions
        if msg.contains("macro") || msg.contains("carb") || msg.contains("fat") || msg.contains("nutrient") || msg.contains("fiber") {
            // General knowledge about macros
            if msg.contains("what") && (msg.contains("are") || msg.contains("is")) && !msg.contains("my") && !msg.contains("today") {
                return "Macronutrients are protein, carbohydrates, and fat — the three main energy sources. Protein builds and repairs tissue (4 cal/g). Carbs are your primary fuel (4 cal/g). Fat supports hormones and absorption (9 cal/g). A balanced split depends on your goals."
            }
            return "Today's macros: \(Int(context.todayProtein))g protein, \(Int(context.todayCarbs))g carbs, \(Int(context.todayFat))g fat. \(remaining > 0 ? "\(remaining) calories left to work with." : "You're at your calorie target.")"
        }

        // Coaching / improvement / advice questions
        if msg.contains("improv") || msg.contains("advice") || msg.contains("tip") || msg.contains("help me")
            || msg.contains("what should i do") || msg.contains("how do i") || msg.contains("how can i")
            || msg.contains("better") || msg.contains("coach") || msg.contains("guide")
            || msg.contains("what can i do") || msg.contains("any suggestion") {
            return coachingResponse(context: context)
        }

        // What to eat / meal suggestions
        if msg.contains("what should i eat") || msg.contains("what to eat") || msg.contains("suggest") || msg.contains("recommend") || msg.contains("dinner") || msg.contains("lunch") || msg.contains("snack") || msg.contains("breakfast") || msg.contains("meal idea") || msg.contains("hungry") || msg.contains("feed me") || msg.contains("need food") {
            let hour = Calendar.current.component(.hour, from: Date())
            let mealTime = hour < 11 ? "breakfast" : hour < 15 ? "lunch" : hour < 18 ? "afternoon snack" : "dinner"

            if remaining > 600 {
                let bigMealOptions = [
                    "You have \(remaining) cal left — plenty of room. \(proteinLeft > 20 ? "Focus on protein (\(proteinLeft)g to go)." : "Protein is covered.") Try grilled chicken with rice and vegetables, or a salmon bowl with sweet potato.",
                    "\(remaining) cal remaining — time for a solid \(mealTime). A burrito bowl with chicken, beans, rice, and veggies would be around 500-600 cal and high in protein.",
                    "Room for a real meal (\(remaining) cal left). Consider stir-fry with lean protein and veggies over rice, or a hearty salad with grilled chicken and avocado.",
                    "With \(remaining) cal to work with, you could do a great \(mealTime). Pasta with ground turkey and marinara, or a poke bowl would both fit well.",
                ]
                return bigMealOptions.randomElement() ?? "I can help with that. What are you thinking about?"
            } else if remaining > 300 {
                let medMealOptions = [
                    "\(remaining) cal left — a moderate meal fits. Try a protein-focused option like a chicken wrap, tuna salad, or an omelet with veggies.",
                    "You've got \(remaining) cal. A Greek yogurt parfait with granola, or a turkey sandwich on whole wheat would be solid choices.",
                    "Room for about \(remaining) cal. Consider eggs with toast, a protein shake with a banana, or a small chicken salad.",
                    "\(remaining) cal to play with. \(proteinLeft > 15 ? "Prioritize protein — try cottage cheese, a protein bar, or some grilled chicken." : "You could go with lighter carbs like a small wrap or fruit.")",
                ]
                return medMealOptions.randomElement() ?? "I can help with that. What are you thinking about?"
            } else if remaining > 100 {
                let snackOptions = [
                    "You have \(remaining) cal left — snack territory. Greek yogurt (100-150 cal), a handful of almonds (160 cal), or an apple with a tablespoon of peanut butter (190 cal).",
                    "\(remaining) cal remaining. Light snack ideas: string cheese (80 cal), a hard boiled egg (70 cal), cottage cheese (100 cal), or a protein bar.",
                    "Almost there with \(remaining) cal left. A piece of fruit, some veggies with hummus, or a small handful of nuts would round out the day.",
                    "Room for a small snack (\(remaining) cal). Rice cakes with PB, a protein shake, or some edamame would all work.",
                ]
                return snackOptions.randomElement() ?? "I can help with that. What are you thinking about?"
            } else if remaining > 0 {
                return ["Just \(remaining) cal left. A piece of fruit or some raw veggies would be a clean finish to the day.",
                        "Barely any room left (\(remaining) cal). If you're hungry, go for cucumber, celery, or a small apple.",
                        "Almost at target with \(remaining) cal. You could have some herbal tea or a few carrot sticks."].randomElement() ?? "I can help with that. What are you thinking about?"
            }
            let overOptions = [
                "You're at your calorie target. If you're still hungry, opt for something very low-calorie like vegetables, broth, or herbal tea.",
                "You've hit your target for the day. If hunger strikes, try sparkling water with lemon, raw veggies, or a cup of broth — minimal calories, still satisfying.",
                "Already at target. Best options if you're hungry: cucumber slices, celery, hot tea, or a small portion of broth. Save the bigger meal for tomorrow.",
            ]
            return overOptions.randomElement() ?? "I can help with that. What are you thinking about?"
        }

        // What have I eaten
        if msg.contains("eaten") || msg.contains("log") || msg.contains("meals today") || msg.contains("what did i") || msg.contains("review") || msg.contains("food today") {
            if meals.isEmpty {
                return "Nothing logged yet today. Tap the + button to log your first meal."
            }
            return "Today's meals: \(meals.joined(separator: ", ")). Total: \(context.todayCalories) cal, \(Int(context.todayProtein))g protein."
        }

        // Streak
        if msg.contains("streak") {
            if context.streak >= 30 {
                let longStreakResponses = [
                    "\(context.streak)-day streak! That's exceptional. You've turned tracking into a real habit — this level of consistency is what separates results from intentions.",
                    "Incredible — \(context.streak) days straight. Most people quit in the first week. You're proof that showing up daily works.",
                    "\(context.streak) days and counting. You're in the top tier of consistency. This is when real body composition changes happen.",
                ]
                return longStreakResponses.randomElement() ?? "I can help with that. What are you thinking about?"
            } else if context.streak >= 7 {
                let weekStreakResponses = [
                    "You're on a \(context.streak)-day streak. At this point, you're building a habit. Keep going — the magic happens around 21+ days.",
                    "\(context.streak) days in a row! You've proven you can show up consistently. Now aim for the next milestone.",
                    "Solid \(context.streak)-day streak. Research shows habits form around 21-66 days. You're on your way.",
                ]
                return weekStreakResponses.randomElement() ?? "I can help with that. What are you thinking about?"
            } else if context.streak > 0 {
                let shortStreakResponses = [
                    "You're on a \(context.streak)-day streak. Keep logging to maintain it — every day counts.",
                    "\(context.streak)-day streak. Build toward 7 days — that's where the momentum really kicks in.",
                    "\(context.streak) days strong. Don't break the chain — log today and keep building.",
                ]
                return shortStreakResponses.randomElement() ?? "I can help with that. What are you thinking about?"
            }
            let noStreakResponses = [
                "No active streak yet. Log a meal today to start one — even a single day counts.",
                "Start your streak today! Logging just one meal kicks it off. Consistency beats perfection.",
                "No streak going — but that changes right now. Log what you've eaten and day 1 begins.",
            ]
            return noStreakResponses.randomElement() ?? "I can help with that. What are you thinking about?"
        }

        // Weight / goal
        if msg.contains("weight") || msg.contains("goal") || msg.contains("lose") || msg.contains("gain") || msg.contains("cut") || msg.contains("bulk") {
            let goalText = context.goalType == "lose" ? "losing weight" : context.goalType == "gain" ? "gaining weight" : "maintaining"
            return "Your goal is \(goalText) at \(context.targetCalories) cal/day. \(remaining > 0 ? "You have \(remaining) cal left today." : "You've hit your calorie target for today.")"
        }

        // Pattern / insight
        if msg.contains("pattern") || msg.contains("insight") || msg.contains("trend") || msg.contains("analysis") {
            if context.todayCalories > 0 {
                let proteinPct = context.todayProtein > 0 ? Int((context.todayProtein * 4) / Double(context.todayCalories) * 100) : 0
                return "Today's breakdown: \(proteinPct)% protein, with \(remaining) cal remaining. Check the Progress tab for weekly trends and patterns."
            }
            return "Log a few meals first — I need data to spot patterns. Check the Progress tab for your weekly trends."
        }

        // General food/nutrition questions — catch these BEFORE the off-topic fallback
        // This handles "is X healthy", "will X be fine", "how many calories in X", "is X good for you", etc.
        if isNutritionRelated(msg) {
            return generalNutritionAnswer(for: msg, context: context)
        }

        // Very short or gibberish
        if msg.count < 3 {
            return "Not sure I follow. Try asking about your calories, macros, or what to eat next."
        }

        // Off-topic catch-all — give a brief coaching nudge instead of a dismissal
        if remaining > 0 {
            return "I'm best with nutrition, food choices, and meal planning. You have \(remaining) cal and \(proteinLeft > 0 ? "\(proteinLeft)g protein" : "no protein") left today — I can help you plan your next meal or give coaching on your progress."
        }
        return "I'm best with nutrition, food choices, and meal planning. Ask me about your progress, what to eat, or how to reach your goals."
    }

    /// Checks if a message is related to food, nutrition, health, or fitness
    private func isNutritionRelated(_ msg: String) -> Bool {
        let nutritionKeywords = [
            // Foods
            "chicken", "beef", "pork", "fish", "salmon", "tuna", "shrimp",
            "egg", "milk", "cheese", "yogurt", "butter", "cream",
            "rice", "bread", "pasta", "oat", "cereal", "wheat", "grain",
            "apple", "banana", "orange", "berry", "fruit", "vegetable",
            "broccoli", "spinach", "kale", "avocado", "potato", "sweet potato",
            "bean", "lentil", "tofu", "nut", "almond", "peanut",
            "oil", "olive", "coconut", "sugar", "honey",
            "steak", "burger", "pizza", "sandwich", "salad", "soup", "sushi",
            "smoothie", "shake", "juice", "coffee", "tea", "water",
            // Nutrition concepts
            "healthy", "unhealthy", "nutritious", "vitamin", "mineral",
            "calorie", "kcal", "serving", "portion",
            "diet", "keto", "vegan", "vegetarian", "paleo", "fasting",
            "supplement", "creatine", "omega", "iron", "calcium", "zinc",
            "cholesterol", "sodium", "potassium", "magnesium",
            // Health/fitness
            "workout", "exercise", "muscle", "recovery",
            "hydrat", "metabolism", "digest", "gut", "bloat",
            // Food-specific patterns
            "eat", "food", "meal", "cook", "recipe", "ingredient",
            "hungry", "crave", "appetite",
            "good for", "bad for", "swap", "replace",
        ]
        return nutritionKeywords.contains { msg.contains($0) }
    }

    /// Provides general nutrition knowledge answers
    private func generalNutritionAnswer(for msg: String, context: UserContext) -> String {
        let remaining = context.targetCalories - context.todayCalories
        let proteinLeft = context.targetProtein - Int(context.todayProtein)

        // Specific food questions: "is X good", "will X be fine", "how about X"
        let meats = ["chicken", "beef", "steak", "pork", "turkey", "lamb", "fish", "salmon", "tuna", "shrimp"]
        let dairy = ["milk", "cheese", "yogurt", "cream", "butter"]
        let grains = ["rice", "bread", "pasta", "oat", "cereal", "wheat"]
        let fruits = ["apple", "banana", "orange", "berry", "berries", "mango", "grape"]
        let veggies = ["broccoli", "spinach", "kale", "salad", "vegetable", "carrot", "tomato"]

        // Check if asking about a specific food
        if let meat = meats.first(where: { msg.contains($0) }) {
            let info: String
            switch meat {
            case "chicken": info = "Chicken breast is one of the best lean proteins — about 165 cal and 31g protein per 100g. Low fat, versatile."
            case "beef", "steak": info = "Beef is protein-dense (26g per 100g) and rich in iron and B12. Leaner cuts like sirloin are around 200 cal per 100g. Fattier cuts run higher."
            case "salmon": info = "Salmon is excellent — 208 cal, 20g protein per 100g, plus omega-3 fatty acids for heart and brain health."
            case "tuna": info = "Tuna is very lean — about 130 cal, 29g protein per 100g. Great for high-protein, low-calorie meals."
            case "fish": info = "Fish is generally a strong choice — high protein, low calorie, and most varieties provide healthy omega-3 fats."
            case "turkey": info = "Turkey breast is very lean — about 135 cal, 30g protein per 100g. Comparable to chicken."
            case "pork": info = "Pork tenderloin is lean — about 143 cal, 26g protein per 100g. Fattier cuts like bacon are much higher in calories."
            case "shrimp": info = "Shrimp is one of the leanest proteins — about 85 cal, 20g protein per 100g."
            default: info = "\(meat.capitalized) is a solid protein source."
            }
            return proteinLeft > 0 ? "\(info) You need \(proteinLeft)g more protein today — this would help." : info
        }

        if dairy.contains(where: { msg.contains($0) }) {
            return "Dairy is a good source of protein and calcium. Greek yogurt (15-20g protein per cup) and cottage cheese (14g per half cup) are particularly protein-dense. Watch portions with cheese and cream — they're calorie-dense."
        }

        if grains.contains(where: { msg.contains($0) }) {
            return "Whole grains provide complex carbs, fiber, and sustained energy. Brown rice, oats, and whole wheat are better choices than refined grains. A typical serving of cooked rice is about 200 cal."
        }

        if fruits.contains(where: { msg.contains($0) }) {
            return "Fruit is nutrient-dense with fiber, vitamins, and natural sugars. Berries are the lowest calorie option. Bananas are great pre-workout fuel. A medium apple is about 95 cal. Whole fruit is always better than juice."
        }

        if veggies.contains(where: { msg.contains($0) }) {
            return "Vegetables are the most nutrient-dense, lowest-calorie foods you can eat. Fill half your plate with them. Leafy greens, broccoli, and peppers are especially rich in vitamins and fiber."
        }

        // Cooking / recipe questions
        if msg.contains("recipe") || msg.contains("cook") || msg.contains("how to make") || msg.contains("prepare") {
            return "For a solid meal, pair a lean protein (chicken, fish, tofu) with a complex carb (rice, sweet potato) and vegetables. Keep cooking methods simple — grilling, baking, or stir-frying with minimal oil."
        }

        // "Is X healthy / fine / good"
        if msg.contains("healthy") || msg.contains("fine") || msg.contains("okay") || msg.contains("good for") || msg.contains("bad for") {
            if remaining > 0 {
                return "Most whole foods are fine in the right amounts. What matters is how it fits your remaining \(remaining) cal and \(proteinLeft > 0 ? "\(proteinLeft)g protein gap" : "macros"). What food are you considering?"
            }
            return "Most whole foods are fine in the right amounts. It depends on your goals and portions. What specifically are you thinking about?"
        }

        // Diet-type questions
        if msg.contains("keto") || msg.contains("vegan") || msg.contains("vegetarian") || msg.contains("paleo") || msg.contains("fasting") || msg.contains("diet") {
            return "The best diet is one you can stick to consistently. Focus on hitting your protein target, eating whole foods, and staying within your calorie range. Specific diets work when they help you do that — not because of any magic formula."
        }

        // Supplement questions
        if msg.contains("supplement") || msg.contains("creatine") || msg.contains("vitamin") || msg.contains("omega") {
            return "Prioritize whole foods first. That said — creatine is well-researched for performance, vitamin D if you're low on sun exposure, and omega-3s if you don't eat fish regularly. Everything else is secondary to a solid diet."
        }

        // Workout/exercise nutrition
        if msg.contains("workout") || msg.contains("exercise") || msg.contains("muscle") || msg.contains("recovery") || msg.contains("pre-workout") || msg.contains("post-workout") {
            return "For exercise performance: eat carbs 1-2 hours before training for energy. After, prioritize protein (20-40g) within a couple hours to support recovery. Stay hydrated throughout."
        }

        // Hydration
        if msg.contains("water") || msg.contains("hydrat") || msg.contains("drink") {
            return "Aim for about 2-3 liters of water daily, more if you're active or in a warm climate. Water, tea, and coffee all count. Signs of good hydration: pale yellow urine, consistent energy."
        }

        // Generic food question we can't specifically answer — ask for specifics
        if remaining > 0 {
            return "I can help with that. What specific food or meal are you thinking about? You have \(remaining) cal left today."
        }
        return "I can help with that. What specific food or meal do you have in mind?"
    }

    /// Personalized coaching response based on user data
    private func coachingResponse(context: UserContext) -> String {
        let remaining = context.targetCalories - context.todayCalories
        let proteinLeft = context.targetProtein - Int(context.todayProtein)
        let goalText = context.goalType == "lose" ? "losing weight" : context.goalType == "gain" ? "gaining weight" : "maintaining"

        // No data logged yet
        if context.todayCalories == 0 {
            let noDataResponses = [
                "Your goal is \(goalText) at \(context.targetCalories) cal/day with \(context.targetProtein)g protein. Start by logging your first meal — consistency is the single biggest factor in reaching any nutrition goal.\(context.streak > 0 ? " You're on a \(context.streak)-day streak — log today to keep it going." : "")",
                "Nothing logged yet. Your target is \(context.targetCalories) cal and \(context.targetProtein)g protein. The most important step is the first one — log what you've eaten so far and we'll work from there.\(context.streak > 0 ? " Don't break your \(context.streak)-day streak!" : "")",
                "Let's get today started. You're aiming for \(context.targetCalories) cal. Log your first meal — even a rough estimate is better than nothing. Tracking builds awareness, and awareness drives results.\(context.streak > 0 ? " Keep that \(context.streak)-day streak alive!" : "")",
                "Hey coach mode activated. Your \(goalText) plan calls for \(context.targetCalories) cal/day. Step one: log what you've had. I'll guide you from there.",
            ]
            return noDataResponses.randomElement() ?? "I can help with that. What are you thinking about?"
        }

        var tips: [String] = []

        // Calorie analysis
        let calPct = Double(context.todayCalories) / Double(context.targetCalories) * 100
        if remaining > 500 {
            let underEatingTips = [
                "You've only eaten \(context.todayCalories) of \(context.targetCalories) cal (\(Int(calPct))%). If you're \(goalText == "losing weight" ? "cutting" : "trying to hit your target"), make sure you're not under-eating — that can slow your metabolism and lead to overeating later.",
                "At \(Int(calPct))% of your target with \(remaining) cal to go. Under-eating consistently is counterproductive — it increases cravings and can tank your energy. Make sure you're fueling properly.",
                "Only \(context.todayCalories) cal so far. You still have \(remaining) to go. Eating too little is just as problematic as eating too much — your body needs fuel to function and recover.",
            ]
            tips.append(underEatingTips.randomElement() ?? "I can help with that. What are you thinking about?")
        } else if remaining < 0 {
            let over = abs(remaining)
            let overTips = [
                "You're \(over) cal over your \(context.targetCalories) target. Don't stress — one day over won't derail you. Tomorrow, aim to hit your target and the weekly average will balance out.",
                "Over by \(over) cal. Here's the truth: progress is about averages, not individual days. Get back on track tomorrow and your weekly numbers will still be solid.",
                "\(over) cal above target. It happens. The worst thing you can do is try to \"make up for it\" by skipping meals tomorrow. Just reset and eat normally.",
            ]
            tips.append(overTips.randomElement() ?? "I can help with that. What are you thinking about?")
        } else if remaining > 0 && remaining <= 300 {
            let closeTips = [
                "You're close to your target with \(remaining) cal left. Nice control today.",
                "Almost there — just \(remaining) cal remaining. A small snack would round this out perfectly.",
                "Dialed in at \(context.todayCalories) cal with only \(remaining) to go. This is solid consistency.",
            ]
            tips.append(closeTips.randomElement() ?? "I can help with that. What are you thinking about?")
        }

        // Protein analysis
        if proteinLeft > 30 {
            let proteinTips = [
                "You still need \(proteinLeft)g protein. Protein is key for \(goalText == "losing weight" ? "preserving muscle while cutting" : goalText == "gaining weight" ? "building muscle" : "staying full and maintaining lean mass"). Try adding Greek yogurt (15g), eggs (6g each), or a chicken breast (31g) to close the gap.",
                "\(proteinLeft)g protein remaining. Top sources to consider: cottage cheese (14g/half cup), tuna (29g/100g), or a protein shake (20-30g). Prioritize this in your next meal.",
                "Protein gap alert: \(proteinLeft)g still needed. This matters for \(goalText == "losing weight" ? "keeping muscle during your cut" : goalText == "gaining weight" ? "muscle growth" : "recovery and satiety"). Try stacking protein in your next 1-2 meals.",
            ]
            tips.append(proteinTips.randomElement() ?? "I can help with that. What are you thinking about?")
        } else if proteinLeft <= 0 {
            let proteinHitTips = [
                "Protein is on point at \(Int(context.todayProtein))g — that's solid for \(goalText).",
                "You crushed your protein target (\(Int(context.todayProtein))g). This is how you \(goalText == "losing weight" ? "preserve muscle while cutting" : goalText == "gaining weight" ? "fuel muscle growth" : "maintain lean mass").",
                "Protein: done. \(Int(context.todayProtein))g logged. Your muscles are happy.",
            ]
            tips.append(proteinHitTips.randomElement() ?? "I can help with that. What are you thinking about?")
        } else {
            tips.append("Protein at \(Int(context.todayProtein))g with \(proteinLeft)g to go. You're on pace — keep including protein with your remaining meals.")
        }

        // Macro balance check
        let totalMacrosCal = (context.todayProtein * 4) + (Double(context.todayCarbs) * 4) + (Double(context.todayFat) * 9)
        if totalMacrosCal > 0 {
            let fatPct = (Double(context.todayFat) * 9) / totalMacrosCal * 100
            let carbPct = (Double(context.todayCarbs) * 4) / totalMacrosCal * 100
            if fatPct > 45 {
                tips.append("Your fat intake is high today (\(Int(fatPct))% of calories). Consider swapping some fats for lean protein or complex carbs in your next meal.")
            }
            if carbPct > 65 {
                tips.append("Carbs are making up \(Int(carbPct))% of your intake. Try balancing with more protein and healthy fats to stay fuller longer.")
            }
        }

        // Streak encouragement
        if context.streak >= 30 {
            tips.append("\(context.streak)-day streak! That's incredible consistency. You've built a real habit — this is when the transformation happens.")
        } else if context.streak >= 14 {
            tips.append("\(context.streak)-day streak. Two weeks of consistent tracking is where most people start seeing real changes. Keep going.")
        } else if context.streak >= 7 {
            tips.append("You're on a \(context.streak)-day streak. That consistency is what drives real results — keep it going.")
        } else if context.streak > 0 {
            tips.append("\(context.streak)-day streak. Build toward 7 days — that's where the habit starts to stick.")
        }

        // Goal-specific tips (expanded pool)
        if tips.count < 3 {
            switch context.goalType {
            case "lose":
                let loseTips = [
                    "For fat loss, prioritize protein at every meal, eat plenty of vegetables for volume, and don't skip meals — it leads to overeating later.",
                    "Cutting tip: eat your protein and veggies first at each meal. You'll feel fuller and naturally eat fewer carbs and fats.",
                    "The best fat loss strategy is boring: hit your calorie target, prioritize protein, eat whole foods, and sleep well. No hacks needed.",
                    "For your cut: high-volume, low-calorie foods like salads, soups, and vegetables are your best friends. They fill you up without the calorie cost.",
                    "Remember — you don't need to be perfect every day. Hitting your target 5-6 days out of 7 is still excellent for fat loss.",
                ]
                tips.append(loseTips.randomElement() ?? "I can help with that. What are you thinking about?")
            case "gain":
                let gainTips = [
                    "For gaining, eat calorie-dense foods like nuts, avocado, and olive oil. Spread protein across 4+ meals for better absorption.",
                    "Bulking tip: if you're struggling to eat enough, drink some calories — smoothies with protein, oats, and peanut butter are easy 500+ cal.",
                    "For your surplus: don't just eat junk. Prioritize quality calories — the goal is muscle, not just weight. Lean proteins, complex carbs, healthy fats.",
                    "Gaining requires consistency in surplus. If you're not seeing results, you're probably not eating as much as you think. Track everything.",
                ]
                tips.append(gainTips.randomElement() ?? "I can help with that. What are you thinking about?")
            default:
                let maintainTips = [
                    "For maintenance, focus on consistent meal timing and hitting your protein target daily. The rest tends to fall into place.",
                    "Maintenance is about consistency. Hit your calories ±100 most days and your weight will stay stable.",
                    "The key to maintaining: build meals around protein and vegetables, then fill in with carbs and fats. Simple and effective.",
                    "You're in maintenance mode — the hardest and most underrated phase. Staying consistent here is what separates the successful from the rest.",
                ]
                tips.append(maintainTips.randomElement() ?? "I can help with that. What are you thinking about?")
            }
        }

        return tips.joined(separator: "\n\n")
    }

    /// Check if response is an auth/service error disguised as a message
    private func isServiceError(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("session expired")
            || lower.contains("please sign in")
            || lower.contains("having trouble connecting")
            || lower.contains("connection issue")
    }

    // MARK: - Send Message

    private func sendMessage(_ text: String) {
        guard !appState.isSendingMessage else { return }
        guard let profile = appState.userProfile else { return }
        let userId = profile.id
        guard RateLimiter.canChat(isPremium: subscriptionService.isPremium) else {
            // Restore the message so the user doesn't lose their input
            if messageText.isEmpty { messageText = text }
            FuelHaptics.shared.error()
            showingPaywall = true
            return
        }
        appState.isSendingMessage = true

        let history = Array(appState.chatMessages.suffix(6))

        let userMessage = ChatMessage(
            id: UUID(),
            userId: userId,
            role: .user,
            content: text,
            createdAt: Date()
        )
        withAnimation(FuelAnimation.messagePop) {
            appState.chatMessages.append(userMessage)
        }

        sendTask = Task {
            try? await appState.databaseService?.saveChatMessage(userMessage)

            // Gather 7-day history for richer context
            let weekHistory = await buildWeekHistory(for: profile)
            let topFoods = await buildTopFoods(for: profile)
            let weightTrend = await buildWeightTrend(for: profile)

            // Build meal detail JSON for edit feature
            let mealsDetail = buildTodayMealsDetail()

            // Yesterday's data for streak recovery
            let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())?.dateString ?? ""
            let yesterdayCal = weekHistory.first(where: { $0.date == yesterdayDate })?.calories
            let yesterdayTgt = appState.calorieTarget

            let context = UserContext(
                targetCalories: appState.calorieTarget,
                targetProtein: appState.proteinTarget,
                targetCarbs: appState.carbsTarget,
                targetFat: appState.fatTarget,
                todayCalories: appState.caloriesConsumed,
                todayProtein: appState.proteinConsumed,
                todayCarbs: appState.carbsConsumed,
                todayFat: appState.fatConsumed,
                goalType: profile.goalType?.rawValue ?? "maintain",
                recentMeals: appState.todayMeals.map { $0.displayName },
                streak: appState.currentStreak,
                displayName: profile.displayName ?? "",
                dietStyle: profile.dietStyle?.rawValue,
                weekHistory: weekHistory,
                topFoods: topFoods,
                weightTrend: weightTrend,
                todayMealsDetail: mealsDetail,
                yesterdayCalories: yesterdayCal,
                yesterdayTarget: yesterdayTgt
            )

            var responseText: String?
            var responseCards: [ChatCard]?
            let isPremium = subscriptionService.isPremium

            // Premium users get full AI; free users get local-only (zero API cost)
            if isPremium, profile != nil, appState.aiService != nil {
                do {
                    let response = try await withTimeout(seconds: 15) {
                        try await appState.aiService?.sendChatMessage(
                            message: text,
                            history: history,
                            userContext: context
                        )
                    }

                    if let msg = response?.message, !msg.isEmpty {
                        // Check if the "response" is actually a service error
                        if isServiceError(msg) {
                            // Treat as failure, fall through to local fallback
                            responseText = nil
                        } else {
                            responseText = msg
                            responseCards = response?.cards
                        }
                    }
                } catch {
                    // Fall through to local fallback
                }
            }

            guard !Task.isCancelled else {
                await MainActor.run { appState.isSendingMessage = false }
                return
            }

            // Use local fallback if AI didn't produce a response
            let finalText = responseText ?? localFallback(for: text, context: context)

            let assistantMessage = ChatMessage(
                id: UUID(),
                userId: userId,
                role: .assistant,
                content: finalText,
                createdAt: Date(),
                cards: responseCards
            )

            // Count against rate limit for all users (free users have daily cap)
            RateLimiter.recordChat()

            await MainActor.run {
                isTypingResponse = true
                withAnimation(FuelAnimation.messagePop) {
                    appState.chatMessages.append(assistantMessage)
                }
                appState.isSendingMessage = false
                FuelHaptics.shared.tap()
            }

            try? await appState.databaseService?.saveChatMessage(assistantMessage)
        }
    }

    // MARK: - Timeout Helper

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CancellationError()
            }
            guard let result = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - 7-Day History Helpers

    private func buildWeekHistory(for profile: UserProfile) async -> [WeekDaySummary] {
        guard let summaries = try? await appState.databaseService?.getSummaries(userId: profile.id, days: 7) else { return [] }
        let target = profile.targetCalories ?? 2000
        return summaries.map { s in
            WeekDaySummary(
                date: s.date,
                calories: s.totalCalories,
                protein: s.totalProtein,
                carbs: s.totalCarbs,
                fat: s.totalFat,
                isOnTarget: abs(s.totalCalories - target) <= Int(Double(target) * 0.15)
            )
        }
    }

    private func buildTopFoods(for profile: UserProfile) async -> [String] {
        guard let db = appState.databaseService else { return [] }
        var foodCounts: [String: Int] = [:]
        // Query actual meals for the last 7 days (summaries don't include meals)
        for dayOffset in 0..<7 {
            guard let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dateStr = date.dateString
            guard let meals = try? await db.getMeals(for: dateStr, userId: profile.id) else { continue }
            for meal in meals {
                let name = meal.displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !name.isEmpty { foodCounts[name, default: 0] += 1 }
            }
        }
        return foodCounts.sorted { $0.value > $1.value }.prefix(8).map { $0.key }
    }

    private func buildWeightTrend(for profile: UserProfile) async -> String? {
        guard let weights = try? await appState.databaseService?.getWeightHistory(userId: profile.id, days: 14) else { return nil }
        guard weights.count >= 2, let recent = weights.last, let earlier = weights.first else { return nil }
        let diff = recent.weightKg - earlier.weightKg
        let isMetric = profile.unitSystem == .metric
        if isMetric {
            return String(format: "%+.1f kg over %d days", diff, weights.count)
        } else {
            return String(format: "%+.1f lbs over %d days", diff * 2.205, weights.count)
        }
    }

    // MARK: - Log From Chat

    func handleFoodLog(query: String) {
        chatLogQuery = query
        showingChatLog = true
    }

    // MARK: - Direct Log (Restaurant Orders)

    func handleDirectLog(name: String, calories: Int, protein: Double, carbs: Double, fat: Double) {
        guard let profile = appState.userProfile else {
            handleFoodLog(query: name)
            return
        }
        let userId = profile.id
        Task {
            let item = MealItem(
                id: UUID(),
                name: name,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                servingSize: nil,
                quantity: 1,
                confidence: 0.8
            )
            let meal = Meal(
                id: UUID(),
                userId: userId,
                items: [item],
                totalCalories: calories,
                totalProtein: protein,
                totalCarbs: carbs,
                totalFat: fat,
                displayName: name,
                loggedDate: Date().dateString,
                loggedAt: Date(),
                createdAt: Date()
            )
            // Optimistic: show meal immediately
            await MainActor.run {
                appState.todayMeals.append(meal)
                appState.rebuildSummaryFromMeals()
                appState.dataVersion += 1
            }
            do {
                try await appState.databaseService?.logMeal(meal)
                await appState.recalculateDailySummary(forceFromMeals: true)
                await MainActor.run {
                    FuelHaptics.shared.tap()
                    let confirmMsg = ChatMessage(
                        id: UUID(),
                        userId: userId,
                        role: .assistant,
                        content: "Logged \(name) — \(calories) cal, \(Int(protein))g protein. Your totals are updated.",
                        createdAt: Date()
                    )
                    withAnimation(FuelAnimation.messagePop) {
                        appState.chatMessages.append(confirmMsg)
                    }
                }
            } catch {
                #if DEBUG
                print("[Chat] Direct log failed: \(error)")
                #endif
                // Add to pending queue for retry on next launch
                await MainActor.run {
                    appState.markMealPending(meal)
                    appendErrorMessage("Saved \(name) locally — it will sync when you're back online.", userId: userId)
                }
            }
        }
    }

    // MARK: - Meal Edit

    func handleMealEdit(editData: MealEditData) {
        guard let profile = appState.userProfile,
              let mealId = UUID(uuidString: editData.mealId) else { return }

        // Find the original meal
        guard let originalMeal = appState.todayMeals.first(where: { $0.id == mealId }) else {
            #if DEBUG
            print("[Chat] Meal edit: meal not found \(editData.mealId)")
            #endif
            appendErrorMessage("Couldn't find that meal to edit. It may have been deleted.", userId: profile.id)
            return
        }

        Task {
            // Create updated meal with same ID and timestamp
            let editedItem = MealItem(
                id: UUID(),
                name: editData.mealName,
                calories: editData.newCalories,
                protein: editData.newProtein,
                carbs: editData.newCarbs,
                fat: editData.newFat,
                quantity: 1,
                confidence: 0.9
            )
            let updatedMeal = Meal(
                id: mealId,
                userId: profile.id,
                items: [editedItem],
                totalCalories: editData.newCalories,
                totalProtein: editData.newProtein,
                totalCarbs: editData.newCarbs,
                totalFat: editData.newFat,
                imageUrl: originalMeal.imageUrl,
                displayName: editData.mealName,
                loggedDate: originalMeal.loggedDate,
                loggedAt: originalMeal.loggedAt,
                createdAt: originalMeal.createdAt
            )

            guard let db = appState.databaseService else {
                await MainActor.run {
                    appendErrorMessage("Couldn't apply the edit — try again in a moment.", userId: profile.id)
                }
                return
            }

            do {
                // Delete old meal
                try await db.deleteMeal(id: mealId)

                do {
                    // Insert updated meal — if this fails, rollback by re-inserting original
                    try await db.logMeal(updatedMeal)
                } catch {
                    // Rollback: re-insert the original meal to prevent data loss
                    try? await db.logMeal(originalMeal)
                    await MainActor.run {
                        appendErrorMessage("Edit failed — your original meal has been restored.", userId: profile.id)
                    }
                    return
                }

                await appState.refreshTodayData()
                await appState.recalculateDailySummary(forceFromMeals: true)

                let calDiff = editData.newCalories - editData.originalCalories
                let diffText = calDiff > 0 ? "+\(calDiff)" : "\(calDiff)"

                await MainActor.run {
                    FuelHaptics.shared.tap()
                    let confirmMsg = ChatMessage(
                        id: UUID(),
                        userId: profile.id,
                        role: .assistant,
                        content: "Updated \(editData.mealName) (\(diffText) cal). Your totals are refreshed.",
                        createdAt: Date()
                    )
                    withAnimation(FuelAnimation.messagePop) {
                        appState.chatMessages.append(confirmMsg)
                    }
                }
            } catch {
                #if DEBUG
                print("[Chat] Meal edit failed: \(error)")
                #endif
                await MainActor.run {
                    appendErrorMessage("Couldn't apply the edit — try again in a moment.", userId: profile.id)
                }
            }
        }
    }

    // MARK: - Log with Analysis (FoodResultsView)

    func handleLogWithAnalysis(_ analysis: FoodAnalysis) {
        chatLogAnalysis = analysis
        showingChatLogResults = true
    }

    private func logMealFromChat(_ analysis: FoodAnalysis) {
        guard !isLoggingFromChat else { return }
        let profile: UserProfile
        if let existing = appState.userProfile {
            profile = existing
        } else if let session = Constants.supabase.auth.currentSession {
            profile = UserProfile(id: session.user.id, isPremium: false, streakCount: 0, longestStreak: 0, unitSystem: .imperial, createdAt: Date(), updatedAt: Date())
        } else { return }

        guard let db = appState.databaseService else {
            appendErrorMessage("Couldn't log the meal — try again in a moment.", userId: profile.id)
            return
        }

        isLoggingFromChat = true
        let now = Date()
        let items = analysis.items.map { item in
            MealItem(id: item.id, name: item.name, calories: item.calories, protein: item.protein, carbs: item.carbs, fat: item.fat, fiber: item.fiber, sugar: item.sugar, servingSize: item.servingSize, estimatedGrams: item.estimatedGrams, measurementUnit: item.measurementUnit, measurementAmount: item.measurementAmount, quantity: item.quantity, confidence: item.confidence)
        }
        let meal = Meal(
            id: UUID(), userId: profile.id, items: items,
            totalCalories: analysis.totalCalories, totalProtein: analysis.totalProtein,
            totalCarbs: analysis.totalCarbs, totalFat: analysis.totalFat,
            totalFiber: analysis.fiberG ?? 0, totalSugar: analysis.sugarG ?? 0,
            totalSodium: analysis.sodiumMg ?? 0,
            displayName: analysis.displayName, loggedDate: now.dateString,
            loggedAt: now, createdAt: now
        )

        MealHistoryService.shared.recordMeal(name: meal.displayName, calories: meal.totalCalories)

        Task {
            do {
                try await db.logMeal(meal)
                await appState.refreshTodayData()
                await appState.recalculateDailySummary(forceFromMeals: true)
                await MainActor.run {
                    isLoggingFromChat = false
                    showingChatLogResults = false
                    FuelHaptics.shared.tap()
                    let confirmMsg = ChatMessage(
                        id: UUID(), userId: profile.id, role: .assistant,
                        content: "Logged \(analysis.displayName) — \(analysis.totalCalories) cal. Your totals are updated.",
                        createdAt: Date()
                    )
                    withAnimation(FuelAnimation.messagePop) {
                        appState.chatMessages.append(confirmMsg)
                    }
                }
            } catch {
                await MainActor.run {
                    isLoggingFromChat = false
                    showingChatLogResults = false
                    appendErrorMessage("Couldn't save the meal — please try again.", userId: profile.id)
                }
                #if DEBUG
                print("[Chat] Log from analysis failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Error Helper

    private func appendErrorMessage(_ text: String, userId: UUID) {
        let msg = ChatMessage(
            id: UUID(),
            userId: userId,
            role: .assistant,
            content: text,
            createdAt: Date()
        )
        withAnimation(FuelAnimation.messagePop) {
            appState.chatMessages.append(msg)
        }
    }

    // MARK: - Build Meal Detail for Edge Function

    private func buildTodayMealsDetail() -> String? {
        let meals = appState.todayMeals
        guard !meals.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"

        // Use proper JSON encoding to avoid truncation/escape issues
        let mealDicts: [[String: Any]] = meals.prefix(10).map { meal in
            let itemDicts: [[String: Any]] = meal.items.prefix(8).map { item in
                ["name": item.name, "cal": item.calories, "p": Int(item.protein), "c": Int(item.carbs), "f": Int(item.fat)]
            }
            return [
                "id": meal.id.uuidString,
                "name": meal.displayName,
                "cal": meal.totalCalories,
                "p": Int(meal.totalProtein),
                "c": Int(meal.totalCarbs),
                "f": Int(meal.totalFat),
                "time": formatter.string(from: meal.loggedAt),
                "items": itemDicts
            ] as [String: Any]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: mealDicts),
              let json = String(data: data, encoding: .utf8) else { return nil }

        // Truncate at a safe boundary (complete meal objects)
        if json.count <= 3000 { return json }

        // Re-encode with fewer meals to stay under limit
        for limit in stride(from: meals.count - 1, through: 1, by: -1) {
            let subset = Array(mealDicts.prefix(limit))
            if let d = try? JSONSerialization.data(withJSONObject: subset),
               let s = String(data: d, encoding: .utf8),
               s.count <= 3000 {
                return s
            }
        }
        return nil
    }

    // MARK: - Daily Summary

    private func checkDailySummary() async {
        let hour = Calendar.current.component(.hour, from: Date())
        let todayStr = Date().dateString
        let key = "daily_summary_shown_\(todayStr)"

        guard hour >= 20,
              !UserDefaults.standard.bool(forKey: key),
              appState.caloriesConsumed > 0,
              let profile = appState.userProfile else { return }

        UserDefaults.standard.set(true, forKey: key)

        let consumed = appState.caloriesConsumed
        let target = appState.calorieTarget
        let remaining = target - consumed
        let proteinPct = appState.proteinTarget > 0
            ? Int(appState.proteinConsumed / Double(appState.proteinTarget) * 100) : 0

        var text: String
        if abs(remaining) <= Int(Double(target) * 0.1) {
            text = "Solid day — you're right at \(consumed) cal against your \(target) target."
        } else if consumed > target {
            text = "You went \(consumed - target) cal over today. One day won't change your trajectory — just get back to it tomorrow."
        } else {
            text = "\(remaining) cal still on the table. \(remaining > 400 ? "Make sure you're fueling enough — skipping too much can backfire." : "A small snack would close this out nicely.")"
        }

        text += " Protein: \(proteinPct)% of target."

        if let best = appState.todayMeals.max(by: { $0.totalProtein < $1.totalProtein }) {
            text += " \(best.displayName) was your strongest meal today."
        }

        let cards = [ChatCard(type: .dailySummary)]
        let message = ChatMessage(
            id: UUID(),
            userId: profile.id,
            role: .assistant,
            content: text,
            createdAt: Date(),
            cards: cards
        )

        await MainActor.run {
            isTypingResponse = true
            withAnimation(FuelAnimation.messagePop) {
                appState.chatMessages.append(message)
            }
        }
        try? await appState.databaseService?.saveChatMessage(message)
    }
}

// MARK: - Thinking Dot

private struct ThinkingDot: View {
    let delay: Double
    @State private var animating = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        Circle()
            .fill(FuelColors.stone)
            .frame(width: 7, height: 7)
            .scaleEffect(animating ? 1.0 : 0.35)
            .opacity(animating ? 0.7 : 0.15)
            .animation(.easeInOut(duration: 0.55), value: animating)
            .onAppear {
                task = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    while !Task.isCancelled {
                        animating.toggle()
                        try? await Task.sleep(nanoseconds: 550_000_000)
                    }
                }
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
    }
}
