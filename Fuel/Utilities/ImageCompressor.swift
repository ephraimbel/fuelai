import UIKit
import CoreImage
import Accelerate

struct ImageCompressor {
    static func compress(_ image: UIImage, maxBytes: Int = Constants.maxImageSizeBytes, quality: CGFloat = Constants.imageCompressionQuality) -> Data? {
        // Reject zero-size or corrupted images early
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        // Auto-enhance dark/low-contrast images for better food recognition
        let enhanced = autoEnhance(image)
        // 1024px is sufficient for AI food recognition (Claude vision) while keeping payload small.
        // Always re-render to strip EXIF metadata (location, device info)
        let downsampled = downsample(enhanced, maxDimension: 1024, forceRerender: true)
        var compression = quality
        guard var data = downsampled.jpegData(compressionQuality: compression) else { return nil }

        while data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            guard let newData = downsampled.jpegData(compressionQuality: compression) else { return data }
            data = newData
        }
        return data
    }

    static func downsample(_ image: UIImage, maxDimension: CGFloat, forceRerender: Bool = false) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        if !forceRerender && maxSide <= maxDimension { return image }

        let scale = min(maxDimension / maxSide, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    static func thumbnail(_ image: UIImage, size: CGSize = Constants.thumbnailSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Image Quality

    /// Detect if an image is too dark or low-contrast and auto-enhance it.
    /// Only applies corrections when needed — well-lit photos pass through unchanged.
    static func autoEnhance(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let context = CIContext(options: [.useSoftwareRenderer: false])

        // Measure average brightness
        let brightness = averageBrightness(ciImage: ciImage)

        // Only enhance if image is dark (brightness < 0.35)
        guard brightness < 0.35 else { return image }

        // Use CIExposureAdjust for dark images
        let exposureBoost = min(1.5, (0.4 - brightness) * 4.0) // Scale boost to how dark it is
        guard let filter = CIFilter(name: "CIExposureAdjust") else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(exposureBoost, forKey: kCIInputEVKey)

        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Estimate image blurriness using Laplacian variance.
    /// Lower values = more blurry. Threshold ~100 for "usable" food photos.
    static func blurScore(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0 }
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()

        // Downsample for speed
        let small = ciImage.transformed(by: CGAffineTransform(scaleX: 0.25, y: 0.25))
        guard let filter = CIFilter(name: "CILaplacian") else { return 100 }
        filter.setValue(small, forKey: kCIInputImageKey)

        // Fallback: use edge detection as proxy
        guard let edgeFilter = CIFilter(name: "CIEdges") else { return 100 }
        edgeFilter.setValue(small, forKey: kCIInputImageKey)
        edgeFilter.setValue(5.0, forKey: "inputIntensity")

        guard let output = edgeFilter.outputImage else { return 100 }

        // Average the edge intensity
        let extent = output.extent
        guard extent.width > 0, extent.height > 0 else { return 100 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(output.clampedToExtent().cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1)),
                      toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        return Double(bitmap[0] + bitmap[1] + bitmap[2]) / 3.0
    }

    /// Check if the image quality is sufficient for food analysis.
    /// Returns nil if OK, or a warning string if quality is poor.
    static func qualityWarning(_ image: UIImage) -> String? {
        let size = image.size
        let minDim = min(size.width, size.height)
        if minDim < 200 {
            return "Image resolution is very low — results may be inaccurate"
        }

        guard let ciImage = CIImage(image: image) else { return nil }
        let brightness = averageBrightness(ciImage: ciImage)
        if brightness < 0.15 {
            return "Image is very dark — consider retaking with better lighting"
        }

        return nil
    }

    private static func averageBrightness(ciImage: CIImage) -> Double {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0.5 }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: ciImage.extent), forKey: "inputExtent")

        guard let output = filter.outputImage else { return 0.5 }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        // Perceived brightness (ITU-R BT.601)
        return (0.299 * Double(pixel[0]) + 0.587 * Double(pixel[1]) + 0.114 * Double(pixel[2])) / 255.0
    }
}
