import SwiftUI
import UIKit

/// Tela de revisão do documento: detecção inicial, ajuste manual dos cantos e correção.
struct DocumentCropEditorView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onComplete: () -> Void

    @State private var points: [CGPoint] = [
        CGPoint(x: 0.04, y: 0.04),
        CGPoint(x: 0.96, y: 0.04),
        CGPoint(x: 0.96, y: 0.96),
        CGPoint(x: 0.04, y: 0.96)
    ]
    @State private var correctedImage: UIImage?
    @State private var isDetecting = true
    @State private var isProcessing = false
    @State private var dragOrigins: [Int: CGPoint] = [:]
    @State private var message = "Identificando os limites do documento..."

    private let corrector = DocumentPerspectiveCorrector()

    var body: some View {
        VStack(spacing: 0) {
            if let correctedImage {
                Image(uiImage: correctedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(12)

                Text("Perspectiva corrigida. Confira o resultado antes de concluir.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 20)
            } else {
                editorCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text(isDetecting ? "Analisando a imagem..." : message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }

            actionButtons
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .task {
            await detectDocument()
        }
    }

    private var editorCanvas: some View {
        GeometryReader { geometry in
            let imageRect = fittedImageRect(
                imageSize: image.size,
                in: CGRect(origin: .zero, size: geometry.size)
            )

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                cropPath(in: imageRect)
                    .fill(Color.green.opacity(0.10))

                cropPath(in: imageRect)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineJoin: .round))

                ForEach(points.indices, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color.green, lineWidth: 4))
                        .frame(width: 30, height: 30)
                        .shadow(color: .black.opacity(0.35), radius: 3)
                        .position(
                            x: imageRect.minX + points[index].x * imageRect.width,
                            y: imageRect.minY + points[index].y * imageRect.height
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if dragOrigins[index] == nil {
                                        dragOrigins[index] = points[index]
                                    }
                                    guard let origin = dragOrigins[index] else { return }

                                    var updated = points
                                    updated[index] = CGPoint(
                                        x: min(max(origin.x + value.translation.width / max(imageRect.width, 1), 0), 1),
                                        y: min(max(origin.y + value.translation.height / max(imageRect.height, 1), 0), 1)
                                    )
                                    points = updated
                                }
                                .onEnded { _ in
                                    dragOrigins[index] = nil
                                }
                        )
                        .accessibilityLabel("Ajustar canto \(index + 1)")
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Capturar novamente", action: onRetake)
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(isProcessing)

            if correctedImage == nil {
                Button {
                    applyCorrection()
                } label: {
                    if isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Aplicar recorte")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DocscanTheme.blue)
                .disabled(isDetecting || isProcessing)
            } else {
                Button("Ajustar cantos") {
                    correctedImage = nil
                    message = "Arraste os quatro pontos verdes para ajustar o documento."
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button("Concluir", action: onComplete)
                    .buttonStyle(.borderedProminent)
                    .tint(DocscanTheme.blue)
            }
        }
        .font(.subheadline.weight(.semibold))
    }

    private func detectDocument() async {
        let source = image
        let detected = await Task.detached(priority: .userInitiated) {
            try? DocumentPerspectiveCorrector().detectCorners(in: source)
        }.value

        if let detected {
            points = detected.points
            message = "Documento detectado. Se necessário, arraste os pontos verdes para ajustar."
        } else {
            message = "Não foi possível detectar automaticamente. Ajuste os quatro cantos manualmente."
        }
        isDetecting = false
    }

    private func applyCorrection() {
        guard points.count == 4 else { return }
        isProcessing = true
        message = "Corrigindo a perspectiva..."

        let source = image
        let selectedCorners = DocumentCropCorners(points: points)

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                try? DocumentPerspectiveCorrector().correct(
                    image: source,
                    corners: selectedCorners
                )
            }.value

            if let result {
                correctedImage = result
                message = "Recorte aplicado."
            } else {
                message = "Não foi possível aplicar o recorte. Confira os cantos e tente novamente."
            }
            isProcessing = false
        }
    }

    private func cropPath(in imageRect: CGRect) -> Path {
        var path = Path()
        guard points.count == 4 else { return path }

        let mapped = points.map {
            CGPoint(
                x: imageRect.minX + $0.x * imageRect.width,
                y: imageRect.minY + $0.y * imageRect.height
            )
        }

        path.move(to: mapped[0])
        path.addLine(to: mapped[1])
        path.addLine(to: mapped[2])
        path.addLine(to: mapped[3])
        path.closeSubpath()
        return path
    }

    private func fittedImageRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
