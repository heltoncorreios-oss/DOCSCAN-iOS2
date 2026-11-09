import SwiftUI
import AVFoundation

/// Scanner personalizado do DOCSCAN com câmera AVFoundation e detecção Vision.
struct ScannerPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = DocumentScannerService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = scanner.capturedImage {
                    capturedPreview(image)
                } else if scanner.isAuthorized {
                    liveCamera
                } else {
                    permissionState
                }
            }
            .navigationTitle("Digitalizar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fechar") { dismiss() }.foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task { await scanner.start() }
            .onDisappear { scanner.stop() }
            .alert("Atenção", isPresented: Binding(
                get: { scanner.errorMessage != nil },
                set: { if !$0 { scanner.clearError() } }
            )) {
                Button("OK") { scanner.clearError() }
            } message: {
                Text(scanner.errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var liveCamera: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(session: scanner.session)
                    .ignoresSafeArea()

                if let rectangle = scanner.detectedRectangle {
                    RectangleGuide(rectangle: rectangle)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .padding(.horizontal, 0)
                        .padding(.vertical, 0)
                        .allowsHitTesting(false)
                }

                VStack {
                    HStack {
                        Label(scanner.detectedRectangle == nil ? "Procure uma folha" : "Documento detectado",
                              systemImage: scanner.detectedRectangle == nil ? "viewfinder" : "checkmark.viewfinder")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(.black.opacity(0.62), in: Capsule())
                        Spacer()
                    }
                    .padding(.top, 18)
                    .padding(.horizontal, 18)
                    Spacer()
                    VStack(spacing: 18) {
                        HStack(spacing: 18) {
                            Image(systemName: "minus.magnifyingglass")
                            Slider(value: Binding(
                                get: { Double(scanner.zoomFactor) },
                                set: { scanner.setZoom(CGFloat($0)) }
                            ), in: 1...4)
                            Image(systemName: "plus.magnifyingglass")
                            Text(String(format: "%.1fx", scanner.zoomFactor))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .frame(width: 42, alignment: .trailing)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)

                        Button { scanner.capture() } label: {
                            ZStack {
                                Circle().stroke(.white, lineWidth: 5).frame(width: 76, height: 76)
                                Circle().fill(.white).frame(width: 62, height: 62)
                            }
                        }
                        .accessibilityLabel("Capturar documento")
                        Text("Posicione o documento dentro da câmera")
                            .font(.caption).foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                }
            }
        }
    }

    private var permissionState: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill").font(.system(size: 48)).foregroundStyle(.white)
            Text("A câmera é necessária").font(.title2.bold()).foregroundStyle(.white)
            Text("Autorize o acesso à câmera para digitalizar seus documentos.")
                .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.75))
            Button("Tentar novamente") { Task { await scanner.start() } }
                .buttonStyle(.borderedProminent)
                .tint(DocscanTheme.blue)
            Button("Fechar") { dismiss() }.foregroundStyle(.white.opacity(0.8))
        }
        .padding(30)
    }

    private func capturedPreview(_ image: UIImage) -> some View {
        VStack(spacing: 18) {
            Image(uiImage: image)
                .resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
            Text("Imagem capturada. A próxima etapa adicionará o ajuste dos cantos e a correção de perspectiva.")
                .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal)
            HStack(spacing: 14) {
                Button("Capturar novamente") { scanner.retake() }
                    .buttonStyle(.bordered)
                Button("Concluir") { dismiss() }
                    .buttonStyle(.borderedProminent).tint(DocscanTheme.blue)
            }
            .padding(.bottom, 24)
        }
        .padding(.top, 12)
    }
}

/// Desenha o quadrilátero detectado. Coordenadas Vision têm origem no canto inferior esquerdo.
private struct RectangleGuide: Shape {
    let rectangle: DocumentRectangle

    func path(in rect: CGRect) -> Path {
        func point(_ normalized: CGPoint) -> CGPoint {
            CGPoint(x: normalized.x * rect.width, y: (1 - normalized.y) * rect.height)
        }
        var path = Path()
        path.move(to: point(rectangle.topLeft))
        path.addLine(to: point(rectangle.topRight))
        path.addLine(to: point(rectangle.bottomRight))
        path.addLine(to: point(rectangle.bottomLeft))
        path.closeSubpath()
        return path
    }
}
