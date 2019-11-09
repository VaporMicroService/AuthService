import XCTest
@testable import App

XCTMain([
    testCase(AppTests.allTests),
    testCase(ExternalAuthControllerTests.allTests),
    testCase(UserControllerTests.allTests),
])
