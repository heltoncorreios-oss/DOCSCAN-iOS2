
import AVFoundation
import Combine
import Foundation
import UIKit
import Vision

/// Gerencia autorização, câmera, zoom, detecção e captura.
final class DocumentScannerService: NSObject, ObservableObject {

    @Published private(set) var isAuthorized = false
    @Published private(set) var isRunning = false
    @Published private(set) var detectedRectangle: DocumentRectangle?
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var errorMessage: String?
    @Published private(set) var zoomFactor: CGFloat = 1

    #if targetEnvironment(simulator)
    @Published private(set) var isSimulator = true
    #else
    @Published private(set) var isSimulator = false
    #endif

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.docscan.camera.session")
    private let videoQueue = DispatchQueue(label: "com.docscan.camera.frames")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()

    private var configured = false
    private var lastDetectionTime = Date.distantPast
    private var activeDevice: AVCaptureDevice?

    func start() async {

        // No simulador, não tenta acessar uma câmera física.
       if isSimulator {
    await MainActor.run {
        self.isAuthorized = false
        self.isRunning = false
        self.errorMessage = nil
    }
    return
}

        let granted: Bool

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            granted = true

        case .notDetermined:
            granted = await AVCaptureDevice.requestAccess(for: .video)

        default:
            granted = false
        }

        await MainActor.run {
            self.isAuthorized = granted
        }

        guard granted else {
            await MainActor.run {
                self.errorMessage = "Permita o acesso à câmera em Ajustes para digitalizar documentos."
            }
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                if !self.configured {
                    try self.configureSession()
                }

                if !self.session.isRunning {
                    self.session.startRunning()
                }

                DispatchQueue.main.async {
                    self.isRunning = true
                    self.errorMessage = nil
                }

            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Não foi possível iniciar a câmera: \(error.localizedDescription)"
                }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.session.isRunning {
                self.session.stopRunning()
            }

            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func setZoom(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeDevice else { return }

            let zoom = min(max(factor, 1), device.activeFormat.videoMaxZoomFactor)

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = zoom
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.zoomFactor = zoom
                }

            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Não foi possível ajustar o zoom."
                }
            }
        }
    }

    func capture() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }

            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality

            if let connection = self.photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }

            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Recebe uma imagem selecionada pelo usuário.
    /// Utilizado pelo seletor de fotos no simulador e no iPhone.
    func useImage(_ image: UIImage) {
        capturedImage = image
        detectedRectangle = nil
        errorMessage = nil
    }

    func retake() {
        capturedImage = nil
        detectedRectangle = nil
    }

    func clearError() {
        errorMessage = nil
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo

        defer {
            session.commitConfiguration()
        }

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            throw ScannerError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)

        guard session.canAddInput(input) else {
            throw ScannerError.cannotAddCamera
        }

        session.addInput(input)
        activeDevice = camera

        guard session.canAddOutput(photoOutput) else {
            throw ScannerError.cannotAddPhotoOutput
        }

        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        guard session.canAddOutput(videoOutput) else {
            throw ScannerError.cannotAddVideoOutput
        }

        session.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        configured = true
    }

    private func detectRectangle(in sampleBuffer: CMSampleBuffer) {
        guard Date().timeIntervalSince(lastDetectionTime) > 0.18 else {
            return
        }

        lastDetectionTime = Date()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.60
        request.minimumSize = 0.18
        request.quadratureTolerance = 25

        do {
            try VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: .up
            ).perform([request])

            let rectangle = request.results?.first.map {
                DocumentRectangle(
                    topLeft: $0.topLeft,
                    topRight: $0.topRight,
                    bottomLeft: $0.bottomLeft,
                    bottomRight: $0.bottomRight
                )
            }

            DispatchQueue.main.async {
                self.detectedRectangle = rectangle
            }

        } catch {
            // Falhas isoladas não interrompem a câmera.
        }
    }

    private enum ScannerError: LocalizedError {
        case cameraUnavailable
        case cannotAddCamera
        case cannotAddPhotoOutput
        case cannotAddVideoOutput

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable:
                return "Câmera traseira não encontrada."
            case .cannotAddCamera:
                return "Não foi possível configurar a câmera."
            case .cannotAddPhotoOutput:
                return "Não foi possível configurar a captura de fotos."
            case .cannotAddVideoOutput:
                return "Não foi possível iniciar a detecção de documentos."
            }
        }
    }
}

struct DocumentRectangle: Equatable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
}

extension DocumentScannerService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        detectRectangle(in: sampleBuffer)
    }
}

extension DocumentScannerService: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            DispatchQueue.main.async {
                self.errorMessage = "Erro ao capturar: \(error.localizedDescription)"
            }
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                self.errorMessage = "Não foi possível ler a imagem capturada."
            }
            return
        }

        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}
