/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#if !NO_FABRIC
import Crashlytics
#endif
import Shared

class BraveSettingsView : AppSettingsTableViewController {

    var debugToggleItemToTriggerCrashCount = 0

    override func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section != 2 {
            return nil
        }

        let footerView = InsetLabel(frame: CGRectMake(0, 0, tableView.frame.size.width, 40))
        footerView.leftInset = CGFloat(20)
        footerView.rightInset = CGFloat(10)
        footerView.numberOfLines = 0
        footerView.font = UIFont.boldSystemFontOfSize(13)

        if BraveSettingsView.isAllBraveShieldPrefsOff {
            footerView.text = "The Brave Shield button is disabled when all settings are off."
            return footerView
        } else if BraveApp.isBraveButtonBypassingFilters {
            footerView.text = "Brave Shields are currently down. These settings only take effect when shields are up."
            return footerView
        }

        return nil
    }

    override func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section != 2 || !(BraveApp.isBraveButtonBypassingFilters || BraveSettingsView.isAllBraveShieldPrefsOff) {
            return 0
        }
        return 40.0
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    let SEL_prefsChanged = "prefsChanged:"
    static var isAllBraveShieldPrefsOff = false
    @objc func prefsChanged(notification: NSNotification) {
        BraveSettingsView.isAllBraveShieldPrefsOff = BraveApp.isAllBraveShieldPrefsOff()
        delay(0.1) {
            self.tableView.reloadData()
        }
    }

    override func generateSettings() -> [SettingSection] {
        BraveSettingsView.isAllBraveShieldPrefsOff = BraveApp.isAllBraveShieldPrefsOff()

        NSNotificationCenter.defaultCenter().removeObserver(self)
        NSNotificationCenter.defaultCenter().addObserver(self, selector:NSSelectorFromString(SEL_prefsChanged), name: NSUserDefaultsDidChangeNotification, object: nil)

        let prefs = profile.prefs
        let generalSettings = [
            SearchSetting(settings: self),
            BoolSetting(prefs: prefs, prefKey: BraveUX.PrefKeyIsToolbarHidingEnabled , defaultValue: true, titleText: "Hide toolbar when scrolling", statusText: nil, settingDidChange:  { value in
                BraveScrollController.hideShowToolbarEnabled = value

                // Hidden way to trigger a crash for testing
                if (self.debugToggleItemToTriggerCrashCount > 4) {
                    UIAlertView(title: "Trigger a crash for testing", message: "Force a crash?", delegate: self, cancelButtonTitle: "Cancel", otherButtonTitles: "OK").show()
                    self.debugToggleItemToTriggerCrashCount = 0
                } else {
                    self.debugToggleItemToTriggerCrashCount++
                }
            })
//            BoolSetting(prefs: prefs, prefKey: "blockPopups", defaultValue: true,
//                titleText: NSLocalizedString("Block Pop-up Windows", comment: "Block pop-up windows setting")),
//            BoolSetting(prefs: prefs, prefKey: "saveLogins", defaultValue: true,
//                titleText: NSLocalizedString("Save Logins", comment: "Setting to enable the built-in password manager")),
        ]
        
        settings += [
            SettingSection(title: NSAttributedString(string: NSLocalizedString("General", comment: "General settings section title")), children: generalSettings),
            SettingSection(title: NSAttributedString(string: NSLocalizedString("Privacy", comment: "Privacy settings section title")), children:
                [ClearPrivateDataSetting(settings: self), CookieSetting(settings: self)]

            ),
            SettingSection(title: NSAttributedString(string: NSLocalizedString("Brave Shield Settings", comment: "Section title for adbblock, tracking protection, HTTPS-E, and cookies")), children:
                [BoolSetting(prefs: prefs, prefKey: AdBlocker.prefKeyAdBlockOn, defaultValue: true, titleText: "Block Ads"),
                BoolSetting(prefs: prefs, prefKey: TrackingProtection.prefKeyTrackingProtectionOn, defaultValue: true, titleText: "Tracking Protection"),
                BoolSetting(prefs: prefs, prefKey: HttpsEverywhere.prefKeyHttpsEverywhereOn, defaultValue: true, titleText: "HTTPS Everywhere")])]

//#if !DISABLE_INTRO_SCREEN
        settings += [
            SettingSection(title: NSAttributedString(string: NSLocalizedString("Support", comment: "Support section title")), children: [
                ShowIntroductionSetting(settings: self),
                BravePrivacyPolicySetting(), BraveTermsOfUseSetting(), 
                ])]
//#endif
        settings += [
            SettingSection(title: NSAttributedString(string: NSLocalizedString("About", comment: "About settings section title")), children: [
                VersionSetting(settings: self),
            ])
        ]
        return settings
    }
}

extension BraveSettingsView : UIAlertViewDelegate {
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        if buttonIndex == alertView.cancelButtonIndex {
            return
        }
#if !NO_FABRIC
        Crashlytics.sharedInstance().crash()
#endif
    }
}

// Opens the search settings pane
class CookieSetting: Setting, PicklistSettingDelegate {
    let profile: Profile

    static var prefAcceptCookies = "braveAcceptCookiesPref"

    let heading = "Cookie Control"
    override var accessoryType: UITableViewCellAccessoryType { return .DisclosureIndicator }

    override var style: UITableViewCellStyle { return .Value1 }

    override var status: NSAttributedString {
        let prefs = profile.prefs
        let current = prefs.intForKey(CookieSetting.prefAcceptCookies) ?? 0
        return NSAttributedString(string: CookieSetting.getOption(Int(current)))
    }

    static func getOptions() -> [String] {
        return ["Block 3rd party cookies", "Block all cookies", "Don't block cookies"]
    }

    static func checkIndexOk(index: Int) -> Bool {
        let options = getOptions()
        return 0..<options.count ~= index
    }

    static func getOption(index: Int) -> String {
        let options = getOptions()
        return checkIndexOk(index) ? options[index] : options[0]
    }

    static func indexToPolicy(index: UInt) -> NSHTTPCookieAcceptPolicy {
        switch index {
        case 1:
            return NSHTTPCookieAcceptPolicy.Never
        case 2:
            return NSHTTPCookieAcceptPolicy.Always
        default:
            return NSHTTPCookieAcceptPolicy.OnlyFromMainDocumentDomain
        }
    }

    static func setup() {
        let current = BraveApp.getPref(CookieSetting.prefAcceptCookies) as? Int ?? 0
        NSHTTPCookieStorage.sharedHTTPCookieStorage().cookieAcceptPolicy = CookieSetting.indexToPolicy(UInt(current))
    }

    init(settings: SettingsTableViewController) {
        self.profile = settings.profile
        super.init(title: NSAttributedString(string: heading, attributes: [NSForegroundColorAttributeName: UIConstants.TableViewRowTextColor]))
    }

    var cookiePickList: PicklistSetting? // on iOS8 there is a crash, seems like it requires this to be retained
    override func onClick(navigationController: UINavigationController?) {
        let current = BraveApp.getPref(CookieSetting.prefAcceptCookies) as? Int ?? 0
        cookiePickList = PicklistSetting(options: CookieSetting.getOptions(), title: heading, current: current)
        navigationController?.pushViewController(cookiePickList!, animated: true)
        cookiePickList!.delegate = self
    }

    func picklistSetting(setting: PicklistSetting, pickedIndex: Int) {
        let prefs = profile.prefs
        prefs.setInt(Int32(pickedIndex), forKey: CookieSetting.prefAcceptCookies)
        NSHTTPCookieStorage.sharedHTTPCookieStorage().cookieAcceptPolicy = CookieSetting.indexToPolicy(UInt(pickedIndex))
    }
}

// Clear all stored passwords. This will clear SQLite storage and the system shared credential storage.
class PasswordsClearable: Clearable {
    let profile: Profile
    init(profile: Profile) {
        self.profile = profile
    }

    var label: String {
        return NSLocalizedString("Saved Logins", tableName: "ClearPrivateData", comment: "Settings item for clearing passwords and login data")
    }

    func clear() -> Success {
        // Clear our storage
        return profile.logins.removeAll() >>== { res in
            let storage = NSURLCredentialStorage.sharedCredentialStorage()
            let credentials = storage.allCredentials
            for (space, credentials) in credentials {
                for (_, credential) in credentials {
                    storage.removeCredential(credential, forProtectionSpace: space)
                }
            }
            return succeed()
        }
    }
}

class BravePrivacyPolicySetting: Setting {
    override var title: NSAttributedString? {
        return NSAttributedString(string: NSLocalizedString("Privacy Policy", comment: "Show Brave Browser Privacy Policy page from the Privacy section in the settings."), attributes: [NSForegroundColorAttributeName: UIConstants.TableViewRowTextColor])
    }

    override var url: NSURL? {
        return NSURL(string: "https://www.brave.com/privacy_ios")
    }

    override func onClick(navigationController: UINavigationController?) {
        setUpAndPushSettingsContentViewController(navigationController)
    }
}

class BraveTermsOfUseSetting: Setting {
    override var title: NSAttributedString? {
        return NSAttributedString(string: NSLocalizedString("Terms of Use", comment: "Show Brave Browser TOS page from the Privacy section in the settings."), attributes: [NSForegroundColorAttributeName: UIConstants.TableViewRowTextColor])
    }

    override var url: NSURL? {
        return NSURL(string: "https://www.brave.com/terms_of_use")
    }

    override func onClick(navigationController: UINavigationController?) {
        setUpAndPushSettingsContentViewController(navigationController)
    }
}



