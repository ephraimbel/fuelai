import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var messageText = ""
    @State private var showingPaywall = false
    @State private var isTypingResponse = false
    @FocusState private var isFocused: Bool
    @State private var sendTask: Task<Void, Never>?

    private let suggestedPrompts = [
        ("chart.bar.fill", "How's my week looking?"),
        ("fork.knife", "What should I eat for dinner?"),
        ("bolt.fill", "Am I getting enough protein?"),
        ("eye", "What patterns do you see?"),
    ]

    var body: some View {
        VStack(spacing: 0) {
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
                                    }
                                )
                                .id(message.id)
                                .padding(.bottom, messagePadding(for: message, at: index))
                            }
                        }

                        if appState.isSendingMessage {
                            thinkingIndicator
                                .id("thinking")

                            // Stop generation button
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
                                        .fill(FuelColors.cloud)
                                        .stroke(FuelColors.mist, lineWidth: 0.5)
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
                    isFocused = false
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
            }

            inputBar
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    FuelHaptics.shared.tap()
                    isFocused = false
                    withAnimation(FuelAnimation.snappy) {
                        appState.selectedTab = .home
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FuelColors.stone)
                }
                .accessibilityLabel("Back to home")
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(FuelColors.flame.opacity(0.12))
                            .frame(width: 26, height: 26)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(FuelColors.flame)
                    }
                    Text("fuel AI")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(FuelColors.ink)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !appState.chatMessages.isEmpty {
                    Button {
                        FuelHaptics.shared.tap()
                        withAnimation(FuelAnimation.smooth) {
                            appState.chatMessages.removeAll()
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
        }
        .onDisappear {
            isFocused = false
            sendTask?.cancel()
        }
        .sheet(isPresented: $showingPaywall) {
            UpgradePaywallView(reason: .chatLimit)
        }
    }

    // MARK: - Message Spacing

    private func messagePadding(for message: ChatMessage, at index: Int) -> CGFloat {
        guard index + 1 < appState.chatMessages.count else { return 0 }
        let next = appState.chatMessages[index + 1]
        return message.role == next.role ? FuelSpacing.sm : FuelSpacing.xl
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer().frame(minHeight: 80)

            VStack(spacing: FuelSpacing.lg + 4) {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [FuelColors.flame.opacity(0.10), FuelColors.flame.opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 56
                            )
                        )
                        .frame(width: 112, height: 112)

                    // Inner circle
                    Circle()
                        .fill(FuelColors.flame.opacity(0.12))
                        .frame(width: 56, height: 56)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(FuelColors.flame)
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
                                .fill(FuelColors.cloud)
                                .stroke(FuelColors.mist, lineWidth: 0.5)
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
            ZStack {
                Circle()
                    .fill(FuelColors.flame.opacity(0.12))
                    .frame(width: 30, height: 30)

                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FuelColors.flame)
            }

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

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)

            HStack(alignment: .bottom, spacing: 8) {
                // Text input
                TextField("Message...", text: $messageText, axis: .vertical)
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
                                isFocused ? FuelColors.mist : FuelColors.mist.opacity(0.5),
                                lineWidth: 0.5
                            )
                    )
                    .onSubmit {
                        sendCurrentMessage()
                    }
                    .submitLabel(.send)

                // Send button
                Button {
                    sendCurrentMessage()
                } label: {
                    Circle()
                        .fill(canSend ? FuelColors.ink : FuelColors.cloud)
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

    private func sendCurrentMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
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
                return "You've logged \(context.todayCalories) of \(context.targetCalories) calories today. \(remaining > 0 ? "You have \(remaining) cal left — want help planning your next meal?" : "You're at your target for the day.")"
            } else {
                return "Nothing logged yet today. What did you have for your first meal?"
            }
        }

        // Calorie / progress questions
        if msg.contains("calori") || msg.contains("how am i") || msg.contains("progress") || msg.contains("how much") || msg.contains("remaining") || msg.contains("left") || msg.contains("how's my") || msg.contains("week") {
            if context.todayCalories == 0 {
                return "You haven't logged anything today. Your target is \(context.targetCalories) cal. Log a meal to get started."
            }
            return "You're at \(context.todayCalories) of \(context.targetCalories) calories. \(remaining > 0 ? "\(remaining) cal remaining." : "You've hit your target.") Protein: \(Int(context.todayProtein))g of \(context.targetProtein)g."
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
        if msg.contains("what should i eat") || msg.contains("what to eat") || msg.contains("suggest") || msg.contains("recommend") || msg.contains("dinner") || msg.contains("lunch") || msg.contains("snack") || msg.contains("breakfast") || msg.contains("meal idea") {
            if remaining > 400 {
                return "You have \(remaining) cal left. \(proteinLeft > 20 ? "Prioritize protein — you need \(proteinLeft)g more." : "Your protein is solid.") A balanced meal with lean protein and vegetables would fit well."
            } else if remaining > 0 {
                return "You have \(remaining) cal remaining. A light option — Greek yogurt, a handful of nuts, or a protein shake — would close out the day."
            }
            return "You're at your calorie target. If you're still hungry, opt for something low-calorie like vegetables or broth."
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
            if context.streak > 0 {
                return "You're on a \(context.streak)-day streak. Keep logging to maintain it."
            }
            return "No active streak yet. Log a meal today to start one."
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
            var response = "Your goal is \(goalText) at \(context.targetCalories) cal/day with \(context.targetProtein)g protein. "
            response += "Start by logging your first meal — consistency is the single biggest factor in reaching any nutrition goal. "
            response += "Even rough estimates help build the habit."
            if context.streak > 0 {
                response += " You're on a \(context.streak)-day streak — log today to keep it going."
            }
            return response
        }

        var tips: [String] = []

        // Calorie analysis
        let calPct = Double(context.todayCalories) / Double(context.targetCalories) * 100
        if remaining > 500 {
            tips.append("You've only eaten \(context.todayCalories) of \(context.targetCalories) cal (\(Int(calPct))%). If you're \(goalText == "losing weight" ? "cutting" : "trying to hit your target"), make sure you're not under-eating — that can slow your metabolism and lead to overeating later.")
        } else if remaining < 0 {
            let over = abs(remaining)
            tips.append("You're \(over) cal over your \(context.targetCalories) target. Don't stress — one day over won't derail you. Tomorrow, aim to hit your target and the weekly average will balance out.")
        }

        // Protein analysis
        if proteinLeft > 30 {
            tips.append("You still need \(proteinLeft)g protein. Protein is key for \(goalText == "losing weight" ? "preserving muscle while cutting" : goalText == "gaining weight" ? "building muscle" : "staying full and maintaining lean mass"). Try adding Greek yogurt (15g), eggs (6g each), or a chicken breast (31g) to close the gap.")
        } else if proteinLeft <= 0 {
            tips.append("Protein is on point at \(Int(context.todayProtein))g — that's solid for \(goalText).")
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
        if context.streak >= 7 {
            tips.append("You're on a \(context.streak)-day streak. That consistency is what drives real results — keep it going.")
        } else if context.streak > 0 {
            tips.append("\(context.streak)-day streak. Build toward 7 days — that's where the habit starts to stick.")
        }

        // Goal-specific tip
        if tips.count < 3 {
            switch context.goalType {
            case "lose":
                tips.append("For fat loss, prioritize protein at every meal, eat plenty of vegetables for volume, and don't skip meals — it leads to overeating later.")
            case "gain":
                tips.append("For gaining, eat calorie-dense foods like nuts, avocado, and olive oil. Spread protein across 4+ meals for better absorption.")
            default:
                tips.append("For maintenance, focus on consistent meal timing and hitting your protein target daily. The rest tends to fall into place.")
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
        guard let profile = appState.userProfile else { return }
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
            userId: profile.id,
            role: .user,
            content: text,
            createdAt: Date()
        )
        withAnimation(FuelAnimation.messagePop) {
            appState.chatMessages.append(userMessage)
        }

        sendTask = Task {
            try? await appState.databaseService?.saveChatMessage(userMessage)

            let context = UserContext(
                targetCalories: appState.calorieTarget,
                targetProtein: appState.proteinTarget,
                todayCalories: appState.caloriesConsumed,
                todayProtein: appState.proteinConsumed,
                todayCarbs: appState.carbsConsumed,
                todayFat: appState.fatConsumed,
                goalType: profile.goalType?.rawValue ?? "maintain",
                recentMeals: appState.todayMeals.map { $0.displayName },
                streak: appState.currentStreak
            )

            var responseText: String?
            var responseCards: [ChatCard]?

            // Try AI service with timeout
            if appState.aiService != nil {
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
                userId: profile.id,
                role: .assistant,
                content: finalText,
                createdAt: Date(),
                cards: responseCards
            )

            // Only count against rate limit if AI service was actually used
            if responseText != nil {
                RateLimiter.recordChat()
            }

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
