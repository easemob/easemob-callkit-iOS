import AVFoundation
import EaseCallUIKit
import UIKit
import XCTest

final class ResourceBundleTests: XCTestCase {
    private var originalBundle: Bundle?
    private var originalLanguage: LanguageType = .Chinese

    override func setUp() {
        super.setUp()
        originalBundle = CallAppearance.resourceBundle
        originalLanguage = CallAppearance.call_language
        CallAppearance.resourceBundle = nil
    }

    override func tearDown() {
        CallAppearance.resourceBundle = originalBundle
        CallAppearance.call_language = originalLanguage
        super.tearDown()
    }

    func testDefaultBundleContainsCallResources() {
        XCTAssertEqual(Bundle.callBundle.bundleURL.lastPathComponent, "CallResource.bundle")
    }

    func testImagesCanBeLoadedFromBundle() throws {
        let bundle = Bundle.callBundle
        for name in ["default_avatar", "bg", "phone_pick", "phone_hang", "mic_on", "camera_off"] {
            XCTAssertNotNil(UIImage(named: name, in: bundle, compatibleWith: nil), name)
        }

        for scale in ["2x", "3x"] {
            let url = try XCTUnwrap(bundle.url(forResource: "default_avatar@\(scale)", withExtension: "png"))
            XCTAssertNotNil(UIImage(contentsOfFile: url.path))
        }
    }

    func testRingtonesCanBeDecoded() throws {
        for name in ["dialing", "ringing", "busy"] {
            let url = try XCTUnwrap(Bundle.callBundle.url(forResource: name, withExtension: "mp3"), name)
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(player.duration, 0, name)
        }
    }

    func testEnglishLocalization() {
        CallAppearance.call_language = .English
        XCTAssertEqual(LanguageConvertor.localValue(key: "singleAudio"), "Private audio call")
    }

    func testChineseLocalization() {
        CallAppearance.call_language = .Chinese
        XCTAssertEqual(LanguageConvertor.localValue(key: "Accept"), "接听")
    }

    func testCustomBundleTakesPriorityAndCanBeReset() {
        let defaultBundle = Bundle.callBundle
        let customBundle = Bundle(for: ResourceBundleTests.self)
        CallAppearance.resourceBundle = customBundle
        XCTAssertTrue(Bundle.callBundle === customBundle)

        CallAppearance.resourceBundle = nil
        XCTAssertEqual(Bundle.callBundle.bundleURL, defaultBundle.bundleURL)
    }
}
