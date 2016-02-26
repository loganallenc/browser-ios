/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import WebKit
import Deferred
import WebImage

private let log = Logger.browserLogger

// Removed Clearables as part of Bug 1226654, but keeping the string around.
private let removedSavedLoginsLabel = NSLocalizedString("Saved Logins", tableName: "ClearPrivateData", comment: "Settings item for clearing passwords and login data")

// A base protocol for something that can be cleared.
protocol Clearable {
    func clear() -> Success
    var label: String { get }
}

class ClearableError: MaybeErrorType {
    private let msg: String
    init(msg: String) {
        self.msg = msg
    }

    var description: String { return msg }
}

// Clears our browsing history, including favicons and thumbnails.
class HistoryClearable: Clearable {
    let profile: Profile
    init(profile: Profile) {
        self.profile = profile
    }

    var label: String {
        return NSLocalizedString("Browsing History", tableName: "ClearPrivateData", comment: "Settings item for clearing browsing history")
    }

    func clear() -> Success {
        return profile.history.clearHistory().bind { success in
            SDImageCache.sharedImageCache().clearDisk()
            SDImageCache.sharedImageCache().clearMemory()
            NSNotificationCenter.defaultCenter().postNotificationName(NotificationPrivateDataClearedHistory, object: nil)
            log.debug("HistoryClearable succeeded: \(success).")
            return Deferred(value: success)
        }
    }
}

struct ClearableErrorType: MaybeErrorType {
    let err: ErrorType

    init(err: ErrorType) {
        self.err = err
    }

    var description: String {
        return "Couldn't clear: \(err)."
    }
}

// Clear the web cache. Note, this has to close all open tabs in order to ensure the data
// cached in them isn't flushed to disk.
class CacheClearable: Clearable {

    var label: String {
        return NSLocalizedString("Cache", tableName: "ClearPrivateData", comment: "Settings item for clearing the cache")
    }

    func clear() -> Success {
        getApp().tabManager.removeAll()

        NSURLCache.sharedURLCache().memoryCapacity = 0;
        NSURLCache.sharedURLCache().diskCapacity = 0;
        // Remove the basic cache.
        NSURLCache.sharedURLCache().removeAllCachedResponses()

        // Now let's finish up by destroying our Cache directory.
        do {
            try deleteLibraryFolderContents("Caches", validateClearedWithNameContains: ["WebKit", "brave"])
        } catch {
            return deferMaybe(ClearableErrorType(err: error))
        }

        do {
            try deleteLibraryFolderContents("WebKit", validateClearedWithNameContains: ["WebsiteData", "GeolocationSites.plist"])
        } catch {
            return deferMaybe(ClearableErrorType(err: error))
        }

        // Leave the cache off in the error cases above
        BraveApp.setupCacheDefaults()

        return succeed()
    }
}

// Delete all the contents of a the folder, and verify using validateClearedWithNameContains that critical files are removed (any remaining file must not contain the specified substring(s))
// Alert the user if these files still exist after clearing.
// validateClearedWithNameContains can be nil, in which case the check is skipped or pass [] as a special case to verify that
// the directory is empty.
private func deleteLibraryFolderContents(folder: String, validateClearedWithNameContains:[String]?) throws {
    let manager = NSFileManager.defaultManager()
    let library = manager.URLsForDirectory(NSSearchPathDirectory.LibraryDirectory, inDomains: .UserDomainMask)[0]
    let dir = library.URLByAppendingPathComponent(folder)
    var contents = try manager.contentsOfDirectoryAtPath(dir.path!)
    for content in contents {
        do {
            try manager.removeItemAtURL(dir.URLByAppendingPathComponent(content))
        } catch where ((error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError)?.code == Int(EPERM) {
            // "Not permitted". We ignore this.
            // Snapshots directory is an example of a Cache dir that is not permitted on device (but is permitted on simulator)
        }
    }

    guard let namesToCheck = validateClearedWithNameContains else { return }
    contents = try manager.contentsOfDirectoryAtPath(dir.path!)
    if namesToCheck.count < 1 && contents.count > 0 {
        BraveApp.showErrorAlert(title: "Error clearing data", error: "\(folder) not fully cleared")
        return
    }

    for content in contents {
        for name in namesToCheck {
            if content.contains(name) {
                BraveApp.showErrorAlert(title: "Error clearing data", error: "Item not cleared: \(content)")
            }
        }
    }
}

private func deleteLibraryFolder(folder: String) throws {
    let manager = NSFileManager.defaultManager()
    let library = manager.URLsForDirectory(NSSearchPathDirectory.LibraryDirectory, inDomains: .UserDomainMask)[0]
    let dir = library.URLByAppendingPathComponent(folder)
    try manager.removeItemAtURL(dir)
}

// Removes all app cache storage.
class SiteDataClearable: Clearable {
    let tabManager: TabManager
    init(tabManager: TabManager) {
        self.tabManager = tabManager
    }

    var label: String {
        return NSLocalizedString("Offline Website Data", tableName: "ClearPrivateData", comment: "Settings item for clearing website data")
    }

    func clear() -> Success {
        if #available(iOS 9.0, *) {
            let dataTypes = Set([WKWebsiteDataTypeOfflineWebApplicationCache])
            WKWebsiteDataStore.defaultDataStore().removeDataOfTypes(dataTypes, modifiedSince: NSDate.distantPast(), completionHandler: {})
        } else {
            // First, close all tabs to make sure they don't hold anything in memory.
            tabManager.removeAll()

            // Then we just wipe the WebKit directory from our Library.
            do {
                try deleteLibraryFolder("WebKit")
            } catch {
                return deferMaybe(ClearableErrorType(err: error))
            }
        }

        log.debug("SiteDataClearable succeeded.")
        return succeed()
    }
}

// Remove all cookies stored by the site. This includes localStorage, sessionStorage, and WebSQL/IndexedDB.
class CookiesClearable: Clearable {

    var label: String {
        return NSLocalizedString("Cookies", tableName: "ClearPrivateData", comment: "Settings item for clearing cookies")
    }

    func clear() -> Success {
        getApp().tabManager.removeAll()

        NSUserDefaults.standardUserDefaults().synchronize()

        // Now we wipe the system cookie store (for our app).
        let storage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        if let cookies = storage.cookies {
            for cookie in cookies {
                storage.deleteCookie(cookie)
            }
        }
        NSUserDefaults.standardUserDefaults().synchronize()

        // And just to be safe, we also wipe the Cookies directory.
        do {
            try deleteLibraryFolderContents("Cookies", validateClearedWithNameContains: [])
        } catch {
            return deferMaybe(ClearableErrorType(err: error))
        }
        return succeed()
    }
}