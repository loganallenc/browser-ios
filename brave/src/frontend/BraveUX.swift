/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

struct BraveUX {
    static let MaxTabsInMemory = 9

    static var PanelShadowWidth = 15

    static var TitleForBraveProtectionOff = "Shields Down"
    static var TitleForBraveProtectionOn = "Shields Up"
    static let BraveButtonMessageInUrlBarColor = UIColor(colorLiteralRed: 1.0, green: 80/255.0, blue: 0, alpha: 1.0)
    static let BraveButtonMessageInUrlBarShowTime = 0.5
    static let BraveButtonMessageInUrlBarFadeTime = 0.7

    // I am considering using DeviceInfo.isBlurSupported() to set this, and reduce heavy animations
    static var IsHighLoadAnimationAllowed = true

    static let WidthOfSlideOut = 260

    static let PullToReloadDistance = 100

    static let PanelClosingThresholdWhenDragging = 0.3 // a percent range 1.0 to 0

    static let BrowserViewAlphaWhenShowingTabTray = 0.3

    static let PrefKeyIsToolbarHidingEnabled = "PrefKeyIsToolbarHidingEnabled"

    static let BackgroundColorForBookmarksHistoryAndTopSites = UIColor(white: 242/255.0, alpha: 1.0)

    // debug settings
    //  static var IsToolbarHidingOff = false
    //  static var IsOverrideScrollingSpeedAndMakeSlower = false // overrides IsHighLoadAnimationAllowed effect

    // set to true to show borders around views
    static let DebugShowBorders = false

    static let BackForwardDisabledButtonAlpha = CGFloat(0.3)
    static let BackForwardEnabledButtonAlpha = CGFloat(1.0)

    static let TopLevelBackgroundColor = UIColor(white: 0.67, alpha: 1.0)

    static let LocationBarTextColor = UIColor(white: 255/255.0, alpha: 1)
    static let LocationBarEditModeBackgroundColor = UIColor(white: 242/255.0, alpha: 1.0)
    static let LocationBarEditModeTextColor = UIColor(white: 0/255.0, alpha: 1)

    static let LocationBarBackgroundColor = UIColor(white: 200/255.0, alpha: 0.3)
    static let LocationBarBackgroundColor_PrivateMode = UIColor.blackColor()

    static let LocationBarEditModeBackgroundColor_Private = UIColor(white: 0/255.0, alpha: 1.0)
    static let LocationBarEditModeTextColor_Private = UIColor(white: 242/255.0, alpha: 1)

    // Interesting: compontents of the url can be colored differently: http://www.foo.com
    // Base: http://www and Host: foo.com
    static let LocationBarTextColor_URLBaseComponent = LocationBarTextColor
    static let LocationBarTextColor_URLHostComponent = LocationBarTextColor

    static let TextFieldCornerRadius = 14.0
    static let TextFieldBorderColor_HasFocus = UIColor.grayColor()
    static let TextFieldBorderColor_NoFocus = UIColor.blackColor()

    static let CancelTextColor = LocationBarTextColor
    // The toolbar button color (for the Normal state). Using default highlight color ATM
    static let ActionButtonTintColor = LocationBarTextColor

    static let AutocompleteTextFieldHighlightColor = UIColor(colorLiteralRed: 0/255.0, green: 118/255.0, blue: 255/255.0, alpha: 1.0)

    // Yes it could be detected, just make life easier and set this number for now
    static let BottomToolbarNumberButtonsToRightOfBackForward = 3
    static let BackForwardButtonLeftOffset = CGFloat(10)

    static let ProgressBarColor = UIColor(colorLiteralRed: 0/255.0, green: 118/255.0, blue: 255/255.0, alpha: 1.0)
    
    static let TabTrayCellCornerRadius = 14.0
    static let TabTrayCellFaviconSize = 54.0
    static let TabTrayCellCloseButtonSize = 24.0
    static let TabTrayCellBackgroundColor = UIColor.whiteColor()
}
