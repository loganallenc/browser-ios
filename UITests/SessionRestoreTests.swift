/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import WebKit
import Shared
import Client

class SessionRestoreTests: KIFTestCase {
    private var webRoot: String!

    override func setUp() {
        webRoot = "http://localhost:6571"
    }

    func testTabRestore() {
        //        let url1 = "\(webRoot)/numberedPage.html?page=1"
        //        let url2 = "\(webRoot)/numberedPage.html?page=2"
        //        let url3 = "\(webRoot)/numberedPage.html?page=3"
        let url1 = "http://www.google.ca"
        let url2 = "http://www.amazon.ca"
        let url3 = "http://www.brave.com"

        // Build a session restore URL from the current homepage URL.
        var jsonDict = [String: AnyObject]()
        jsonDict["history"] = [url1, url2, url3]
        jsonDict["currentPage"] = -1
        let escapedJSON = JSON.stringify(jsonDict, pretty: false).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
        //let webView = tester().waitForViewWithAccessibilityLabel("Web content") as! UIWebView
        let restoreURL = NSURL(string: webRoot + "/about/sessionrestore?history=\(escapedJSON)")

        // Enter the restore URL and verify the back/forward history.
        // After triggering the restore, the session should look like this:
        //   about:home, page1, *page2*, page3
        // where page2 is active.

        tester().tapViewWithAccessibilityIdentifier("url")
        tester().clearTextFromAndThenEnterTextIntoCurrentFirstResponder("\(restoreURL!.absoluteString)\n")
        tester().waitForTimeInterval(1)
        tester().waitForTappableViewWithAccessibilityLabel("Back")
        tester().tapViewWithAccessibilityLabel("Back")
        tester().waitForTimeInterval(1)
        tester().waitForViewWithAccessibilityLabel("Google")
        tester().tapViewWithAccessibilityLabel("Forward")
        tester().waitForTimeInterval(1)
        tester().waitForViewWithAccessibilityLabel("Amazon.ca")

//        let canGoBack: Bool
//        do {
//            try tester().tryFindingTappableViewWithAccessibilityLabel("Back")
//            canGoBack = true
//        } catch _ {
//            canGoBack = false
//        }
//        XCTAssertFalse(canGoBack, "Reached the beginning of browser history")
        tester().tapViewWithAccessibilityLabel("Forward")
        tester().waitForTimeInterval(1)
        tester().hasWebViewTitleWithPrefix("Brave Software")
        let canGoForward: Bool
        do {
            try tester().tryFindingTappableViewWithAccessibilityLabel("Forward")
            canGoForward = true
        } catch _ {
            canGoForward = false
        }
        XCTAssertFalse(canGoForward, "Reached the end of browser history")
    }

    override func tearDown() {
        //BrowserUtils.resetToAboutHome(tester())
    }
}