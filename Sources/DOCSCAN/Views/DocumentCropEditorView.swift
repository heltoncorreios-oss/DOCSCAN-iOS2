
import SwiftUI
import UIKit

/// Tela de ajuste dos cantos e correção de perspectiva do DOCSCAN.
struct DocumentCropEditorView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onComplete: () -> Void

    @State private var corners = DocumentCropCorners(
        topLeft: CGPoint(x: 0.08, y: 0.08),
        topRight: CGPoint(x: 0.92, y: 0.08),
        bottomRight: CGPoint(x: 0.92, y: 0.92),
        bottomLeft: CGPoint(x: 0.08, y: 0.92)
    )

    @State private var correctedImage: UIImage?
    @State private var isProcessing = false
    @State private var isDetecting = true
    @State private var errorMessage: String?

    private let corrector = DocumentPerspectiveCorrector()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(correctedImage == nil ? "Ajustar documento" : "Documento corrigido")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if correctedImage == nil {
                    Text("Arraste os cantos")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding()

            GeometryReader { geometry in
                let displayedRect = fittedImageRect(
                    container: geometry.size,
                    imageSize: image.size
                )

                ZStack(alignment: .topLeading) {
                    Color.black

                    Image(uiImage: correctedImage ?? image)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )

                    if correctedImage == nil {
                        cropOverlay(in: displayedRect)
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .coordinateSpace(name: "cropArea")
            }

            if isDetecting {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Detectando documento...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 12)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 10)
            }

            HStack(spacing: 12) {
                Button {
                    onRetake()
                } label: {
                    Label("Refazer", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button {
                    if correctedImage != nil {
                        onComplete()
                    } else {
                        applyCorrection()
                    }
                } label: {
                    Label(
                        correctedImage == nil ? "Recortar" : "Confirmar",
                        systemImage: correctedImage == nil
                            ? "crop.rotate"
                            : "checkmark"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(DocscanTheme.blue)
                .disabled(isProcessing || isDetecting)
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            detectDocument()
        }
    }

    // MARK: - Área de recorte

    private func cropOverlay(in rect: CGRect) -> some View {
        ZStack {
            Canvas { context, _ in
                let points = corners.points.map {
                    CGPoint(
                        x: rect.minX + $0.x * rect.width,
                        y: rect.minY + $0.y * rect.height
                    )
                }

                var path = Path()
                path.move(to: points[0])

                for point in points.dropFirst() {
                    path.addLine(to: point)
                }

                path.closeSubpath()

                context.fill(
                    path,
                    with: .color(.blue.opacity(0.16))
                )

                context.stroke(
                    path,
                    with: .color(.white),
                    lineWidth: 2
                )
            }

            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(DocscanTheme.blue)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Circle()
                            .stroke(.white, lineWidth: 3)
                    }
                    .position(
                        x: rect.minX + corners.points[index].x * rect.width,
                        y: rect.minY + corners.points[index].y * rect.height
                    )
                    .gesture(
                        DragGesture(coordinateSpace: .named("cropArea"))
                            .onChanged { value in
                                updateCorner(
                                    index,
                                    location: value.location,
                                    imageRect: rect
                                )
                            }
                    )
            }
        }
    }

    private func updateCorner(
        _ index: Int,
        location: CGPoint,
        imageRect: CGRect
    ) {
        guard imageRect.width > 0, imageRect.height > 0 else {
            return
        }

        let point = CGPoint(
            x: min(max((location.x - imageRect.minX) / imageRect.width, 0), 1),
            y: min(max((location.y - imageRect.minY) / imageRect.height, 0), 1)
        )

        switch index {
        case 0:
            corners.topLeft = point
        case 1:
            corners.topRight = point
        case 2:
            corners.bottomRight = point
        case 3:
            corners.bottomLeft = point
        default:
            break
        }
    }

    // MARK: - Detecção automática

    private func detectDocument() {
        isDetecting = true

        do {
            if let detected = try corrector.detectCorners(in: image) {
                corners = detected
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isDetecting = false
    }

    // MARK: - Correção de perspectiva

    private func applyCorrection() {
        isProcessing = true
        errorMessage = nil

        do {
            correctedImage = try corrector.correct(
                image: image,
                corners: corners
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    // MARK: - Proporção da imagem

    private func fittedImageRect(
        container: CGSize,
        imageSize: CGSize
    ) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }

        let scale = min(
            container.width / imageSize.width,
            container.height / imageSize.height
        )

        let width = imageSize.width * scale
        let height = imageSize.height * scale

        return CGRect(
            x: (container.width - width) / 2,
            y: (container.height - height) / 2,
            width: width,
            height: height
        )
    }
}
