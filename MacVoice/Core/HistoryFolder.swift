import Foundation

struct HistoryFolder: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var colorName: String?
    let createdDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorName: String? = nil,
        createdDate: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.createdDate = createdDate
    }
}
