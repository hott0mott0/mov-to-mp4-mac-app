import Foundation

struct ConversionItem: Identifiable, Equatable {
    enum Status: Equatable {
        case queued
        case converting
        case completed
        case failed(String)
        case cancelled

        var title: String {
            switch self {
            case .queued: "待機中"
            case .converting: "変換中"
            case .completed: "完了"
            case .failed: "失敗"
            case .cancelled: "キャンセル"
            }
        }

        var isFinished: Bool {
            switch self {
            case .completed, .failed, .cancelled: true
            case .queued, .converting: false
            }
        }
    }

    let id: UUID
    let sourceURL: URL
    var outputURL: URL?
    var progress: Double
    var status: Status

    init(sourceURL: URL) {
        id = UUID()
        self.sourceURL = sourceURL
        outputURL = nil
        progress = 0
        status = .queued
    }

    var fileName: String {
        sourceURL.lastPathComponent
    }
}

enum OutputURLBuilder {
    static func makeURL(
        for sourceURL: URL,
        in directory: URL,
        reserving reservedURLs: Set<URL> = [],
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var suffix = 0

        while true {
            let candidateName = suffix == 0 ? "\(baseName).mp4" : "\(baseName) (\(suffix)).mp4"
            let candidate = directory.appendingPathComponent(candidateName)
            if !fileExists(candidate.path) && !reservedURLs.contains(candidate) {
                return candidate
            }
            suffix += 1
        }
    }
}
