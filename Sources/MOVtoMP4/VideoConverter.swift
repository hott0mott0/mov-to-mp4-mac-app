@preconcurrency import AVFoundation
import Foundation

enum VideoConversionError: LocalizedError {
    case cannotCreateExportSession
    case mp4NotSupported
    case exportFailed(String)
    case exportCancelled

    var errorDescription: String? {
        switch self {
        case .cannotCreateExportSession:
            "この動画を変換するための書き出しセッションを作成できませんでした。"
        case .mp4NotSupported:
            "この動画のコーデックは MP4 への書き出しに対応していません。"
        case .exportFailed(let message):
            "変換に失敗しました: \(message)"
        case .exportCancelled:
            "変換がキャンセルされました。"
        }
    }
}

@MainActor
final class VideoConverter {
    private final class ExportSessionBox: @unchecked Sendable {
        let session: AVAssetExportSession

        init(_ session: AVAssetExportSession) {
            self.session = session
        }
    }

    private(set) var activeSession: AVAssetExportSession?

    func convert(
        sourceURL: URL,
        outputURL: URL,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let sourceAccess = sourceURL.startAccessingSecurityScopedResource()
        let destinationAccess = outputURL.deletingLastPathComponent().startAccessingSecurityScopedResource()
        defer {
            if sourceAccess { sourceURL.stopAccessingSecurityScopedResource() }
            if destinationAccess { outputURL.deletingLastPathComponent().stopAccessingSecurityScopedResource() }
        }

        let asset = AVURLAsset(url: sourceURL)
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoConversionError.cannotCreateExportSession
        }
        guard session.supportedFileTypes.contains(.mp4) else {
            throw VideoConversionError.mp4NotSupported
        }

        activeSession = session
        defer { activeSession = nil }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        let progressTask = Task { @MainActor in
            while !Task.isCancelled {
                onProgress(Double(session.progress))
                try? await Task.sleep(for: .milliseconds(150))
            }
        }

        do {
            try await export(session)
            progressTask.cancel()
            onProgress(1)
        } catch {
            progressTask.cancel()
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            throw error
        }
    }

    func cancel() {
        activeSession?.cancelExport()
    }

    private func export(_ session: AVAssetExportSession) async throws {
        let box = ExportSessionBox(session)
        try await withCheckedThrowingContinuation { continuation in
            session.exportAsynchronously {
                switch box.session.status {
                case .completed:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: VideoConversionError.exportCancelled)
                case .failed:
                    continuation.resume(
                        throwing: VideoConversionError.exportFailed(
                            box.session.error?.localizedDescription ?? "不明なエラー"
                        )
                    )
                default:
                    continuation.resume(
                        throwing: VideoConversionError.exportFailed(
                            box.session.error?.localizedDescription ?? "書き出しが完了しませんでした"
                        )
                    )
                }
            }
        }
    }
}
