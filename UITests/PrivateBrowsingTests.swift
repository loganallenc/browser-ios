/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import WebKit
import Shared
import UIKit

class PrivateBrowsingTests: KIFTestCase {
    private var webRoot: String!

    override func setUp() {
        webRoot = SimplePageServer.start()
    }

    override func tearDown() {
//        do {
//            try tester().tryFindingTappableViewWithAccessibilityLabel("home")
//            tester().tapViewWithAccessibilityLabel("home")
//        } catch _ {
//        }
      //  BrowserUtils.resetToAboutHome(tester())
    }


    private func setCookies(cookie cookie: String) {
        let webView = tester().waitForViewWithAccessibilityLabel("Web content") as! UIWebView
        webView.stringByEvaluatingJavaScriptFromString("document.cookie = \"\(cookie)\"; localStorage.cookie = \"\(cookie)\"; sessionStorage.cookie = \"\(cookie)\";")
    }

    private func getCookies() -> (cookie: String, localStorage: String?, sessionStorage: String?) {
        let webView = tester().waitForViewWithAccessibilityLabel("Web content") as! UIWebView
        var cookie: (String, String?, String?)!
        let result = webView.stringByEvaluatingJavaScriptFromString("JSON.stringify([document.cookie, localStorage.cookie, sessionStorage.cookie])")
        XCTAssert(result != nil)
        let cookies = JSON.parse(result!).asArray!
        cookie = (cookies[0].asString!, cookies[1].asString, cookies[2].asString)
        return cookie
    }

    func testPrivateTabCookie() {
        enterUrl()
        let c = "cookie8675309=tommytutone"

        // local storage cookie is kept in-app memory and can't be cleared until app killed
        func verifyNoCookie(exceptForLocalStorageCookie exceptForLocalStorageCookie: Bool = false) {
            let cookies = getCookies()
            XCTAssertEqual(cookies.cookie, "")
            if exceptForLocalStorageCookie {
                XCTAssert(cookies.localStorage == c)
            } else {
                XCTAssert(cookies.localStorage == nil)
            }
            XCTAssert(cookies.sessionStorage == nil)
        }

        verifyNoCookie()
        
        tester().tapViewWithAccessibilityLabel("Show Tabs")
        tester().tapViewWithAccessibilityLabel("Private Mode")
        tester().tapViewWithAccessibilityLabel("Add Tab")
        enterUrl()

        setCookies(cookie: c)
        let cookies = getCookies()
        XCTAssertEqual(cookies.cookie, c)
        XCTAssertEqual(cookies.localStorage, c)
        XCTAssertEqual(cookies.sessionStorage, c)

        tester().tapViewWithAccessibilityLabel("Show Tabs")
        tester().tapViewWithAccessibilityLabel("Private Mode")
        tester().tapViewWithAccessibilityLabel("Page 1")
        enterUrl()

        verifyNoCookie(exceptForLocalStorageCookie: true)

    }

    private func enterUrl() {
        let url1 = "\(webRoot)/numberedPage.html?page=1"
        tester().tapViewWithAccessibilityIdentifier("url")
        tester().clearTextFromAndThenEnterTextIntoCurrentFirstResponder("\(url1)\n")
        tester().waitForWebViewElementWithAccessibilityLabel("Page 1")
        tester().waitForTimeInterval(0.5)
    }

    func testPrivateTabDoesntTrackHistory() {
        // First navigate to a normal tab and see that it tracks

        func checkHistory() {
            tester().tapViewWithAccessibilityLabel("Bookmarks and History Panel")
            tester().tapViewWithAccessibilityLabel("Show History")
            var tableView = tester().waitForViewWithAccessibilityIdentifier("History List") as! UITableView
            XCTAssertEqual(tableView.numberOfRowsInSection(0), 1)
            tester().tapScreenAtPoint(CGPoint(x:260 + 50, y:10))
            tester().waitForViewWithAccessibilityLabel("Show Tabs")
        }

        enterUrl()
        checkHistory()

        // Then try doing the same thing for a private tab
        tester().tapViewWithAccessibilityLabel("Show Tabs")
        tester().tapViewWithAccessibilityLabel("Private Mode")
        tester().tapViewWithAccessibilityLabel("Add Tab")

        enterUrl()
        checkHistory()

        // Exit private mode
        tester().tapViewWithAccessibilityLabel("Show Tabs")
        tester().tapViewWithAccessibilityLabel("Private Mode")
        tester().tapViewWithAccessibilityLabel("Page 1")

        checkHistory()
    }

    func testTabCountShowsOnlyNormalOrPrivateTabCount() {
        enterUrl()

        // Add two tabs and make sure we see the right tab count
        tester().tapViewWithAccessibilityLabel("Show Tabs")
        tester().tapViewWithAccessibilityLabel("Add Tab")

        enterUrl()

        var tabButton = tester().waitForViewWithAccessibilityLabel("Show Tabs") as! UIControl
        XCTAssertEqual(tabButton.accessibilityValue, "2", "Tab count shows 2 tabs")

        // Add a private tab and make sure we only see the private tab in the count, and not the normal tabs
        tester().tapViewWithAccessibilityLabel("Show Tabs")
        tester().tapViewWithAccessibilityLabel("Private Mode")
        tester().tapViewWithAccessibilityLabel("Add Tab")

        enterUrl()

        tabButton = tester().waitForViewWithAccessibilityLabel("Show Tabs") as! UIControl
        XCTAssertEqual(tabButton.accessibilityValue, "1", "Private tab count should show 1 tab opened")

        // Switch back to normal tabs and make sure the private tab doesnt get added to the count
        tester().tapViewWithAccessibilityLabel("Show Tabs")
        tester().tapViewWithAccessibilityLabel("Private Mode")
        tester().tapViewWithAccessibilityLabel("Page 1")

        enterUrl()

        tabButton = tester().waitForViewWithAccessibilityLabel("Show Tabs") as! UIControl
        XCTAssertEqual(tabButton.accessibilityValue, "2", "Tab count shows 2 tabs")
    }

//    func testNoPrivateTabsShowsAndHidesEmptyView() {
//        // Do we show the empty private tabs panel view?
//        tester().tapViewWithAccessibilityLabel("Show Tabs")
//        tester().tapViewWithAccessibilityLabel("Private Mode")
//        var emptyView = tester().waitForViewWithAccessibilityLabel("Private Browsing")
//        XCTAssertTrue(emptyView.superview!.alpha == 1)
//
//        // Do we hide it when we add a tab?
//        tester().tapViewWithAccessibilityLabel("Add Tab")
//        tester().waitForViewWithAccessibilityLabel("Show Tabs")
//        tester().tapViewWithAccessibilityLabel("Show Tabs")
//
//        emptyView = tester().waitForViewWithAccessibilityLabel("Private Browsing")
//        XCTAssertTrue(emptyView.superview!.alpha == 0)
//
//        // Remove the private tab - do we see the empty view now?
//        let tabsView = tester().waitForViewWithAccessibilityLabel("Tabs Tray").subviews.first as! UICollectionView
//        while tabsView.numberOfItemsInSection(0) > 0 {
//            let cell = tabsView.cellForItemAtIndexPath(NSIndexPath(forItem: 0, inSection: 0))!
//            tester().swipeViewWithAccessibilityLabel(cell.accessibilityLabel, inDirection: KIFSwipeDirection.Left)
//            tester().waitForAbsenceOfViewWithAccessibilityLabel(cell.accessibilityLabel)
//        }
//
//        emptyView = tester().waitForViewWithAccessibilityLabel("Private Browsing")
//        XCTAssertTrue(emptyView.superview!.alpha == 1)
//
//        // Exit private mode
//        tester().tapViewWithAccessibilityLabel("Private Mode")
//    }
//
//    func testClosePrivateTabsClosesPrivateTabs() {
//        // First, make sure that selecting the option to ON will close the tabs
//        tester().tapViewWithAccessibilityLabel("Show Tabs")
//        tester().tapViewWithAccessibilityLabel("Settings")
//        tester().setOn(true, forSwitchWithAccessibilityLabel: "Close Private Tabs, When Leaving Private Browsing")
//        tester().tapViewWithAccessibilityLabel("Done")
//        tester().tapViewWithAccessibilityLabel("Private Mode")
//
//        XCTAssertEqual(numberOfTabs(), 0)
//
//        tester().tapViewWithAccessibilityLabel("Add Tab")
//        tester().waitForViewWithAccessibilityLabel("Show Tabs")
//        tester().tapViewWithAccessibilityLabel("Show Tabs")
//
//        XCTAssertEqual(numberOfTabs(), 1)
//
//        tester().tapViewWithAccessibilityLabel("Private Mode")
//        tester().waitForAnimationsToFinish()
//        tester().tapViewWithAccessibilityLabel("Private Mode")
//
//        XCTAssertEqual(numberOfTabs(), 0)
//
//        tester().tapViewWithAccessibilityLabel("Private Mode")
//
//        // Second, make sure selecting the option to OFF will not close the tabs
//        tester().tapViewWithAccessibilityLabel("Settings")
//        tester().setOn(false, forSwitchWithAccessibilityLabel: "Close Private Tabs, When Leaving Private Browsing")
//        tester().tapViewWithAccessibilityLabel("Done")
//        tester().tapViewWithAccessibilityLabel("Private Mode")
//
//        XCTAssertEqual(numberOfTabs(), 0)
//
//        tester().tapViewWithAccessibilityLabel("Add Tab")
//        tester().waitForViewWithAccessibilityLabel("Show Tabs")
//        tester().tapViewWithAccessibilityLabel("Show Tabs")
//
//        XCTAssertEqual(numberOfTabs(), 1)
//
//        tester().tapViewWithAccessibilityLabel("Private Mode")
//        tester().waitForAnimationsToFinish()
//        tester().tapViewWithAccessibilityLabel("Private Mode")
//
//        XCTAssertEqual(numberOfTabs(), 1)
//
//        tester().tapViewWithAccessibilityLabel("Private Mode")
//    }

    private func numberOfTabs() -> Int {
        let tabsView = tester().waitForViewWithAccessibilityLabel("Tabs Tray").subviews.first as! UICollectionView
        return tabsView.numberOfItemsInSection(0)
    }
}
