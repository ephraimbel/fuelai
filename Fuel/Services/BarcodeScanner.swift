import AVFoundation

@MainActor
final class BarcodeScanner: NSObject, ObservableObject {
    @Published var scannedCode: String?

    let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()

    private var isConfigured = false

    func configure() {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce]
        }

        session.commitConfiguration()
        isConfigured = true
    }

    func start() {
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
    }
}

extension BarcodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else { return }

        Task { @MainActor in
            self.scannedCode = code
        }
    }
}
