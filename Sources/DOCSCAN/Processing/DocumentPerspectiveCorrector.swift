import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UIKit
import Vision

/// Detecta os cantos na foto em resolução completa e corrige a perspectiva.
struct DocumentPerspectiveCorrector {
    private let context = CIContext()

    /// Retorna os cantos normalizados com origem no canto superior esquerdo.
    /// A ordem é: superior esquerdo, superior direito, inferior direito, inferior esquerdo.
    func detectCorners(in image: UIImage) throws -> DocumentCropCorners? {
        let normalized = try normalizedCGImage(from: image)

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.45
        request.minimumSize = 0.12
        request.quadratureTolerance = 30
        request.minimumAspectRatio = 0.45
        request.maximumAspectRatio = 1.0

        try VNImageRequestHandler(cgImage: normalized, orientation: .up).perform([request])

        guard let observation = request.results?.first else {
            return nil
        }

        // Vision usa origem inferior-esquerda. A interface de edição usa superior-esquerda.
        func topOrigin(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x, y: 1.0 - point.y)
        }

        return DocumentCropCorners(
            topLeft: topOrigin(observation.topLeft),
            topRight: topOrigin(observation.topRight),
            bottomRight: topOrigin(observation.bottomRight),
            bottomLeft: topOrigin(observation.bottomLeft)
        )
    }

    /// Aplica CIPerspectiveCorrection usando cantos normalizados de origem superior-esquerda.
    func correct(image: UIImage, corners: DocumentCropCorners) throws -> UIImage {
        let cgImage = try normalizedCGImage(from: image)
        let input = CIImage(cgImage: cgImage)
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        func coreImagePoint(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * width, y: (1.0 - point.y) * height)
        }

        let filter = CIFilter.perspectiveCorrection()
        filter.topLeft = coreImagePoint(corners.topLeft)
filter.topRight = coreImagePoint(corners.topRight)
filter.bottomRight = coreImagePoint(corners.bottomRight)
filter.bottomLeft = coreImagePoint(corners.bottomLeft)
        guard let output = filter.outputImage else {
            throw PerspectiveError.correctionFailed
        }

        let extent = output.extent.integral
        guard !extent.isEmpty, let result = context.createCGImage(output, from: extent) else {
            throw PerspectiveError.correctionFailed
        }

        return UIImage(cgImage: result, scale: image.scale, orientation: .up)
    }

    /// Desenha a UIImage em um bitmap novo para remover metadados de orientação
    /// antes da análise e manter a geometria da foto consistente.
    private func normalizedCGImage(from image: UIImage) throws -> CGImage {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        guard let cgImage = normalized.cgImage else {
            throw PerspectiveError.invalidImage
        }
        return cgImage
    }

    enum PerspectiveError: LocalizedError {
        case invalidImage
        case correctionFailed

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Não foi possível preparar a imagem para o recorte."
            case .correctionFailed:
                return "Não foi possível corrigir a perspectiva. Ajuste os cantos e tente novamente."
            }
        }
    }
}

/// Cantos normalizados (0...1), com origem no canto superior esquerdo.
struct DocumentCropCorners: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    var points: [CGPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }

    init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    init(points: [CGPoint]) {
        self.init(
            topLeft: points[0],
            topRight: points[1],
            bottomRight: points[2],
            bottomLeft: points[3]
        )
    }
}
