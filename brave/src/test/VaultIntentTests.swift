/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import XCTest
@testable import Client
import Shared

class VaultIntentTests: XCTestCase {
  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    super.tearDown()
  }

  func setupExpectation() {
    expectationForNotification(VaultManager.notificationVaultSimpleResponse, object: nil,
      handler: { notification in
        guard let response = notification.userInfo?["response"] else { XCTFail("no response"); return false }
        // Please fill in: response.contains("some expected thing")
        let data = response.dataUsingEncoding(NSUTF8StringEncoding)
        if data == nil || data?.length < 1 {
          // maybe we should specify setupExpectation(isEmptyResponseOk: true/false)
          return true
        }

        do {
          guard let json = try NSJSONSerialization.JSONObjectWithData(data!, options: [])
            as? [String:AnyObject] else { XCTFail("bad response"); return false }
          if json["statusCode"] != nil {
            XCTAssert(json["statusCode"] as? Int == 200, "Response: \(json)")
          }
        } catch let error as NSError {
            XCTFail("\(error)")
        }
        return true
    })
  }

  func waitForExpectation() {
    waitForExpectationsWithTimeout(10, handler: { error in
      XCTAssert(error == nil, "vault response error: \(error)")
    })
  }

  func testLiveUserProfileInit() {
    setupExpectation()
    VaultManager.userProfileInit()
    waitForExpectation()
  }


}