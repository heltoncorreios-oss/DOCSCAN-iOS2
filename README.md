# DOCSCAN iOS — Starter técnico

Este pacote inicia a versão iOS nativa do DOCSCAN com SwiftUI. Foi preparado a partir da análise do ZIP Android recebido.

## Conteúdo

- `project.yml`: definição do projeto Xcode via XcodeGen.
- `codemagic.yaml`: workflow de compilação inicial sem assinatura para simulador iOS.
- `Sources/DOCSCAN`: estrutura SwiftUI inicial, tema, modelo e contratos de serviços.
- `Docs/MIGRATION-MAP.md`: correspondência entre arquivos e recursos Android e os módulos iOS previstos.

## Importante

Este pacote é um **starter**, não uma versão funcional completa do scanner. A tela de digitalização é provisória. A próxima implementação deverá criar a sessão AVFoundation, detecção Vision em tempo real, zoom, captura, correção de perspectiva e recorte manual.

O `PRODUCT_BUNDLE_IDENTIFIER` em `project.yml` está como `com.example.docscan` apenas para compilação inicial. Deve ser trocado por um identificador exclusivo antes de assinatura ou publicação.

## Compilar na nuvem

1. Criar conta no Codemagic e conectar o repositório Git.
2. Enviar esta pasta para um repositório GitHub.
3. No Codemagic, selecionar o workflow `docscan-ios-unsigned-check`.
4. Executar o build. O workflow instala XcodeGen, gera `DOCSCAN.xcodeproj` e compila para o simulador sem assinatura.

A compilação sem assinatura valida o projeto, mas não instala o aplicativo em um iPhone físico. Para TestFlight/App Store será necessária a assinatura Apple e a associação à conta Apple Developer Program.

## Tecnologias planejadas

Swift 5.9+, SwiftUI, AVFoundation, Vision, Core Image, PDFKit, SwiftData, PencilKit e Keychain.
