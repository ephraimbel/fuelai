import AVFoundation
import PhotosUI
import SwiftUI

struct CameraLogView: View {
    let onCapture: (Data, String?) -> Void
    @StateObject private var cameraService = CameraService()
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var captureError: String?
    @State private var isCapturing = false
    @Environment(\.scenePhase) private var scenePhase

    private var hasCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if hasCamera && cameraPermission == .authorized {
                // Live camera preview
                CameraPreviewView(session: cameraService.session)
                    .ignoresSafeArea()

                // Viewfinder brackets
                viewfinderOverlay

                // Bottom controls
                cameraControls
            } else if cameraPermission == .denied || cameraPermission == .restricted {
                // Permission denied
                permissionDeniedView
            } else if !hasCamera {
                // No camera (simulator) — show photo picker fallback
                noCameraView
            } else {
                // Requesting permission
                FuelColors.shadow.ignoresSafeArea()
                    .onAppear { requestPermission() }
            }
        }
        .overlay(alignment: .top) {
            if let error = captureError {
                Text(error)
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.onDark)
                    .padding(.horizontal, FuelSpacing.lg)
                    .padding(.vertical, FuelSpacing.sm)
                    .background(Capsule().fill(FuelColors.over.opacity(0.9)))
                    .padding(.top, FuelSpacing.xxl)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { captureError = nil }
                        }
                    }
            }
        }
        .animation(FuelAnimation.smooth, value: captureError != nil)
        .onAppear {
            cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
            if cameraPermission == .authorized && hasCamera {
                cameraService.configure()
                cameraService.start()
            } else if cameraPermission == .notDetermined {
                requestPermission()
            }
        }
        .onDisappear {
            cameraService.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let newStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if newStatus != cameraPermission {
                cameraPermission = newStatus
                if newStatus == .authorized && hasCamera {
                    cameraService.configure()
                    cameraService.start()
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            // Reset so the same photo can be re-picked (onChange needs value change)
            selectedPhotoItem = nil
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw NSError(domain: "Fuel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load photo"])
                    }
                    guard let image = UIImage(data: data) else {
                        throw NSError(domain: "Fuel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not read image"])
                    }
                    guard let compressed = ImageCompressor.compress(image) else {
                        throw NSError(domain: "Fuel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not process photo"])
                    }
                    onCapture(compressed, nil)
                } catch {
                    FuelHaptics.shared.error()
                    captureError = "Could not load photo. Please try another."
                }
            }
        }
    }

    // MARK: - Viewfinder Overlay

    private var viewfinderOverlay: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.72
            let len: CGFloat = 32
            let lw: CGFloat = 3
            let r: CGFloat = 12
            let color = Color.white.opacity(0.8)

            ZStack {
                // Top-left
                CornerBracket(length: len, lineWidth: lw, radius: r)
                    .stroke(color, lineWidth: lw)
                    .frame(width: len, height: len)
                    .position(x: (geo.size.width - side) / 2 + len / 2,
                              y: (geo.size.height - side) / 2 + len / 2 - 40)

                // Top-right
                CornerBracket(length: len, lineWidth: lw, radius: r)
                    .stroke(color, lineWidth: lw)
                    .frame(width: len, height: len)
                    .rotationEffect(.degrees(90))
                    .position(x: (geo.size.width + side) / 2 - len / 2,
                              y: (geo.size.height - side) / 2 + len / 2 - 40)

                // Bottom-left
                CornerBracket(length: len, lineWidth: lw, radius: r)
                    .stroke(color, lineWidth: lw)
                    .frame(width: len, height: len)
                    .rotationEffect(.degrees(-90))
                    .position(x: (geo.size.width - side) / 2 + len / 2,
                              y: (geo.size.height + side) / 2 - len / 2 - 40)

                // Bottom-right
                CornerBracket(length: len, lineWidth: lw, radius: r)
                    .stroke(color, lineWidth: lw)
                    .frame(width: len, height: len)
                    .rotationEffect(.degrees(180))
                    .position(x: (geo.size.width + side) / 2 - len / 2,
                              y: (geo.size.height + side) / 2 - len / 2 - 40)

                // Hint text
                Text("Center your food")
                    .font(FuelType.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .position(x: geo.size.width / 2,
                              y: (geo.size.height + side) / 2 - 40 + FuelSpacing.xl)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Camera Controls

    private var cameraControls: some View {
        HStack(spacing: FuelSpacing.xxl) {
            // Photo library
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    Image(systemName: "photo.on.rectangle")
                        .font(FuelType.iconMd)
                        .foregroundStyle(FuelColors.onDark)
                }
            }

            // Capture button
            Button {
                capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(isCapturing ? 0.5 : 1.0))
                        .frame(width: 72, height: 72)
                    Circle()
                        .stroke(.white.opacity(0.5), lineWidth: 4)
                        .frame(width: 82, height: 82)
                }
                .scaleEffect(isCapturing ? 0.92 : 1.0)
                .animation(FuelAnimation.snappy, value: isCapturing)
            }
            .disabled(isCapturing)
            .accessibilityLabel("Take photo")
            .accessibilityHint("Captures a photo of your food for nutrition analysis")

            // Spacer for symmetry
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.bottom, FuelSpacing.xxl + FuelSpacing.lg)
    }

    // MARK: - No Camera View

    private var noCameraView: some View {
        VStack(spacing: FuelSpacing.xl) {
            Spacer()

            VStack(spacing: FuelSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(FuelColors.cloud)
                        .frame(width: 88, height: 88)
                    Image(systemName: "camera")
                        .font(FuelType.title)
                        .foregroundStyle(FuelColors.stone)
                }

                VStack(spacing: FuelSpacing.sm) {
                    Text("No Camera Available")
                        .font(FuelType.section)
                        .foregroundStyle(FuelColors.ink)

                    Text("Choose a photo from your library instead")
                        .font(FuelType.body)
                        .foregroundStyle(FuelColors.stone)
                        .multilineTextAlignment(.center)
                }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text("Choose Photo")
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.onDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FuelSpacing.lg)
                    .background(FuelColors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
            }
            .padding(.horizontal, FuelSpacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FuelColors.white)
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: FuelSpacing.xl) {
            Spacer()

            VStack(spacing: FuelSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(FuelColors.cloud)
                        .frame(width: 88, height: 88)
                    Image(systemName: "camera.fill")
                        .font(FuelType.title)
                        .foregroundStyle(FuelColors.stone)
                }

                VStack(spacing: FuelSpacing.sm) {
                    Text("Camera Access Needed")
                        .font(FuelType.section)
                        .foregroundStyle(FuelColors.ink)

                    Text("Allow camera access in Settings to scan your meals")
                        .font(FuelType.body)
                        .foregroundStyle(FuelColors.stone)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FuelSpacing.xl)
                }
            }

            VStack(spacing: FuelSpacing.md) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(FuelType.cardTitle)
                        .foregroundStyle(FuelColors.onDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.lg)
                        .background(FuelColors.ink)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text("Choose from Library")
                        .font(FuelType.cardTitle)
                        .foregroundStyle(FuelColors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.lg)
                        .background(FuelColors.cloud)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                }
            }
            .padding(.horizontal, FuelSpacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FuelColors.white)
    }

    // MARK: - Actions

    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraPermission = granted ? .authorized : .denied
                if granted && hasCamera {
                    cameraService.configure()
                    cameraService.start()
                }
            }
        }
    }

    private func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        Task {
            do {
                let image = try await cameraService.capturePhoto()
                FuelHaptics.shared.scan()
                if let data = ImageCompressor.compress(image) {
                    onCapture(data, nil)
                } else {
                    FuelHaptics.shared.error()
                    captureError = "Could not process photo. Please try again."
                }
            } catch {
                FuelHaptics.shared.error()
                captureError = "Capture failed. Please try again."
            }
            isCapturing = false
        }
    }
}

// MARK: - Corner Bracket Shape

private struct CornerBracket: Shape {
    let length: CGFloat
    let lineWidth: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Top-left corner bracket: vertical line down + arc + horizontal line right
        p.move(to: CGPoint(x: 0, y: length))
        p.addLine(to: CGPoint(x: 0, y: radius))
        p.addQuadCurve(
            to: CGPoint(x: radius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        p.addLine(to: CGPoint(x: length, y: 0))
        return p
    }
}
