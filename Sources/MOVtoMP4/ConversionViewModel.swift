import AppKit
import Combine
import Foundation

@MainActor
final class ConversionViewModel: ObservableObject {
    @Published private(set) var items: [ConversionItem] = []
    @Published var outputDirectory: URL?
    @Published private(set) var isConverting = false
    @Published private(set) var isCancelling = false

    private let converter = VideoConverter()
    private var cancellationRequested = false

    var canStart: Bool {
        outputDirectory != nil
            && !isConverting
            && items.contains { item in
                if case .queued = item.status { return true }
                if case .failed = item.status { return true }
                if case .cancelled = item.status { return true }
                return false
            }
    }

    var overallProgress: Double {
        guard !items.isEmpty else { return 0 }
        let total = items.reduce(0.0) { partial, item in
            switch item.status {
            case .completed:
                partial + 1
            case .converting:
                partial + item.progress
            case .queued, .failed, .cancelled:
                partial
            }
        }
        return total / Double(items.count)
    }

    var completedCount: Int {
        items.count { $0.status == .completed }
    }

    func addFiles(_ urls: [URL]) {
        let existingPaths = Set(items.map { $0.sourceURL.standardizedFileURL.path })
        let additions = urls
            .filter { $0.pathExtension.caseInsensitiveCompare("mov") == .orderedSame }
            .filter { !existingPaths.contains($0.standardizedFileURL.path) }
            .map(ConversionItem.init(sourceURL:))
        items.append(contentsOf: additions)
    }

    func remove(_ item: ConversionItem) {
        guard !isConverting else { return }
        items.removeAll { $0.id == item.id }
    }

    func clearFinished() {
        guard !isConverting else { return }
        items.removeAll { $0.status.isFinished }
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "MP4 の保存先を選択"
        panel.prompt = "選択"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK {
            outputDirectory = panel.url
        }
    }

    func startConversion() async {
        guard let outputDirectory, canStart else { return }

        isConverting = true
        isCancelling = false
        cancellationRequested = false
        defer {
            isConverting = false
            isCancelling = false
        }

        let destinationAccess = outputDirectory.startAccessingSecurityScopedResource()
        defer {
            if destinationAccess { outputDirectory.stopAccessingSecurityScopedResource() }
        }

        var reservedURLs = Set(items.compactMap(\.outputURL))
        let pendingIDs = items.compactMap { item -> UUID? in
            switch item.status {
            case .queued, .failed, .cancelled: item.id
            case .converting, .completed: nil
            }
        }

        for id in pendingIDs {
            if cancellationRequested { break }
            guard let index = items.firstIndex(where: { $0.id == id }) else { continue }

            let outputURL = OutputURLBuilder.makeURL(
                for: items[index].sourceURL,
                in: outputDirectory,
                reserving: reservedURLs
            )
            reservedURLs.insert(outputURL)
            items[index].outputURL = outputURL
            items[index].progress = 0
            items[index].status = .converting

            do {
                try await converter.convert(
                    sourceURL: items[index].sourceURL,
                    outputURL: outputURL
                ) { [weak self] progress in
                    guard let self,
                          let currentIndex = self.items.firstIndex(where: { $0.id == id })
                    else { return }
                    self.items[currentIndex].progress = progress
                }

                if let currentIndex = items.firstIndex(where: { $0.id == id }) {
                    items[currentIndex].progress = 1
                    items[currentIndex].status = .completed
                }
            } catch is CancellationError {
                markCancelled(id)
            } catch VideoConversionError.exportCancelled {
                markCancelled(id)
            } catch {
                if let currentIndex = items.firstIndex(where: { $0.id == id }) {
                    items[currentIndex].status = .failed(error.localizedDescription)
                }
            }
        }

        if cancellationRequested {
            for index in items.indices where items[index].status == .queued {
                items[index].status = .cancelled
            }
        }
    }

    func cancelConversion() {
        guard isConverting else { return }
        cancellationRequested = true
        isCancelling = true
        converter.cancel()
    }

    func revealOutput(for item: ConversionItem) {
        guard let outputURL = item.outputURL,
              FileManager.default.fileExists(atPath: outputURL.path)
        else { return }
        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
    }

    private func markCancelled(_ id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = .cancelled
        }
    }
}
