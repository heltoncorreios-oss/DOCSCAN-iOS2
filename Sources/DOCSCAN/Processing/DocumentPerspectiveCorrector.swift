import CoreImage
import Vision

/// Ponto de entrada para a correção de perspectiva no iOS.
/// Será implementado com CIWarpPerspective após a migração e validação
/// da geometria dos quatro cantos do projeto Android.
struct DocumentPerspectiveCorrector {
    let context = CIContext()
}
