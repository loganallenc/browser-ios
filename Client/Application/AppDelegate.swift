/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Shared
import Storage
import AVFoundation
import XCGLogger
#if !BRAVE
import Breakpad
#endif
import MessageUI
import WebImage


private let log = Logger.browserLogger

let LatestAppVersionProfileKey = "latestAppVersion"

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var browserViewController: BrowserViewController!
    var rootViewController: UINavigationController!
    weak var profile: BrowserProfile?
    var tabManager: TabManager!
    var adjustIntegration: AdjustIntegration?

    weak var application: UIApplication?
    var launchOptions: [NSObject: AnyObject]?

    let appVersion = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String

    var openInBraveURL: NSURL? = nil

    func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
#if BRAVE
        BraveApp.willFinishLaunching_begin()
#endif
        // Hold references to willFinishLaunching parameters for delayed app launch
        self.application = application
        self.launchOptions = launchOptions

        log.debug("Configuring window…")

        self.window = BraveMainWindow(frame: UIScreen.mainScreen().bounds)
        self.window!.backgroundColor = UIConstants.AppBackgroundColor

        // Short circuit the app if we want to email logs from the debug menu
        if DebugSettingsBundleOptions.launchIntoEmailComposer {
            self.window?.rootViewController = UIViewController()
            presentEmailComposerWithLogs()
            return true
        } else {
            return startApplication(application, withLaunchOptions: launchOptions)
        }
    }

    private func startApplication(application: UIApplication,  withLaunchOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        log.debug("Setting UA…")
#if !BRAVE
        // Set the Firefox UA for browsing.
        setUserAgent()
#endif
        log.debug("Starting keyboard helper…")
        // Start the keyboard helper to monitor and cache keyboard state.
        KeyboardHelper.defaultHelper.startObserving()

        log.debug("Starting dynamic font helper…")
        // Start the keyboard helper to monitor and cache keyboard state.
        DynamicFontHelper.defaultHelper.startObserving()

        log.debug("Setting custom menu items…")
        MenuHelper.defaultHelper.setItems()

        log.debug("Creating Sync log file…")
        let logDate = NSDate()
        // Create a new sync log file on cold app launch. Note that this doesn't roll old logs.
        Logger.syncLogger.newLogWithDate(logDate)

        log.debug("Creating corrupt DB logger…")
        Logger.corruptLogger.newLogWithDate(logDate)

        log.debug("Creating Browser log file…")
        Logger.browserLogger.newLogWithDate(logDate)
        log.debug("Getting profile…")
        let profile = getProfile(application)

        if !DebugSettingsBundleOptions.disableLocalWebServer {
            log.debug("Starting web server…")
            // Set up a web server that serves us static content. Do this early so that it is ready when the UI is presented.
            setUpWebServer(profile)
        }

        log.debug("Setting AVAudioSession category…")
        do {
            // for aural progress bar: play even with silent switch on, and do not stop audio from other apps (like music)
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, withOptions: AVAudioSessionCategoryOptions.MixWithOthers)
        } catch _ {
            log.error("Failed to assign AVAudioSession category to allow playing with silent switch on for aural progress bar")
        }

        let defaultRequest = NSURLRequest(URL: UIConstants.DefaultHomePage)
        let imageStore = DiskImageStore(files: profile.files, namespace: "TabManagerScreenshots", quality: UIConstants.ScreenshotQuality)

        log.debug("Configuring tabManager…")
        self.tabManager = TabManager(defaultNewTabRequest: defaultRequest, prefs: profile.prefs, imageStore: imageStore)
        self.tabManager.stateDelegate = self

        browserViewController = BraveBrowserViewController(profile: profile, tabManager: self.tabManager)
        browserViewController.restorationIdentifier = NSStringFromClass(BrowserViewController.self)
        browserViewController.restorationClass = AppDelegate.self
        browserViewController.automaticallyAdjustsScrollViewInsets = false

        let topmost = BraveTopViewController(browser: browserViewController as! BraveBrowserViewController)

        rootViewController = UINavigationController(rootViewController: topmost)
        rootViewController.automaticallyAdjustsScrollViewInsets = false
        rootViewController.delegate = self
        rootViewController.navigationBarHidden = true
        self.window!.rootViewController = rootViewController

#if !BRAVE
        activeCrashReporter = BreakpadCrashReporter(breakpadInstance: BreakpadController.sharedInstance())
        configureActiveCrashReporter(profile.prefs.boolForKey("crashreports.send.always"))
#endif

        log.debug("Adding observers…")
        NSNotificationCenter.defaultCenter().addObserverForName(FSReadingListAddReadingListItemNotification, object: nil, queue: nil) { (notification) -> Void in
            if let userInfo = notification.userInfo, url = userInfo["URL"] as? NSURL {
                let title = (userInfo["Title"] as? String) ?? ""
                profile.readingList?.createRecordWithURL(url.absoluteString, title: title, addedBy: UIDevice.currentDevice().name)
            }
        }

        // check to see if we started 'cos someone tapped on a notification.
        if let localNotification = launchOptions?[UIApplicationLaunchOptionsLocalNotificationKey] as? UILocalNotification {
            viewURLInNewTab(localNotification)
        }
        
        adjustIntegration = AdjustIntegration(profile: profile)

        // We need to check if the app is a clean install to use for
        // preventing the What's New URL from appearing.
        if getProfile(application).prefs.intForKey(IntroViewControllerSeenProfileKey) == nil {
            getProfile(application).prefs.setString(AppInfo.appVersion, forKey: LatestAppVersionProfileKey)
        }
        log.debug("Done with setting up the application.")

#if BRAVE
        BraveApp.willFinishLaunching_end()
#endif
        return true
    }

    func applicationWillTerminate(application: UIApplication) {
        log.debug("Application will terminate.")

        // We have only five seconds here, so let's hope this doesn't take too long.
        self.profile?.shutdown()

        // Allow deinitializers to close our database connections.
        self.profile = nil
        self.tabManager = nil
        self.browserViewController = nil
        self.rootViewController = nil
    }

    /**
     * We maintain a weak reference to the profile so that we can pause timed
     * syncs when we're backgrounded.
     *
     * The long-lasting ref to the profile lives in BrowserViewController,
     * which we set in application:willFinishLaunchingWithOptions:.
     *
     * If that ever disappears, we won't be able to grab the profile to stop
     * syncing... but in that case the profile's deinit will take care of things.
     */
    func getProfile(application: UIApplication) -> Profile {
        if let profile = self.profile {
            return profile
        }
        let clearProfile = NSProcessInfo.processInfo().environment["MOZ_WIPE_PROFILE"] != nil
        let p = BrowserProfile(localName: "profile", app: application, clear: clearProfile)
        self.profile = p
        return p
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        var shouldPerformAdditionalDelegateHandling = true

        log.debug("Did finish launching.")
        
        log.debug("Setting up Adjust")
        self.adjustIntegration?.triggerApplicationDidFinishLaunchingWithOptions(launchOptions)
        
        log.debug("Making window key and visible…")
        self.window!.makeKeyAndVisible()

        // Now roll logs.
        log.debug("Triggering log roll.")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            Logger.syncLogger.deleteOldLogsDownToSizeLimit()
            Logger.browserLogger.deleteOldLogsDownToSizeLimit()
        }


        if #available(iOS 9, *) {
            // If a shortcut was launched, display its information and take the appropriate action
            if let shortcutItem = launchOptions?[UIApplicationLaunchOptionsShortcutItemKey] as? UIApplicationShortcutItem {

                QuickActions.sharedInstance.launchedShortcutItem = shortcutItem
                // This will block "performActionForShortcutItem:completionHandler" from being called.
                shouldPerformAdditionalDelegateHandling = false
            }
        }

        log.debug("Done with applicationDidFinishLaunching.")
        return shouldPerformAdditionalDelegateHandling
    }

    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
        if let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false) {
#if BRAVE
            if !BraveApp.shouldHandleOpenURL(components) { return false }
#else
            if components.scheme != "firefox" && components.scheme != "firefox-x-callback" {
                return false
            }
#endif
            var url: String?
            for item in (components.queryItems ?? []) as [NSURLQueryItem] {
                switch item.name {
                case "url":
                    url = item.value
                default: ()
                }
            }

            if let url = url, newURL = NSURL(string: url.unescape()) {
                // If we are active then we can ask the BVC to open the new tab right away. Else we remember the
                // URL and we open it in applicationDidBecomeActive.
                if application.applicationState == .Active {
                    if #available(iOS 9, *) {
                        self.browserViewController.switchToPrivacyMode(isPrivate: false)
                    }
                    self.browserViewController.openURLInNewTab(newURL)
                } else {
                    openInBraveURL = newURL
                }
                return true
            }
        }
        return false
    }

    func application(application: UIApplication, shouldAllowExtensionPointIdentifier extensionPointIdentifier: String) -> Bool {
        return extensionPointIdentifier != UIApplicationKeyboardExtensionPointIdentifier
    }

    // We sync in the foreground only, to avoid the possibility of runaway resource usage.
    // Eventually we'll sync in response to notifications.
    func applicationDidBecomeActive(application: UIApplication) {
        guard !DebugSettingsBundleOptions.launchIntoEmailComposer else {
            return
        }

        self.profile?.syncManager.applicationDidBecomeActive()

        // We could load these here, but then we have to futz with the tab counter
        // and making NSURLRequests.
        self.browserViewController.loadQueuedTabs()

        // handle quick actions is available
        if #available(iOS 9, *) {
            let quickActions = QuickActions.sharedInstance
            if let shortcut = quickActions.launchedShortcutItem {
                // dispatch asynchronously so that BVC is all set up for handling new tabs
                // when we try and open them
                quickActions.handleShortCutItem(shortcut, withBrowserViewController: browserViewController)
                quickActions.launchedShortcutItem = nil
            }
        }

        // If we have a URL waiting to open, switch to non-private mode and open the URL.
        if let url = openInBraveURL {
            openInBraveURL = nil
            // This needs to be scheduled so that the BVC is ready.
            dispatch_async(dispatch_get_main_queue()) {
                if #available(iOS 9, *) {
                    self.browserViewController.switchToPrivacyMode(isPrivate: false)
                }
                self.browserViewController.switchToTabForURLOrOpen(url)
            }
        }
    }

    func applicationDidEnterBackground(application: UIApplication) {
        self.profile?.syncManager.applicationDidEnterBackground()

        var taskId: UIBackgroundTaskIdentifier = 0
        taskId = application.beginBackgroundTaskWithExpirationHandler { _ in
            log.warning("Running out of background time, but we have a profile shutdown pending.")
            application.endBackgroundTask(taskId)
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            self.profile?.shutdown()
            application.endBackgroundTask(taskId)
        }

        // Workaround for crashing in the background when <select> popovers are visible (rdar://24571325).
        let jsBlurSelect = "if (document.activeElement && document.activeElement.tagName === 'SELECT') { document.activeElement.blur(); }"
        tabManager.selectedTab?.webView?.evaluateJavaScript(jsBlurSelect, completionHandler: nil)
    }

    private func setUpWebServer(profile: Profile) {
        let server = WebServer.sharedInstance
        ReaderModeHandlers.register(server, profile: profile)
        ErrorPageHelper.register(server)
        AboutHomeHandler.register(server)
        AboutLicenseHandler.register(server)
        SessionRestoreHandler.register(server)
        // Bug 1223009 was an issue whereby CGDWebserver crashed when moving to a background task
        // catching and handling the error seemed to fix things, but we're not sure why.
        // Either way, not implicitly unwrapping a try is not a great way of doing things
        // so this is better anyway.
        do {
            try server.start()
        } catch let err as NSError {
            log.error("Unable to start WebServer \(err)")
        }
    }

    private func setUserAgent() {
        let firefoxUA = UserAgent.defaultUserAgent()

        // Set the UA for WKWebView (via defaults), the favicon fetcher, and the image loader.
        // This only needs to be done once per runtime. Note that we use defaults here that are
        // readable from extensions, so they can just use the cached identifier.
        let defaults = NSUserDefaults(suiteName: AppInfo.sharedContainerIdentifier())!
        defaults.registerDefaults(["UserAgent": firefoxUA])

        SDWebImageDownloader.sharedDownloader().setValue(firefoxUA, forHTTPHeaderField: "User-Agent")

        // Record the user agent for use by search suggestion clients.
        SearchViewController.userAgent = firefoxUA

        // Some sites will only serve HTML that points to .ico files.
        // The FaviconFetcher is explicitly for getting high-res icons, so use the desktop user agent.
        FaviconFetcher.userAgent = UserAgent.desktopUserAgent()
    }

    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
        if let actionId = identifier {
            if let action = SentTabAction(rawValue: actionId) {
                viewURLInNewTab(notification)
                switch(action) {
                case .Bookmark:
                    addBookmark(notification)
                    break
                case .ReadingList:
                    addToReadingList(notification)
                    break
                default:
                    break
                }
            } else {
                print("ERROR: Unknown notification action received")
            }
        } else {
            print("ERROR: Unknown notification received")
        }
    }

    func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        viewURLInNewTab(notification)
    }

    private func presentEmailComposerWithLogs() {
        if let buildNumber = NSBundle.mainBundle().objectForInfoDictionaryKey(String(kCFBundleVersionKey)) as? NSString {
            let mailComposeViewController = MFMailComposeViewController()
            mailComposeViewController.mailComposeDelegate = self
            mailComposeViewController.setSubject("Debug Info for iOS client version v\(appVersion) (\(buildNumber))")

            if DebugSettingsBundleOptions.attachLogsToDebugEmail {
                do {
                    let logNamesAndData = try Logger.diskLogFilenamesAndData()
                    logNamesAndData.forEach { nameAndData in
                        if let data = nameAndData.1 {
                            mailComposeViewController.addAttachmentData(data, mimeType: "text/plain", fileName: nameAndData.0)
                        }
                    }
                } catch _ {
                    print("Failed to retrieve logs from device")
                }
            }

            if DebugSettingsBundleOptions.attachTabStateToDebugEmail {
                if let tabStateDebugData = TabManager.tabRestorationDebugInfo().dataUsingEncoding(NSUTF8StringEncoding) {
                    mailComposeViewController.addAttachmentData(tabStateDebugData, mimeType: "text/plain", fileName: "tabState.txt")
                }

                if let tabStateData = TabManager.tabArchiveData() {
                    mailComposeViewController.addAttachmentData(tabStateData, mimeType: "application/octet-stream", fileName: "tabsState.archive")
                }
            }

            self.window?.rootViewController?.presentViewController(mailComposeViewController, animated: true, completion: nil)
        }
    }

    func application(application: UIApplication, continueUserActivity userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
        if let url = userActivity.webpageURL {
            browserViewController.switchToTabForURLOrOpen(url)
            return true
        }
        return false
    }

    private func viewURLInNewTab(notification: UILocalNotification) {
        if let alertURL = notification.userInfo?[TabSendURLKey] as? String {
            if let urlToOpen = NSURL(string: alertURL) {
                browserViewController.openURLInNewTab(urlToOpen)

                if #available(iOS 9, *) {
                    var userData = [QuickActions.TabURLKey: alertURL]
                    if let title = notification.userInfo?[TabSendTitleKey] as? String where title.characters.count > 0 {
                        userData[QuickActions.TabTitleKey] = title
                    } else {
                        userData[QuickActions.TabTitleKey] = alertURL
                    }
                    QuickActions.sharedInstance.addDynamicApplicationShortcutItemOfType(.OpenLastTab, withUserData: userData, toApplication: UIApplication.sharedApplication())
                }
            }
        }
    }

    private func addBookmark(notification: UILocalNotification) {
        if let alertURL = notification.userInfo?[TabSendURLKey] as? String,
            let title = notification.userInfo?[TabSendTitleKey] as? String {
                browserViewController.addBookmark(alertURL, title: title)

                if #available(iOS 9, *) {
                    let userData = [QuickActions.TabURLKey: alertURL,
                        QuickActions.TabTitleKey: title]
                    QuickActions.sharedInstance.addDynamicApplicationShortcutItemOfType(.OpenLastBookmark, withUserData: userData, toApplication: UIApplication.sharedApplication())
                }
        }
    }

    private func addToReadingList(notification: UILocalNotification) {
        if let alertURL = notification.userInfo?[TabSendURLKey] as? String,
           let title = notification.userInfo?[TabSendTitleKey] as? String {
            if let urlToOpen = NSURL(string: alertURL) {
                NSNotificationCenter.defaultCenter().postNotificationName(FSReadingListAddReadingListItemNotification, object: self, userInfo: ["URL": urlToOpen, "Title": title])
            }
        }
    }

    @available(iOS 9.0, *)
    func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: Bool -> Void) {
        let handledShortCutItem = QuickActions.sharedInstance.handleShortCutItem(shortcutItem, withBrowserViewController: browserViewController)

        completionHandler(handledShortCutItem)
    }

#if !BRAVE
  var activeCrashReporter: CrashReporter?
  func configureActiveCrashReporter(optedIn: Bool?) {
    if let reporter = activeCrashReporter {
      configureCrashReporter(reporter, optedIn: optedIn)
    }
  }
#endif
}

// MARK: - Root View Controller Animations
extension AppDelegate: UINavigationControllerDelegate {
#if !BRAVE
    func navigationController(navigationController: UINavigationController,
        animationControllerForOperation operation: UINavigationControllerOperation,
        fromViewController fromVC: UIViewController,
        toViewController toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            if operation == UINavigationControllerOperation.Push {
                return BrowserToTrayAnimator()
            } else if operation == UINavigationControllerOperation.Pop {
                return TrayToBrowserAnimator()
            } else {
                return nil
            }
    }
#endif
}

extension AppDelegate: TabManagerStateDelegate {
    func tabManagerWillStoreTabs(tabs: [Browser]) {
        // It is possible that not all tabs have loaded yet, so we filter out tabs with a nil URL.
        let storedTabs: [RemoteTab] = tabs.flatMap( Browser.toTab )

        // Don't insert into the DB immediately. We tend to contend with more important
        // work like querying for top sites.
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(ProfileRemoteTabsSyncDelay * Double(NSEC_PER_MSEC))), queue) {
            self.profile?.storeTabs(storedTabs)
        }
    }
}

extension AppDelegate: MFMailComposeViewControllerDelegate {
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        // Dismiss the view controller and start the app up
        controller.dismissViewControllerAnimated(true, completion: nil)
        startApplication(application!, withLaunchOptions: self.launchOptions)
    }
}