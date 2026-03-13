import AVFoundation
import SwiftUI

struct BarcodeLogView: View {
    let onScan: (String) -> Void
    var onSwitchToCamera: (() -> Void)? = nil
    @StateObject private var scanner = BarcodeScanner()
    @State private var hasScanned = false
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @Environment(\.scenePhase) private var scenePhase

    private var hasCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    var body: some View {
        ZStack {
            if hasCamera && cameraPermission == .authorized {
                // Camera preview
                CameraPreviewView(session: scanner.session)
                    .ignoresSafeArea()

                // Scan overlay
                VStack(spacing: 0) {
                    Spacer()

                    // Scan frame
                    ZStack {
                        RoundedRectangle(cornerRadius: FuelRadius.md)
                            .stroke(FuelColors.flame, lineWidth: 2)
                            .frame(width: 280, height: 100)
                            .background(
                                RoundedRectangle(cornerRadius: FuelRadius.md)
                                    .fill(FuelColors.shadow.opacity(0.05))
                            )

                        // Animated scan line
                        if !hasScanned {
                            ScanLineView()
                                .frame(width: 260)
                                .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                        }
                    }

                    Text(hasScanned ? "Barcode detected!" : "Align barcode within frame")
                        .font(FuelType.caption)
                        .foregroundStyle(FuelColors.onDark)
                        .padding(.horizontal, FuelSpacing.lg)
                        .padding(.vertical, FuelSpacing.sm)
                        .background(Capsule().fill(FuelColors.shadow.opacity(0.5)))
                        .padding(.top, FuelSpacing.md)

                    Spacer()

                    // Switch to camera button
                    if let onSwitchToCamera {
                        Button {
                            FuelHaptics.shared.tap()
                            onSwitchToCamera()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 52, height: 52)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(FuelColors.onDark)
                            }
                        }
                        .padding(.bottom, FuelSpacing.xxl + FuelSpacing.lg)
                    }
                }
                .accessibilityLabel(hasScanned ? "Barcode detected" : "Barcode scanner active")
                .accessibilityHint("Point camera at a barcode to scan it")
            } else if cameraPermission == .denied || cameraPermission == .restricted {
                permissionDeniedView
            } else if !hasCamera {
                noCameraView
            } else {
                FuelColors.white
                    .onAppear { requestPermission() }
            }
        }
        .onAppear {
            cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
            if cameraPermission == .authorized && hasCamera {
                scanner.configure()
            } else if cameraPermission == .notDetermined {
                requestPermission()
            }
        }
        .onDisappear {
            scanner.stop()
        }
        .onChange(of: scanner.scannedCode) { _, code in
            guard let code, !hasScanned else { return }
            hasScanned = true
            scanner.stop()
            FuelHaptics.shared.scan()
            onScan(code)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !hasScanned else { return }
            let newStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if newStatus != cameraPermission {
                cameraPermission = newStatus
                if newStatus == .authorized && hasCamera {
                    scanner.configure()
                }
            }
        }
    }

    // MARK: - No Camera View

    private var noCameraView: some View {
        VStack(spacing: FuelSpacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(FuelColors.cloud)
                    .frame(width: 88, height: 88)
                Image(systemName: "barcode.viewfinder")
                    .font(FuelType.title)
                    .foregroundStyle(FuelColors.stone)
            }
            Text("Camera required for barcode scanning")
                .font(FuelType.body)
                .foregroundStyle(FuelColors.stone)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(FuelColors.white)
    }

    // MARK: - Permission Denied

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
                    Text("Allow camera access to scan barcodes")
                        .font(FuelType.body)
                        .foregroundStyle(FuelColors.stone)
                }
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(FuelType.cardTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FuelSpacing.lg)
                    .background(FuelColors.buttonFill)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
            }
            .padding(.horizontal, FuelSpacing.xl)
            Spacer()
        }
        .background(FuelColors.white)
    }

    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraPermission = granted ? .authorized : .denied
                if granted && hasCamera {
                    scanner.configure()
                }
            }
        }
    }
}

// MARK: - Scan Line Animation

private struct ScanLineView: View {
    @State private var offset: CGFloat = -40

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [FuelColors.flame.opacity(0), FuelColors.flame.opacity(0.6), FuelColors.flame.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    offset = 40
                }
            }
    }
}
