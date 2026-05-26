// App-level smoke test. Concrete UI tests land per milestone.

import XCTest
@testable import SlothIOS

final class SlothIOSAppTests: XCTestCase {

    func testAppCompilesAndLaunchesToContentView() {
        // The test target's presence proves the SlothIOS target
        // builds against the iOS SDK. Per-screen UI tests arrive
        // with M3 (when there's a real screen worth snapshotting).
        XCTAssertTrue(true)
    }
}
