/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Storage
import SnapKit

class MainSidePanelViewController : SidePanelBaseViewController {

    let bookmarks = BookmarksPanel()
    let history = HistoryPanel()

    var bookmarksButton = UIButton()
    var historyButton = UIButton()

    var settingsButton = UIButton()

    let topButtonsView = UIView()
    let addBookmarkButton = UIButton()

    //let triangleViewContainer = UIView()
    let triangleView = UIImageView()

    let tabTitleViewContainer = UIView()
    let tabTitleView = UILabel()

    let divider = UIView()

    let shadow = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()

        shadow.image = UIImage(named: "panel_shadow")
        shadow.contentMode = .ScaleToFill

        tabTitleViewContainer.backgroundColor = UIColor.whiteColor()
        tabTitleView.textColor = self.view.tintColor
        bookmarks.profile = getApp().profile
        history.profile = getApp().profile

        containerView.addSubview(topButtonsView)
        containerView.addSubview(tabTitleViewContainer)

        tabTitleViewContainer.addSubview(tabTitleView)
        topButtonsView.addSubview(triangleView)
        topButtonsView.addSubview(bookmarksButton)
        topButtonsView.addSubview(historyButton)
        topButtonsView.addSubview(addBookmarkButton)
        topButtonsView.addSubview(settingsButton)
        topButtonsView.addSubview(divider)

        divider.backgroundColor = UIColor.grayColor()

        triangleView.image = UIImage(named: "triangle-nub")
        triangleView.contentMode = UIViewContentMode.Center
        triangleView.alpha = 0.9

        settingsButton.setImage(UIImage(named: "settings")?.imageWithRenderingMode(.AlwaysTemplate), forState: .Normal)
        settingsButton.addTarget(self, action: NSSelectorFromString(SEL_onClickSettingsButton), forControlEvents: .TouchUpInside)
        settingsButton.accessibilityLabel = NSLocalizedString("Settings", comment: "Accessibility label for the Settings button.")

        bookmarksButton.setImage(UIImage(named: "bookmarklist"), forState: .Normal)
        bookmarksButton.addTarget(self, action: "showBookmarks", forControlEvents: .TouchUpInside)
        bookmarksButton.accessibilityLabel = NSLocalizedString("Show Bookmarks", comment: "Button to show the bookmarks list")

        historyButton.setImage(UIImage(named: "history"), forState: .Normal)
        historyButton.addTarget(self, action: "showHistory", forControlEvents: .TouchUpInside)
        historyButton.accessibilityLabel = NSLocalizedString("Show History", comment: "Button to show the history list")

        addBookmarkButton.addTarget(self, action: NSSelectorFromString(SEL_onClickBookmarksButton), forControlEvents: .TouchUpInside)
        addBookmarkButton.setImage(UIImage(named: "bookmark"), forState: .Normal)
        addBookmarkButton.setImage(UIImage(named: "bookmarkMarked"), forState: .Selected)
        addBookmarkButton.accessibilityLabel = NSLocalizedString("Add Bookmark", comment: "Button to add a bookmark")

        settingsButton.tintColor = BraveUX.ActionButtonTintColor
        bookmarksButton.tintColor = BraveUX.ActionButtonTintColor
        historyButton.tintColor = BraveUX.ActionButtonTintColor
        addBookmarkButton.tintColor = BraveUX.ActionButtonTintColor

        containerView.addSubview(history.view)
        containerView.addSubview(bookmarks.view)

        showBookmarks()

        bookmarks.view.hidden = false

        containerView.bringSubviewToFront(topButtonsView)

        if BraveUX.PanelShadowWidth > 0 {
            containerView.addSubview(shadow)
        }
    }

    let SEL_onClickSettingsButton = "onClickSettingsButton"
    func onClickSettingsButton() {
        if getApp().profile == nil {
            return
        }
        
        let settingsTableViewController = BraveSettingsView(style: .Grouped)
        settingsTableViewController.profile = getApp().profile

        let controller = SettingsNavigationController(rootViewController: settingsTableViewController)
        ///controller.popoverDelegate = self
        controller.modalPresentationStyle = UIModalPresentationStyle.FormSheet
        presentViewController(controller, animated: true, completion: nil)
    }

    let SEL_onClickBookmarksButton = "onClickBookmarksButton"
    func onClickBookmarksButton() {
        guard let tab = browser?.tabManager.selectedTab,
            let url = tab.displayURL?.absoluteString else {
                return
        }

        if addBookmarkButton.selected {
            browser?.removeBookmark(url)
        } else {
            browser?.addBookmark(url, title: tab.title)
        }

        showBookmarks()

        delay(0.1) {
            self.bookmarks.reloadData()
        }
    }

    override func setupConstraints() {
        topButtonsView.snp_remakeConstraints {
            make in
            make.top.equalTo(containerView).offset(spaceForStatusBar())
            make.left.right.equalTo(containerView)
            make.height.equalTo(44.0)
        }

        func common(make: ConstraintMaker) {
            make.bottom.equalTo(self.topButtonsView)
            make.height.equalTo(UIConstants.ToolbarHeight)
        }

        settingsButton.snp_remakeConstraints {
            make in
            common(make)
            make.centerX.equalTo(self.topButtonsView).multipliedBy(0.25)
        }

        divider.snp_remakeConstraints {
            make in
            make.bottom.equalTo(self.topButtonsView).inset(8.0)
            make.height.equalTo(UIConstants.ToolbarHeight - 18.0)
            make.width.equalTo(2.0)
            make.centerX.equalTo(self.topButtonsView).multipliedBy(0.5)
        }

        historyButton.snp_remakeConstraints {
            make in
            make.bottom.equalTo(self.topButtonsView)
            make.height.equalTo(UIConstants.ToolbarHeight)
            make.centerX.equalTo(self.topButtonsView).multipliedBy(0.75)
        }

        bookmarksButton.snp_remakeConstraints {
            make in
            make.bottom.equalTo(self.topButtonsView)
            make.height.equalTo(UIConstants.ToolbarHeight)
            make.centerX.equalTo(self.topButtonsView).multipliedBy(1.25)
        }

        addBookmarkButton.snp_remakeConstraints {
            make in
            make.bottom.equalTo(self.topButtonsView)
            make.height.equalTo(UIConstants.ToolbarHeight)
            make.centerX.equalTo(self.topButtonsView).multipliedBy(1.75)
        }

        tabTitleViewContainer.snp_remakeConstraints {
            make in
            make.right.left.equalTo(containerView)
            make.top.equalTo(topButtonsView.snp_bottom)
            make.height.equalTo(44.0)
        }

        tabTitleView.snp_remakeConstraints {
            make in
            make.right.top.bottom.equalTo(tabTitleViewContainer)
            make.left.lessThanOrEqualTo(containerView).inset(24)
        }

        bookmarks.view.snp_remakeConstraints { make in
            make.left.right.bottom.equalTo(containerView)
            make.top.equalTo(tabTitleView.snp_bottom)
        }

        history.view.snp_remakeConstraints { make in
            make.left.right.bottom.equalTo(containerView)
            make.top.equalTo(tabTitleView.snp_bottom)
        }

        if BraveUX.PanelShadowWidth > 0 {
            shadow.snp_remakeConstraints { make in
                make.right.top.bottom.equalTo(containerView)
                make.width.equalTo(BraveUX.PanelShadowWidth)
            }
        }
    }

    func showBookmarks() {
        tabTitleView.text = "Bookmarks"
        history.view.hidden = true
        bookmarks.view.hidden = false
        moveTabIndicator(bookmarksButton)
    }

    func showHistory() {
        tabTitleView.text = "History"
        bookmarks.view.hidden = true
        history.view.hidden = false
        moveTabIndicator(historyButton)
    }

    func moveTabIndicator(button: UIButton) {
        triangleView.snp_remakeConstraints {
            make in
            make.width.equalTo(button)
            make.height.equalTo(6)
            make.left.equalTo(button)
            make.top.equalTo(button.snp_bottom)
        }
    }

    override func setHomePanelDelegate(delegate: HomePanelDelegate?) {
        bookmarks.homePanelDelegate = delegate
        history.homePanelDelegate = delegate
        if (delegate != nil) {
            bookmarks.reloadData()
            history.reloadData()
        }
    }

    var loc = CGFloat(-1)
    func onTouchToHide(touchPoint: CGPoint, phase: UITouchPhase) {
        if view.hidden {
            return
        }

        let isFullWidth = fabs(view.frame.width - CGFloat(BraveUX.WidthOfSlideOut)) < 0.5
        
        func complete() {
            if isFullWidth {
                loc = CGFloat(-1)
                return
            }
            
            let shouldShow = view.frame.width / CGFloat(BraveUX.WidthOfSlideOut) > CGFloat(BraveUX.PanelClosingThresholdWhenDragging)
            if shouldShow {
                showPanel(true)
            } else {
                setHomePanelDelegate(nil)
                showPanel(false)
            }
        }
        
        let isOnEdge = fabs(touchPoint.x - view.frame.width) < 10
        if !isOnEdge && loc < 0 && phase != .Began {
            return
        }
        
        switch phase {
        case .Began:  // A finger touched the screen
            loc = isOnEdge ? touchPoint.x : CGFloat(-1)
            break
        case .Moved, .Stationary:
            if loc < 0 || touchPoint.x > loc {
                complete()
                return
            }
            
            view.snp_remakeConstraints {
                make in
                make.bottom.left.top.equalTo(self.view.superview!)
                make.width.equalTo(CGFloat(BraveUX.WidthOfSlideOut) - (loc - touchPoint.x))
            }
            self.view.layoutIfNeeded()
            break
        case .Ended, .Cancelled:
            complete()
            break
        }
    }

    func updateBookmarkStatus(isBookmarked: Bool) {
        addBookmarkButton.selected = isBookmarked
    }
}


