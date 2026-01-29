import XCTest
@testable import Flux

final class LaunchEnvironmentTests: XCTestCase {
    func testBuildEnvironmentWithoutGPTK() {
        let env = WineEnvironmentBuilder.buildEnvironment(
            base: ["PATH": "/usr/bin"],
            prefixPath: "/tmp/flux/prefix",
            wineExecutable: "/opt/homebrew/bin/wine",
            wineserverPath: "/opt/homebrew/bin/wineserver",
            useGPTK: false,
            gptkPath: "/opt/gptk",
            executionEnvironment: .x86,
            steamAppId: 0
        )

        XCTAssertEqual(env["WINEPREFIX"], "/tmp/flux/prefix")
        XCTAssertEqual(env["WINEARCH"], "win32")
        XCTAssertEqual(env["WINE"], "/opt/homebrew/bin/wine")
        XCTAssertEqual(env["WINESERVER"], "/opt/homebrew/bin/wineserver")
        XCTAssertNil(env["WINE64"])
        XCTAssertNil(env["DYLD_LIBRARY_PATH"])
        XCTAssertNil(env["METAL_DEVICE_CAPTURE_ENABLED"])
    }

    func testBuildEnvironmentWithGPTK() {
        let env = WineEnvironmentBuilder.buildEnvironment(
            base: ["PATH": "/usr/bin"],
            prefixPath: "/tmp/flux/prefix",
            wineExecutable: "/opt/homebrew/bin/wine",
            wineserverPath: nil,
            useGPTK: true,
            gptkPath: "/opt/gptk",
            executionEnvironment: .native,
            steamAppId: 123
        )

        XCTAssertEqual(env["WINEPREFIX"], "/tmp/flux/prefix")
        XCTAssertEqual(env["WINE"], "/opt/homebrew/bin/wine")
        XCTAssertEqual(env["DYLD_LIBRARY_PATH"], "/opt/gptk/lib")
        XCTAssertEqual(env["METAL_DEVICE_CAPTURE_ENABLED"], "1")
        XCTAssertEqual(env["SteamAppId"], "123")
        XCTAssertEqual(env["SteamGameId"], "123")
    }

    func testBuildCommand() {
        let cmd = WineEnvironmentBuilder.buildCommand(
            wineExecutable: "/opt/homebrew/bin/wine",
            executablePath: "/Games/Test/game.exe"
        )

        XCTAssertEqual(cmd.first, "/opt/homebrew/bin/wine")
        XCTAssertEqual(cmd.last, "/Games/Test/game.exe")
        XCTAssertEqual(cmd.count, 2)
    }
}
