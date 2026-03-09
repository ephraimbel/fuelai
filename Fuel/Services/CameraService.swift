import AVFoundation
import UIKit

@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isReady = false

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<UIImage, Error>?

    func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }

        session.commitConfiguration()
        isReady = true
    }

    func start() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
    }

    func capturePhoto() async throws -> UIImage {
        try await withThrowingTaskGroup(of: UIImage.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation
                    let settings = AVCapturePhotoSettings()
                    self.output.capturePhoto(with: settings, delegate: self)
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10s timeout
                throw FuelError.cameraFailed("Photo capture timed out")
            }
            guard let result = try await group.next() else {
                throw FuelError.cameraFailed("Photo capture failed")
            }
            group.cancelAll()
            return result
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            // Grab and nil-out the continuation atomically to prevent double-resume
            guard let cont = self.continuation else { return }
            self.continuation = nil

            if let error = error {
                cont.resume(throwing: error)
                return
            }

            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                cont.resume(throwing: FuelError.cameraFailed("Could not process photo"))
                return
            }

            capturedImage = image
            cont.resume(returning: image)
        }
    }
}
