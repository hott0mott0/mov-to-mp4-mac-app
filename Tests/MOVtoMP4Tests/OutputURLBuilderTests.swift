import Foundation
import Testing
@testable import MOVtoMP4

struct OutputURLBuilderTests {
    @Test
    func usesMP4Extension() {
        let source = URL(fileURLWithPath: "/input/holiday.MOV")
        let directory = URL(fileURLWithPath: "/output")

        let result = OutputURLBuilder.makeURL(
            for: source,
            in: directory,
            fileExists: { _ in false }
        )

        #expect(result.path == "/output/holiday.mp4")
    }

    @Test
    func addsSuffixWhenDestinationExists() {
        let source = URL(fileURLWithPath: "/input/clip.mov")
        let directory = URL(fileURLWithPath: "/output")

        let result = OutputURLBuilder.makeURL(
            for: source,
            in: directory,
            fileExists: { $0 == "/output/clip.mp4" }
        )

        #expect(result.path == "/output/clip (1).mp4")
    }

    @Test
    func avoidsReservedBatchNames() {
        let source = URL(fileURLWithPath: "/different/clip.mov")
        let directory = URL(fileURLWithPath: "/output")
        let reserved = Set([URL(fileURLWithPath: "/output/clip.mp4")])

        let result = OutputURLBuilder.makeURL(
            for: source,
            in: directory,
            reserving: reserved,
            fileExists: { _ in false }
        )

        #expect(result.path == "/output/clip (1).mp4")
    }
}
