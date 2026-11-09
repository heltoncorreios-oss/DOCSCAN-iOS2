# Mapa de migração Android -> iOS

Mapeamento identificado no ZIP Android recebido:

| Android (arquivo) | iOS (destino) | Estratégia |
|---|---|---|
| camera/CameraCaptureManager.kt | Services/DocumentScannerService.swift + CameraSession | AVFoundation; sessão, foco, flash e zoom |
| imageprocessing/EdgeDetector.kt | Services/DocumentDetectionService.swift | Vision (retângulos) + refinamento próprio |
| imageprocessing/DocumentCorners.kt | Models/DocumentCorners.swift | Coordenadas normalizadas e conversões de orientação |
| imageprocessing/PerspectiveCorrector.kt | Processing/DocumentPerspectiveCorrector.swift | Core Image CIWarpPerspective; validar orientação e coordenadas |
| imageprocessing/CropCornerOverlay.kt | Views/CropAdjustmentView.swift | SwiftUI Canvas/gestos para quatro alças |
| imageprocessing/DocumentFilters.kt | Processing/DocumentFilters.swift | Core Image |
| data/database/* | Storage/DocumentStore.swift | SwiftData; migração de metadados planejada |
| data/repository/DocumentRepository.kt | Storage/DocumentRepository.swift | Arquivos no sandbox + SwiftData |
| pdf/PdfExporter.kt | PDF/PDFGenerator.swift | PDFKit |
| pdf/PdfMergeCompressHelper.kt | PDF/PDFTools.swift | PDFKit + recompressão de imagens |
| ocr/OcrTextRecognizer.kt | OCR/TextRecognizer.swift | Vision VNRecognizeTextRequest; idioma pt-BR |
| backup/BackupHelper.kt | Backup/BackupService.swift | Definir destino e política de privacidade antes de implementar |
| security/SecurityPreferences.kt | Security/SecureSettings.swift | Keychain para segredos; UserDefaults para preferências não sensíveis |
| ui/screens/SignatureScreen.kt | Views/SignatureView.swift | PencilKit/SwiftUI |
| ui/screens/BarcodeScannerScreen.kt | Services/BarcodeScannerService.swift | Vision barcode detection |
| ui/screens/IdCardScanScreen.kt | Features/IDCardCapture | Fluxo frente/verso e composição de páginas |

## Recursos identificados no Android

- Captura de câmera, foco, flash e zoom.
- Detecção de bordas e quatro cantos.
- Ajuste manual, correção de perspectiva e filtros.
- Documentos multipágina, histórico, pesquisa, renomeação e exclusão.
- PDF, visualização, mesclagem, compressão e compartilhamento.
- OCR em português e pesquisa por texto.
- Assinatura, captura de identidade, código de barras e backup.

## Observações de migração

- Não copiar código Kotlin literalmente; portar comportamento e regras.
- Não migrar o SQLite/Room diretamente para SwiftData sem definir exportação/importação e testes de integridade.
- O bundle identifier `com.example.docscan` é provisório e deve ser substituído por um identificador exclusivo controlado pelo proprietário antes da assinatura/publicação.
- O projeto inicial é um esqueleto de arquitetura e interface; não é ainda um scanner completo nem um IPA instalável.
