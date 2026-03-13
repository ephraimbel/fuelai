import SwiftUI

struct ShowcasePhoneFrame<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // iPhone 15 Pro real proportions: 393 x 852 = 0.461 aspect
    private let phoneAspect: CGFloat = 0.462
    private let bezel: CGFloat = 4
    private let outerRadius: CGFloat = 50
    private let innerRadius: CGFloat = 46
    private let islandWidth: CGFloat = 100
    private let islandHeight: CGFloat = 30
    private let statusBarHeight: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let phoneWidth = min(geo.size.width, geo.size.height * phoneAspect)
            let phoneHeight = phoneWidth / phoneAspect

            ZStack(alignment: .top) {
                // Outer titanium band
                RoundedRectangle(cornerRadius: outerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#3A3A3E"),
                                Color(hex: "#1C1C1E"),
                                Color(hex: "#2E2E32"),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Inner black chassis
                RoundedRectangle(cornerRadius: outerRadius - 1)
                    .fill(Color.black)
                    .padding(1.5)

                // Screen (white base)
                RoundedRectangle(cornerRadius: innerRadius)
                    .fill(FuelColors.white)
                    .padding(bezel)

                // Content — clipped to screen
                content
                    .frame(width: phoneWidth - bezel * 2, height: phoneHeight - bezel * 2)
                    .clipShape(RoundedRectangle(cornerRadius: innerRadius))
                    .padding(.top, bezel)

                // Dynamic island (on top of content)
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: islandWidth, height: islandHeight)
                        .padding(.top, bezel + 10)
                    Spacer()
                }

                // Home indicator
                VStack {
                    Spacer()
                    Capsule()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: phoneWidth * 0.34, height: 4)
                        .padding(.bottom, bezel + 8)
                }

                // Side buttons — right (power)
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#3A3A3E"), Color(hex: "#28282C")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 3, height: 36)
                        .offset(x: 1.5, y: phoneHeight * 0.22)
                }

                // Side buttons — left (volume + silent)
                HStack {
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: "#2E2E32"))
                            .frame(width: 3, height: 16)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: "#2E2E32"))
                            .frame(width: 3, height: 26)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: "#2E2E32"))
                            .frame(width: 3, height: 26)
                    }
                    .offset(x: -1.5, y: phoneHeight * 0.15)

                    Spacer()
                }
            }
            .frame(width: phoneWidth, height: phoneHeight)
            .shadow(color: Color.black.opacity(0.2), radius: 30, y: 16)
            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(phoneAspect, contentMode: .fit)
        .frame(maxHeight: 440)
    }
}
