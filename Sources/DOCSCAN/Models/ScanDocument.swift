import Foundation

struct ScanDocument: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var createdAt: Date = .now
    var pageCount: Int = 0
    var pdfFileName: String?
}
