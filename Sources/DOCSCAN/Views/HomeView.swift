import SwiftUI

struct HomeView: View {
    @State private var showingScanner = false

    var body: some View {
        NavigationStack {
            ZStack {
                DocscanTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DOCSCAN")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(DocscanTheme.navy)
                        Text("Digitalize seus documentos com facilidade")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button { showingScanner = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 30, weight: .medium))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Digitalizar documento").font(.headline)
                                Text("Capturar, recortar e gerar PDF").font(.caption)
                                    .opacity(0.85)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(.white)
                        .padding(20)
                        .background(DocscanTheme.navy, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)

                    Text("Ferramentas")
                        .font(.title3.bold())
                        .foregroundStyle(DocscanTheme.navy)
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        toolTile("Arquivos PDF", icon: "doc.richtext")
                        toolTile("Extrair texto", icon: "text.viewfinder")
                        toolTile("Assinatura", icon: "signature")
                        toolTile("Documentos", icon: "folder")
                    }
                    Spacer()
                }
                .padding(20)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingScanner) {
                ScannerPlaceholderView()
            }
        }
    }

    private func toolTile(_ title: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(DocscanTheme.blue)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(DocscanTheme.navy)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}
