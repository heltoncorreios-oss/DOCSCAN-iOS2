import Foundation
import Vision
import AVFoundation

/// Contrato inicial para o pipeline de captura e detecção do DOCSCAN.
/// A implementação AVFoundation/Vision será adicionada na etapa de câmera.
protocol DocumentScannerServiceProtocol {
    func requestCameraAuthorization() async -> Bool
}

final class DocumentScannerService: DocumentScannerServiceProtocol {
    func requestCameraAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}
