/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// To hide the curve effect
class HideCurveView : CurveView {
    override func drawRect(rect: CGRect) {}
}

extension UILabel {
    func boldRange(range: Range<String.Index>) {
        if let text = self.attributedText {
            let attr = NSMutableAttributedString(attributedString: text)
            let start = text.string.startIndex.distanceTo(range.startIndex)
            let length = range.startIndex.distanceTo(range.endIndex)
            attr.addAttributes([NSFontAttributeName: UIFont.boldSystemFontOfSize(self.font.pointSize)], range: NSMakeRange(start, length))
            self.attributedText = attr
        }
    }

    func boldSubstring(substr: String) {
        let range = self.text?.rangeOfString(substr)
        if let r = range {
            boldRange(r)
        }
    }
}

class BraveURLBarView : URLBarView {

    private static weak var currentInstance: BraveURLBarView?
    lazy var leftSidePanelButton = { return UIButton() }()
    lazy var braveButton = { return UIButton() }()

    override func commonInit() {
        BraveURLBarView.currentInstance = self
        locationContainer.layer.cornerRadius = CGFloat(BraveUX.TextFieldCornerRadius)
        curveShape = HideCurveView()

        addSubview(leftSidePanelButton)
        addSubview(braveButton)
        super.commonInit()

        leftSidePanelButton.addTarget(self, action: NSSelectorFromString(SEL_onClickLeftSlideOut), forControlEvents: UIControlEvents.TouchUpInside)
        leftSidePanelButton.setImage(UIImage(named: "listpanel"), forState: .Normal)
        leftSidePanelButton.setImage(UIImage(named: "listpanel_down")?.imageWithRenderingMode(.AlwaysTemplate), forState: .Selected)
        leftSidePanelButton.accessibilityLabel = NSLocalizedString("Bookmarks and History Panel", comment: "Button to show the bookmarks and history panel")
        leftSidePanelButton.tintColor = BraveUX.ActionButtonTintColor

        braveButton.addTarget(self, action: NSSelectorFromString(SEL_onClickBraveButton) , forControlEvents: UIControlEvents.TouchUpInside)
        braveButton.setImage(UIImage(named: "bravePanelButton"), forState: .Normal)
        braveButton.setImage(UIImage(named: "bravePanelButtonOff"), forState: .Selected)
        braveButton.accessibilityLabel = NSLocalizedString("Brave Panel", comment: "Button to show the brave panel")
        braveButton.tintColor = BraveUX.ActionButtonTintColor

        ToolbarTextField.appearance().clearButtonTintColor = nil

        var theme = Theme()
        theme.URLFontColor = BraveUX.LocationBarTextColor_URLBaseComponent
        theme.hostFontColor = BraveUX.LocationBarTextColor_URLHostComponent
        theme.backgroundColor = BraveUX.LocationBarBackgroundColor
        BrowserLocationViewUX.Themes[Theme.NormalMode] = theme

        theme = Theme()
        theme.URLFontColor = BraveUX.LocationBarTextColor_URLBaseComponent
        theme.hostFontColor = BraveUX.LocationBarTextColor_URLHostComponent
        theme.backgroundColor = BraveUX.LocationBarBackgroundColor_PrivateMode
        BrowserLocationViewUX.Themes[Theme.PrivateMode] = theme

        theme = Theme()
        theme.backgroundColor = BraveUX.LocationBarEditModeBackgroundColor
        theme.textColor = BraveUX.LocationBarEditModeTextColor
        ToolbarTextField.Themes[Theme.NormalMode] = theme

        theme = Theme()
        theme.backgroundColor = BraveUX.LocationBarEditModeBackgroundColor_Private
        theme.textColor = BraveUX.LocationBarEditModeTextColor_Private
        ToolbarTextField.Themes[Theme.PrivateMode] = theme

        theme = Theme()
        theme.borderColor = BraveUX.TextFieldBorderColor_NoFocus
        theme.activeBorderColor = BraveUX.TextFieldBorderColor_HasFocus
        theme.tintColor = URLBarViewUX.ProgressTintColor
        theme.textColor = BraveUX.LocationBarTextColor
        theme.buttonTintColor = BraveUX.ActionButtonTintColor
        URLBarViewUX.Themes[Theme.NormalMode] = theme
    }

    override func applyTheme(themeName: String) {
        super.applyTheme(themeName)
//        if themeName == Theme.NormalMode {
//            backgroundColor = BraveUX.LocationBarBackgroundColor
//        }
//        if themeName == Theme.PrivateMode {
//            backgroundColor = BraveUX.LocationBarBackgroundColor_PrivateMode
//        }
    }

    override func updateAlphaForSubviews(alpha: CGFloat) {
        super.updateAlphaForSubviews(alpha)
        self.superview?.alpha = alpha
    }

    let SEL_onClickLeftSlideOut = "onClickLeftSlideOut"
    func onClickLeftSlideOut() {
        leftSidePanelButton.selected = !leftSidePanelButton.selected
        NSNotificationCenter.defaultCenter().postNotificationName(kNotificationLeftSlideOutClicked, object: leftSidePanelButton)
    }

    let SEL_onClickBraveButton = "onClickBraveButton"
    func onClickBraveButton() {
        if BraveApp.isAllBraveShieldPrefsOff() {
            return
        }

        braveButton.selected = !braveButton.selected
        let v = InsetLabel(frame: CGRectMake(0, 0, locationContainer.frame.width, locationContainer.frame.height))
        v.rightInset = CGFloat(20)
        v.text = braveButton.selected ? BraveUX.TitleForBraveProtectionOff : BraveUX.TitleForBraveProtectionOn
        if var range = v.text!.rangeOfString(" ", options:NSStringCompareOptions.BackwardsSearch) {
            range.endIndex = v.text!.characters.endIndex
            v.boldRange(range)
        }
        v.backgroundColor = BraveUX.BraveButtonMessageInUrlBarColor
        v.textAlignment = .Right
        locationContainer.addSubview(v)
        v.alpha = 0.0
        UIView.animateWithDuration(0.25, animations: { v.alpha = 1.0 }, completion: {
            finished in
            UIView.animateWithDuration(BraveUX.BraveButtonMessageInUrlBarFadeTime, delay: BraveUX.BraveButtonMessageInUrlBarShowTime, options: [], animations: { v.alpha = 0 }, completion: {
                finished in
                v.removeFromSuperview()
            })
        })
        NSNotificationCenter.defaultCenter().postNotificationName(kNotificationBraveButtonClicked, object: braveButton)
    }

    override func updateTabCount(count: Int, animated: Bool = true) {
        super.updateTabCount(count, animated: toolbarIsShowing)
        BraveBrowserBottomToolbar.updateTabCountDuplicatedButton(count, animated: animated)
    }

    class func tabButtonPressed() {
        guard let instance = BraveURLBarView.currentInstance else { return }
        instance.delegate?.urlBarDidPressTabs(instance)
    }

    override var accessibilityElements: [AnyObject]? {
        get {
            if inOverlayMode {
                guard let locationTextField = locationTextField else { return nil }
                return [leftSidePanelButton, locationTextField, cancelButton]
            } else {
                if toolbarIsShowing {
                    return [backButton, forwardButton, leftSidePanelButton, locationView, braveButton, shareButton, tabsButton]
                } else {
                    return [leftSidePanelButton, locationView, braveButton, progressBar]
                }
            }
        }
        set {
            super.accessibilityElements = newValue
        }
    }

    override func updateViewsForOverlayModeAndToolbarChanges() {
        super.updateViewsForOverlayModeAndToolbarChanges()

        if !self.toolbarIsShowing {
            self.tabsButton.hidden = true
        } else {
            self.tabsButton.hidden = false
        }

        self.stopReloadButton.hidden = true
        progressBar.hidden = true
        bookmarkButton.hidden = true
    }

    override func prepareOverlayAnimation() {
        super.prepareOverlayAnimation()
        progressBar.hidden = true
        bookmarkButton.hidden = true
        braveButton.hidden = true
    }

    override func transitionToOverlay(didCancel: Bool = false) {
        super.transitionToOverlay(didCancel)
        bookmarkButton.hidden = true
        locationView.alpha = 0.0

        locationView.superview?.backgroundColor = locationTextField?.backgroundColor
    }

    override func leaveOverlayMode(didCancel cancel: Bool) {
        if !inOverlayMode {
            return
        }

        super.leaveOverlayMode(didCancel: cancel)
        locationView.alpha = 1.0

        // The orange brave button sliding in looks odd, lets fade it in in-place
        braveButton.alpha = 0
        braveButton.hidden = false
        UIView.animateWithDuration(0.3, animations: { self.braveButton.alpha = 1.0 })
    }

    override func updateConstraints() {
        super.updateConstraints()

        if BraveApp.isAllBraveShieldPrefsOff() {
            delay(0.1) {
                BraveApp.isBraveButtonBypassingFilters = true
                self.braveButton.selected = true
            }
        }

        curveShape.hidden = true
        bookmarkButton.hidden = true

        // TODO : remove this entirely
        progressBar.hidden = true
        progressBar.alpha = 0.0

        bookmarkButton.snp_removeConstraints()
        curveShape.snp_removeConstraints()

        func pinLeftPanelButtonToLeft() {
            leftSidePanelButton.snp_remakeConstraints { make in
                make.left.equalTo(self)
                make.centerY.equalTo(self)
                make.size.equalTo(UIConstants.ToolbarHeight)
            }
        }

        if inOverlayMode {
            // In overlay mode, we always show the location view full width
            self.locationContainer.snp_remakeConstraints { make in
                make.left.equalTo(self.leftSidePanelButton.snp_right)//.offset(URLBarViewUX.LocationLeftPadding)
                make.right.equalTo(self.cancelButton.snp_left)
                make.height.equalTo(URLBarViewUX.LocationHeight)
                make.centerY.equalTo(self)
            }
            pinLeftPanelButtonToLeft()
        } else {
            self.locationContainer.snp_remakeConstraints { make in
                if self.toolbarIsShowing {
                    // Firefox is not referring to the bottom toolbar, it is asking is this class showing more tool buttons
                    make.leading.equalTo(self.leftSidePanelButton.snp_trailing)
                    make.trailing.equalTo(self).inset(UIConstants.ToolbarHeight * 3)
                } else {
                    make.left.equalTo(self).inset(UIConstants.ToolbarHeight)
                    make.right.equalTo(self).inset(UIConstants.ToolbarHeight)
                }

                make.height.equalTo(URLBarViewUX.LocationHeight)
                make.centerY.equalTo(self)
            }

            if self.toolbarIsShowing {
                leftSidePanelButton.snp_remakeConstraints { make in
                    make.left.equalTo(self.forwardButton.snp_right)
                    make.centerY.equalTo(self)
                    make.size.equalTo(UIConstants.ToolbarHeight)
                }
            } else {
                pinLeftPanelButtonToLeft()
            }

            braveButton.snp_remakeConstraints { make in
                make.left.equalTo(self.locationContainer.snp_right)
                make.centerY.equalTo(self)
                make.size.equalTo(UIConstants.ToolbarHeight)
            }
        }
    }

    override func setupConstraints() {

        backButton.snp_makeConstraints { make in
            make.left.centerY.equalTo(self)
            make.size.equalTo(UIConstants.ToolbarHeight)
        }

        forwardButton.snp_makeConstraints { make in
            make.left.equalTo(self.backButton.snp_right)
            make.centerY.equalTo(self)
            make.size.equalTo(backButton)
        }

        leftSidePanelButton.snp_makeConstraints { make in
            make.left.equalTo(self.forwardButton.snp_right)
            make.centerY.equalTo(self)
            make.size.equalTo(UIConstants.ToolbarHeight)
        }

        locationView.snp_makeConstraints { make in
            make.edges.equalTo(self.locationContainer)
        }

        cancelButton.snp_makeConstraints { make in
            make.centerY.equalTo(self.locationContainer)
            make.trailing.equalTo(self)
        }

        shareButton.snp_remakeConstraints { make in
            make.right.equalTo(self.tabsButton.snp_left).offset(0)
            make.centerY.equalTo(self)
            make.width.equalTo(UIConstants.ToolbarHeight)
        }

        tabsButton.snp_makeConstraints { make in
            make.centerY.equalTo(self.locationContainer)
            make.trailing.equalTo(self)
            make.size.equalTo(UIConstants.ToolbarHeight)
        }
    }

    var progressIsCompleting = false
    override func updateProgressBar(progress: Float) {
        let minProgress = locationView.frame.width / 3.0

        func setWidth(width: CGFloat) {
            var frame = locationView.braveProgressView.frame
            frame.size.width = width
            locationView.braveProgressView.frame = frame
        }
        
        if progress == 1.0 {
            if progressIsCompleting {
                return
            }
            progressIsCompleting = true
            
            UIView.animateWithDuration(0.5, animations: {
                setWidth(self.locationView.frame.width)
                }, completion: { _ in
                    UIView.animateWithDuration(0.5, animations: {
                        self.locationView.braveProgressView.alpha = 0.0
                        }, completion: { _ in
                            self.progressIsCompleting = false
                            setWidth(0)
                    })
            })
        } else {
            self.locationView.braveProgressView.alpha = 1.0
            progressIsCompleting = false
            let w = minProgress + CGFloat(progress) * (self.locationView.frame.width - minProgress)
            
            if w > locationView.braveProgressView.frame.size.width {
                UIView.animateWithDuration(0.5, animations: {
                    setWidth(w)
                    }, completion: { _ in
                        
                })
            }
        }
    }
    
}
