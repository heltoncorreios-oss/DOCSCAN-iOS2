import AVFoundation
import SwiftUI
import UIKit

/// Exibe a câmera e desenha o contorno usando as conversões reais do preview layer.
/// Isso mantém o quadrilátero alinhado mesmo com resizeAspectFill, rotação e recorte.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let rectangle: DocumentRectangle?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.configure(session: session)
        view.documentRectangle = rectangle
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.configure(session: session)
        uiView.documentRectangle = rectangle
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    var documentRectangle: DocumentRectangle? {
        didSet {
            updateRectanglePath()
        }
    }

    private let rectangleLayer = CAShapeLayer()
    private weak var configuredSession: AVCaptureSession?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureRectangleLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureRectangleLayer()
    }

    private func configureRectangleLayer() {
        rectangleLayer.fillColor = UIColor.clear.cgColor
        rectangleLayer.strokeColor = UIColor.systemGreen.cgColor
        rectangleLayer.lineWidth = 3
        rectangleLayer.lineJoin = .round
        rectangleLayer.lineCap = .round
        rectangleLayer.contentsScale = UIScreen.main.scale
        previewLayer.addSublayer(rectangleLayer)
    }

    func configure(session: AVCaptureSession) {
        if configuredSession !== session {
            previewLayer.session = session
            configuredSession = session
        }

        previewLayer.videoGravity = .resizeAspectFill

        if let connection = previewLayer.connection,
           connection.isVideoRotationAngleSupported(90),
           connection.videoRotationAngle != 90 {
            connection.videoRotationAngle = 90
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rectangleLayer.frame = previewLayer.bounds
        updateRectanglePath()
    }

    private func updateRectanglePath() {
        guard bounds.width > 0, bounds.height > 0,
              let rectangle = documentRectangle else {
            rectangleLayer.path = nil
            return
        }

        // Vision usa origem inferior-esquerda. A conversão do preview layer
        // espera pontos normalizados do dispositivo com origem superior-esquerda.
        func previewPoint(from visionPoint: CGPoint) -> CGPoint {
            let devicePoint = CGPoint(
                x: visionPoint.x,
                y: 1.0 - visionPoint.y
            )
            return previewLayer.layerPointConverted(
                fromCaptureDevicePoint: devicePoint
            )
        }

        let topLeft = previewPoint(from: rectangle.topLeft)
        let topRight = previewPoint(from: rectangle.topRight)
        let bottomRight = previewPoint(from: rectangle.bottomRight)
        let bottomLeft = previewPoint(from: rectangle.bottomLeft)

        let path = UIBezierPath()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.close()

        rectangleLayer.path = path.cgPath
    }
}
