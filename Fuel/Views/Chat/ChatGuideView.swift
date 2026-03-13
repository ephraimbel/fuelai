import SwiftUI

struct ChatGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, color: Color, title: String, description: String, examples: [String])] = [
        (
            "fork.knife",
            FuelColors.flame,
            "Meal Planning",
            "Get a personalized meal plan built around your remaining calories and macros for the day.",
            ["Plan my meals today", "What should I eat for dinner?", "I have 600 cal left, plan my evening"]
        ),
        (
            "mappin.circle.fill",
            FuelColors.flame,
            "Restaurant Mode",
            "Tell me where you're eating and I'll build you the best order for your goals — with real menu items.",
            ["Help me order at Chipotle", "I'm at Sweetgreen", "What should I get at Chick-fil-A?"]
        ),
        (
            "pencil.circle.fill",
            FuelColors.protein,
            "Meal Editing",
            "Swap, remove, or adjust items from meals you've already logged. I'll show you exactly what changes.",
            ["Swap the rice for cauliflower rice", "Remove the cheese from my lunch", "I actually had a large not medium"]
        ),
        (
            "cart.fill",
            FuelColors.success,
            "Grocery Lists",
            "Get a weekly shopping list based on your targets. Copy it or share it straight from the chat.",
            ["Make me a grocery list", "What should I buy for the week?", "Grocery list for meal prep"]
        ),
        (
            "clock.fill",
            FuelColors.flame,
            "Meal Prep Coach",
            "Get a batch cooking plan for the week with organized prep sessions, cooking instructions, and a shopping list.",
            ["Meal prep plan for the week", "Batch cook for 5 days", "Sunday prep plan"]
        ),
        (
            "arrow.triangle.2.circlepath",
            FuelColors.fat,
            "Smart Substitutions",
            "Find healthier or macro-friendly swaps for any food. I'll compare the options side by side.",
            ["What can I eat instead of rice?", "Low carb swap for pasta", "Healthier alternative to fries"]
        ),
        (
            "refrigerator.fill",
            FuelColors.success,
            "Fridge Mode",
            "Tell me what ingredients you have and I'll build a complete meal with macros and cooking steps.",
            ["I have chicken, rice & broccoli", "What can I make with eggs and spinach?", "Only have ground beef and potatoes"]
        ),
        (
            "arrow.counterclockwise.circle.fill",
            FuelColors.protein,
            "Streak Recovery",
            "Had an off day? I'll build a recovery plan to get you back on track without the guilt trip.",
            ["I went way over yesterday", "Had a cheat day, help me recover", "I fell off track this week"]
        ),
        (
            "chart.bar.fill",
            FuelColors.fat,
            "Progress Check-ins",
            "Ask how you're doing and I'll pull up your live stats — calories, macros, streaks, trends.",
            ["How's my week looking?", "Am I getting enough protein?", "Give me a daily recap"]
        ),
        (
            "text.bubble.fill",
            FuelColors.carbs,
            "Nutrition Coaching",
            "Ask me anything about food, diets, supplements, or nutrition. I'll give it to you straight.",
            ["Is intermittent fasting worth it?", "Best high-protein snacks?", "How much water should I drink?"]
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: FuelSpacing.md) {
                        Image("FlameIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)

                        Text("What Fuel AI Can Do")
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .foregroundStyle(FuelColors.ink)

                        Text("Your personal nutrition coach — not a generic chatbot")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(FuelColors.stone)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, FuelSpacing.xl)
                    .padding(.bottom, FuelSpacing.xxl)

                    // Feature cards
                    VStack(spacing: FuelSpacing.md) {
                        ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                            featureCard(feature)
                                .staggeredAppear(index: index)
                        }
                    }
                    .padding(.horizontal, FuelSpacing.lg)

                    // Footer
                    VStack(spacing: FuelSpacing.sm) {
                        Text("Just type naturally — I'll figure out what you need.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FuelColors.stone)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, FuelSpacing.xxl)
                    .padding(.bottom, FuelSpacing.section)
                }
            }
            .scrollIndicators(.hidden)
            .background(FuelColors.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        FuelHaptics.shared.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FuelColors.stone)
                            .frame(width: 32, height: 32)
                            .background(FuelColors.cloud)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private func featureCard(_ feature: (icon: String, color: Color, title: String, description: String, examples: [String])) -> some View {
        VStack(alignment: .leading, spacing: FuelSpacing.md) {
            // Icon + Title
            HStack(spacing: 10) {
                Image(systemName: feature.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(feature.color)
                    .frame(width: 32, height: 32)
                    .background(feature.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(feature.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FuelColors.ink)
            }

            // Description
            Text(feature.description)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(FuelColors.stone)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Example prompts
            VStack(alignment: .leading, spacing: 6) {
                Text("Try saying")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FuelColors.fog)
                    .textCase(.uppercase)
                    .tracking(0.5)

                FlowLayout(spacing: 6) {
                    ForEach(feature.examples, id: \.self) { example in
                        Text(example)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(FuelColors.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(FuelColors.cloud)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
    }
}

// MARK: - Flow Layout for wrapping tags

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}
