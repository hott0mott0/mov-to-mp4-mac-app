import AVFoundation
import CoreVideo
import Foundation
import Testing
@testable import MOVtoMP4

struct VideoConverterIntegrationTests {
    private enum FixtureError: Error {
        case cannotAddInput
        case cannotCreatePixelBuffer(CVReturn)
        case cannotAppendFrame
        case writerFailed(String)
    }

    @Test @MainActor
    func convertsGeneratedMOVToMP4() async throws {
        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mov-to-mp4-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDirectory) }

        let sourceURL = testDirectory.appendingPathComponent("fixture.mov")
        let outputURL = testDirectory.appendingPathComponent("fixture.mp4")
        try await makeFixture(at: sourceURL)

        let converter = VideoConverter()
        try await converter.convert(sourceURL: sourceURL, outputURL: outputURL) { _ in }

        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        let outputAsset = AVURLAsset(url: outputURL)
        let duration = try await outputAsset.load(.duration)
        #expect(duration.seconds > 0)
    }

    @MainActor
    private func makeFixture(at url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 160,
                AVVideoHeightKey: 90
            ]
        )
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 160,
                kCVPixelBufferHeightKey as String: 90
            ]
        )

        guard writer.canAdd(input) else { throw FixtureError.cannotAddInput }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var pixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            160,
            90,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
            &pixelBuffer
        )
        guard result == kCVReturnSuccess, let pixelBuffer else {
            throw FixtureError.cannotCreatePixelBuffer(result)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(baseAddress, 0x20, CVPixelBufferGetDataSize(pixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        guard adaptor.append(pixelBuffer, withPresentationTime: .zero),
              adaptor.append(pixelBuffer, withPresentationTime: CMTime(seconds: 1, preferredTimescale: 600))
        else {
            throw FixtureError.cannotAppendFrame
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw FixtureError.writerFailed(writer.error?.localizedDescription ?? "不明なエラー")
        }
    }
}
