
import SwiftUI
import AVFoundation
import PhotosUI

/// Scanner personalizado do DOCSCAN com suporte a câmera e simulador.
struct ScannerPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = DocumentScannerService()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = scanner.capturedImage {
                    capturedPreview(image)

                } else if scanner.isSimulator {
                    simulatorState

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
                    Button("Fechar") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await scanner.start()
            }
            .task(id: selectedPhoto) {
                await importSelectedPhoto()
            }
            .onDisappear {
                scanner.stop()
            }
            .alert("Atenção", isPresented: Binding(
                get: { scanner.errorMessage != nil },
                set: { if !$0 { scanner.clearError() } }
            )) {
                Button("OK") {
                    scanner.clearError()
                }
            } message: {
                Text(scanner.errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Tela do simulador

    private var simulatorState: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 65))
                .foregroundStyle(DocscanTheme.blue)

            Text("Teste do DOCSCAN")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("A câmera física não está disponível no simulador. Escolha uma foto de documento para testar a digitalização.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 20)

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Importar imagem", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(DocscanTheme.blue, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLoadingPhoto)

            if isLoadingPhoto {
                ProgressView("Carregando imagem...")
                    .tint(.white)
                    .foregroundStyle(.white)
            }

            Text("Selecione uma foto para testar o recorte e a correção de perspectiva.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 25)
        }
        .padding(30)
    }

    // MARK: - Importação da imagem

    @MainActor
    private func importSelectedPhoto() async {
        guard let selectedPhoto else { return }

        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                scanner.clearError()
                return
            }

            scanner.useImage(image)

        } catch {
            scanner.clearError()
        }
    }

    // MARK: - Câmera real

    private var liveCamera: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(
                    session: scanner.session,
                    rectangle: scanner.detectedRectangle
                )
                .ignoresSafeArea()

                VStack {
                    HStack {
                        Label(
                            scanner.detectedRectangle == nil
                                ? "Procure uma folha"
                                : "Documento detectado",
                            systemImage: scanner.detectedRectangle == nil
                                ? "viewfinder"
                                : "checkmark.viewfinder"
                        )
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.62), in: Capsule())

                        Spacer()
                    }
                    .padding(.top, 18)
                    .padding(.horizontal, 18)

                    Spacer()

                    VStack(spacing: 18) {
                        HStack(spacing: 18) {
                            Image(systemName: "minus.magnifyingglass")

                            Slider(
                                value: Binding(
                                    get: { Double(scanner.zoomFactor) },
                                    set: { scanner.setZoom(CGFloat($0)) }
                                ),
                                in: 1...4
                            )

                            Image(systemName: "plus.magnifyingglass")

                            Text(String(format: "%.1fx", scanner.zoomFactor))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .frame(width: 42, alignment: .trailing)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)

                        Button {
                            scanner.capture()
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(.white, lineWidth: 5)
                                    .frame(width: 76, height: 76)

                                Circle()
                                    .fill(.white)
                                    .frame(width: 62, height: 62)
                            }
                        }
                        .accessibilityLabel("Capturar documento")

                        Text("Posicione o documento dentro da câmera")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
    }

    // MARK: - Permissão da câmera

    private var permissionState: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)

            Text("A câmera é necessária")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Autorize o acesso à câmera para digitalizar seus documentos.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))

            Button("Tentar novamente") {
                Task {
                    await scanner.start()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(DocscanTheme.blue)

            Button("Fechar") {
                dismiss()
            }
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(30)
    }

    // MARK: - Editor de recorte

    private func capturedPreview(_ image: UIImage) -> some View {
        DocumentCropEditorView(
            image: image,
            onRetake: {
                scanner.retake()
            },
            onComplete: {
                dismiss()
            }
        )
    }
}
