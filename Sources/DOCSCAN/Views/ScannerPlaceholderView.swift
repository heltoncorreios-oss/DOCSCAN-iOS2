import SwiftUI

/// Tela provisória da primeira compilação. A próxima etapa implementará AVFoundation,
/// detecção Vision em tempo real, zoom e captura personalizada.
struct ScannerPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Scanner em preparação",
                systemImage: "viewfinder",
                description: Text("A câmera personalizada, a detecção automática das bordas e a correção de perspectiva serão implementadas na próxima etapa.")
            )
            .navigationTitle("Digitalizar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}
