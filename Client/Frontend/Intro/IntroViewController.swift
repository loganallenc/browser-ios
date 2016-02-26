/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import SnapKit

struct IntroViewControllerUX {
    static let Width = 375
    static let Height = 667

    static let CardSlides = ["page1", "page2", "page3", "page4", "page5"]
    static let NumberOfCards = CardSlides.count

    static let PagerCenterOffsetFromScrollViewBottom = 20

    static let StartBrowsingButtonTitle = NSLocalizedString("Start Browsing", tableName: "Intro", comment: "")
    static let StartBrowsingButtonColor = UIColor(rgb: 0x363B40)
    static let StartBrowsingButtonHeight = 120


    static let CardTextLineHeight = CGFloat(6)

    static let CardTitlePage1 = NSLocalizedString("Welcome to Brave.", tableName: "Intro", comment: "")
    static let CardTextPage1 = NSLocalizedString("Get ready to experience a Faster, Safer, Better Web.", tableName: "Intro", comment: "")

    static let CardTitlePage2 = NSLocalizedString("Brave is Faster,\nand here's why...", tableName: "Intro", comment: "")
    static let CardTextPage2 = NSLocalizedString("Brave blocks ads.\nBrave stops trackers.\nBrave is designed for speed and efficiency.", tableName: "Intro", comment: "")

    static let CardTitlePage3 = NSLocalizedString("Brave keeps you safe as you browse.", tableName: "Intro", comment: "")
    static let CardTextPage3 = NSLocalizedString("Browse with us and your privacy is protected, with nothing further to install, learn or configure.", tableName: "Intro", comment: "")

    static let CardTitlePage4 = NSLocalizedString("In case you hit a speed bump", tableName: "Intro", comment: "")
    static let CardTextPage4 = NSLocalizedString("Brave makes it easy to temporarily disable ad blocking and privacy features.\nTap the Brave button to toggle shields on or off.", tableName: "Intro", comment: "")

    static let CardTitlePage5 = NSLocalizedString("Ready?", tableName: "Intro", comment: "")
    static let CardTextPage5 = NSLocalizedString("", tableName: "Intro", comment: "")

    static let CardTextSyncOffsetFromCenter = 25
    static let Card3ButtonOffsetFromCenter = -10

    static let FadeDuration = 0.25

    static let BackForwardButtonEdgeInset = 20
}

let IntroViewControllerSeenProfileKey = "IntroViewControllerSeen"

protocol IntroViewControllerDelegate: class {
    func introViewControllerDidFinish(introViewController: IntroViewController)
    #if !BRAVE
    func introViewControllerDidRequestToLogin(introViewController: IntroViewController)
    #endif
}

class IntroViewController: UIViewController, UIScrollViewDelegate {
    weak var delegate: IntroViewControllerDelegate?

    var slides = [UIImage]()
    var cards = [UIImageView]()
    var introViews = [UIView]()
    var titleLabels = [InsetLabel]()
    var textLabels = [InsetLabel]()

    var startBrowsingButton: UIButton!
    var introView: UIView?
    var slideContainer: UIView!
    var pageControl: UIPageControl!
    var backButton: UIButton!
    var forwardButton: UIButton!

    var bgColors = [UIColor]()

    private var scrollView: IntroOverlayScrollView!

    var slideVerticalScaleFactor: CGFloat = 1.0

    var arrow: UIImageView?

    override func viewDidLoad() {
        view.backgroundColor = UIColor.whiteColor()

        bgColors.append(BraveUX.BraveButtonMessageInUrlBarColor)
        bgColors.append(UIColor(colorLiteralRed: 69/255.0, green: 155/255.0, blue: 255/255.0, alpha: 1.0))
        bgColors.append(UIColor(colorLiteralRed: 254/255.0, green: 202/255.0, blue: 102/255.0, alpha: 1.0))
        bgColors.append(BraveUX.BraveButtonMessageInUrlBarColor)
        bgColors.append(BraveUX.BraveButtonMessageInUrlBarColor)

        arrow = UIImageView(image: UIImage(named: "screen_5_arrow"))

        // scale the slides down for iPhone 4S
        if view.frame.height <=  480 {
            slideVerticalScaleFactor = 1.33
        }

        for slideName in IntroViewControllerUX.CardSlides {
            if let image = UIImage(named: slideName) {
                slides.append(image)
            }
        }

        startBrowsingButton = UIButton()
        startBrowsingButton.backgroundColor = IntroViewControllerUX.StartBrowsingButtonColor
        startBrowsingButton.setTitle(IntroViewControllerUX.StartBrowsingButtonTitle, forState: UIControlState.Normal)
        startBrowsingButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        startBrowsingButton.addTarget(self, action: "SELstartBrowsing", forControlEvents: UIControlEvents.TouchUpInside)
        startBrowsingButton.contentHorizontalAlignment = .Left
        startBrowsingButton.contentVerticalAlignment = .Top
        startBrowsingButton.contentEdgeInsets = UIEdgeInsetsMake(20, 20, 0, 0);

        view.addSubview(startBrowsingButton)
        startBrowsingButton.snp_makeConstraints { (make) -> Void in
            make.left.right.bottom.equalTo(self.view)
            make.height.equalTo(self.view.frame.width <= 320 ? 60 : IntroViewControllerUX.StartBrowsingButtonHeight)
        }

        scrollView = IntroOverlayScrollView()
        scrollView.backgroundColor = UIColor.clearColor()
        scrollView.accessibilityLabel = NSLocalizedString("Intro Tour Carousel", comment: "Accessibility label for the introduction tour carousel")
        scrollView.delegate = self
        scrollView.bounces = false
        scrollView.pagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentSize = CGSize(width: scaledWidthOfSlide * CGFloat(IntroViewControllerUX.NumberOfCards), height: scaledHeightOfSlide)
        view.addSubview(scrollView)

        slideContainer = UIView()
        slideContainer.backgroundColor = bgColors[0]
        var imageView: UIImageView? = nil
        for i in 0..<IntroViewControllerUX.NumberOfCards {
            imageView = UIImageView(frame: CGRect(x: CGFloat(i)*scaledWidthOfSlide, y: 0, width: scaledWidthOfSlide, height: scaledHeightOfSlide))
            imageView?.image = slides[i]
            if let imageView = imageView {
                slideContainer.addSubview(imageView)
            }
        }
        imageView?.alpha = 0.0

        scrollView.addSubview(slideContainer)
        scrollView.snp_makeConstraints { (make) -> Void in
            make.left.right.top.equalTo(self.view)
            make.bottom.equalTo(startBrowsingButton.snp_top)
        }

        pageControl = UIPageControl()
        pageControl.pageIndicatorTintColor = UIColor.blackColor().colorWithAlphaComponent(0.3)
        pageControl.currentPageIndicatorTintColor = UIColor.blackColor()
        pageControl.numberOfPages = IntroViewControllerUX.NumberOfCards
        pageControl.accessibilityIdentifier = "pageControl"
        pageControl.addTarget(self, action: Selector("changePage"), forControlEvents: UIControlEvents.ValueChanged)

        view.addSubview(pageControl)
        pageControl.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.scrollView).offset(20.0)
            make.centerY.equalTo(self.startBrowsingButton.snp_top).offset(-IntroViewControllerUX.PagerCenterOffsetFromScrollViewBottom)
        }


        func addCard(text: String, title: String) {
            let introView = UIView()
            self.introViews.append(introView)
            self.addLabelsToIntroView(introView, text: text, title: title)
        }

        addCard(IntroViewControllerUX.CardTextPage1, title: IntroViewControllerUX.CardTitlePage1)
        addCard(IntroViewControllerUX.CardTextPage2, title: IntroViewControllerUX.CardTitlePage2)
        addCard(IntroViewControllerUX.CardTextPage3, title: IntroViewControllerUX.CardTitlePage3)
        addCard(IntroViewControllerUX.CardTextPage4, title: IntroViewControllerUX.CardTitlePage4)
        addCard(IntroViewControllerUX.CardTextPage5, title: IntroViewControllerUX.CardTitlePage5)

        titleLabels.last?.textAlignment = .Center
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            titleLabels.last?.leftInset = self.view.frame.width <= 320 ? -20 : 20
        }
        // Add all the cards to the view, make them invisible with zero alpha

        for introView in introViews {
            introView.alpha = 0
            self.view.addSubview(introView)
            introView.snp_makeConstraints { (make) -> Void in
                make.top.equalTo(self.slideContainer.snp_bottom)
                make.bottom.equalTo(self.startBrowsingButton.snp_top)
                make.left.right.equalTo(self.view)
            }
        }

        // Make whole screen scrollable by bringing the scrollview to the top
        view.bringSubviewToFront(scrollView)
        view.bringSubviewToFront(pageControl)


        // Activate the first card
        setActiveIntroView(introViews[0], forPage: 0)

        setupDynamicFonts()
    }

    func setupTextOnButton() {
        startBrowsingButton.contentHorizontalAlignment = .Left
        startBrowsingButton.contentVerticalAlignment = .Top
        startBrowsingButton.contentEdgeInsets = UIEdgeInsetsMake(20, 20, 0, 0);
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "SELDynamicFontChanged:", name: NotificationDynamicFontChanged, object: nil)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NotificationDynamicFontChanged, object: nil)
    }

    func SELDynamicFontChanged(notification: NSNotification) {
        guard notification.name == NotificationDynamicFontChanged else { return }
        setupDynamicFonts()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        scrollView.snp_remakeConstraints { (make) -> Void in
            make.left.right.top.equalTo(self.view)
            make.bottom.equalTo(self.startBrowsingButton.snp_top)
        }

        for i in 0..<IntroViewControllerUX.NumberOfCards {
            if let imageView = slideContainer.subviews[i] as? UIImageView {
                imageView.frame = CGRect(x: CGFloat(i)*scaledWidthOfSlide, y: 0, width: scaledWidthOfSlide, height: scaledHeightOfSlide)
                imageView.contentMode = UIViewContentMode.ScaleAspectFit
            }
        }
        slideContainer.frame = CGRect(x: 0, y: 0, width: scaledWidthOfSlide * CGFloat(IntroViewControllerUX.NumberOfCards), height: scaledHeightOfSlide)
        scrollView.contentSize = CGSize(width: slideContainer.frame.width, height: slideContainer.frame.height)
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    override func shouldAutorotate() -> Bool {
        return false
    }

    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        // This actually does the right thing on iPad where the modally
        // presented version happily rotates with the iPad orientation.
        return UIInterfaceOrientationMask.Portrait
    }

    func SELstartBrowsing() {
        delegate?.introViewControllerDidFinish(self)
    }

    func SELback() {
        if introView == introViews[1] {
            setActiveIntroView(introViews[0], forPage: 0)
            scrollView.scrollRectToVisible(scrollView.subviews[0].frame, animated: true)
            pageControl.currentPage = 0
        } else if introView == introViews[2] {
            setActiveIntroView(introViews[1], forPage: 1)
            scrollView.scrollRectToVisible(scrollView.subviews[1].frame, animated: true)
            pageControl.currentPage = 1
        }
    }

    func SELforward() {
        if introView == introViews[0] {
            setActiveIntroView(introViews[1], forPage: 1)
            scrollView.scrollRectToVisible(scrollView.subviews[1].frame, animated: true)
            pageControl.currentPage = 1
        } else if introView == introViews[1] {
            setActiveIntroView(introViews[2], forPage: 2)
            scrollView.scrollRectToVisible(scrollView.subviews[2].frame, animated: true)
            pageControl.currentPage = 2
        }
    }

    func SELlogin() {
        #if !BRAVE
		delegate?.introViewControllerDidRequestToLogin(self)
        #endif
    }

    private var accessibilityScrollStatus: String {
        return String(format: NSLocalizedString("Introductory slide %@ of %@", tableName: "Intro", comment: "String spoken by assistive technology (like VoiceOver) stating on which page of the intro wizard we currently are. E.g. Introductory slide 1 of 3"), NSNumberFormatter.localizedStringFromNumber(pageControl.currentPage+1, numberStyle: .DecimalStyle), NSNumberFormatter.localizedStringFromNumber(IntroViewControllerUX.NumberOfCards, numberStyle: .DecimalStyle))
    }

    func changePage() {
        let swipeCoordinate = CGFloat(pageControl.currentPage) * scrollView.frame.size.width
        scrollView.setContentOffset(CGPointMake(swipeCoordinate, 0), animated: true)
    }

    func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        // Need to add this method so that tapping the pageControl will also change the card texts. 
        // scrollViewDidEndDecelerating waits until the end of the animation to calculate what card it's on.
        scrollViewDidEndDecelerating(scrollView)
    }

    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.x / scrollView.frame.size.width)
        pageControl.currentPage = page
        if page < introViews.count {
            setActiveIntroView(introViews[page], forPage: page)
        }
    }

    var lionHead: UIImageView?
    private func setActiveIntroView(newIntroView: UIView, forPage page: Int) {
        if introView != newIntroView {
            UIView.animateWithDuration(IntroViewControllerUX.FadeDuration, animations: { () -> Void in
                self.introView?.alpha = 0
                self.introView = newIntroView
                newIntroView.alpha = 1.0
            }, completion: { _ in
                        })
        }

        if page < bgColors.count {
            slideContainer.backgroundColor = bgColors[page]
        }

        if page == bgColors.count - 1 {
            startBrowsingButton.contentHorizontalAlignment = .Center
            startBrowsingButton.contentVerticalAlignment = .Center
            startBrowsingButton.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0)

            if lionHead == nil {
                lionHead = UIImageView(image: UIImage(named: "lionhead"))
            }
            self.view.addSubview(lionHead!)
            lionHead!.snp_remakeConstraints {
                make in
                make.centerX.equalTo(self.view)
                make.centerY.equalTo(introView!.snp_top)
            }
//            delay(0) {
//                UIView.animateWithDuration(0.2) {
//                    if let v = self.slideContainer.subviews.last {
//                        v.alpha = 10
//                        v.transform = CGAffineTransformMakeTranslation(0, 40)
//                    }
//                }
//            }
            guard let arrow = arrow else { return }
            pageControl.superview?.addSubview(arrow)
            arrow.alpha = 0
            arrow.snp_remakeConstraints {
                make in
                make.bottom.equalTo(pageControl).inset(15)
                make.centerX.equalTo(arrow.superview!)
            }

            UIView.animateWithDuration(0.2) {
                self.arrow?.alpha = 1.0
                self.pageControl.alpha = 0
            }
        } else {
            if lionHead?.superview != nil {
                lionHead?.removeFromSuperview()
            }

            setupTextOnButton()
            if let v = self.slideContainer.subviews.last {
                v.alpha = 0
                v.transform = CGAffineTransformMakeTranslation(0, 0)
            }
            arrow?.alpha = 0
            pageControl.alpha = 1
        }
    }

    private var scaledWidthOfSlide: CGFloat {
        return view.frame.width
    }

    private var scaledHeightOfSlide: CGFloat {
        return (view.frame.width / slides[0].size.width) * slides[0].size.height / slideVerticalScaleFactor
    }

    private func attributedStringForLabel(text: String) -> NSMutableAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = IntroViewControllerUX.CardTextLineHeight
        paragraphStyle.alignment = .Center

        let string = NSMutableAttributedString(string: text)
        string.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSMakeRange(0, string.length))
        return string
    }

    private func addLabelsToIntroView(introView: UIView, text: String, title: String = "") {
        let label = InsetLabel()

        label.numberOfLines = 0
        label.attributedText = attributedStringForLabel(text)
        label.textAlignment = .Left
        textLabels.append(label)

        addViewsToIntroView(introView, label: label, title: title)
    }

    private func addViewsToIntroView(introView: UIView, label: UIView, title: String = "") {
        introView.addSubview(label)
        label.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(introView)
            make.left.equalTo(introView).offset(20)
            make.width.equalTo(self.view.frame.width <= 320 ? 260 : 300) // TODO Talk to UX about small screen sizes
        }

        if !title.isEmpty {
            let titleLabel = InsetLabel()
            if (title == IntroViewControllerUX.CardTitlePage1) {
                titleLabel.textColor = BraveUX.BraveButtonMessageInUrlBarColor
            } else if (title == IntroViewControllerUX.CardTitlePage5) {
                titleLabel.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(1.2, 1.2), CGAffineTransformMakeTranslation(30, 20))
            }
            titleLabel.numberOfLines = 0
            titleLabel.textAlignment = NSTextAlignment.Left
            titleLabel.lineBreakMode = .ByWordWrapping
            titleLabel.text = title
            titleLabels.append(titleLabel)
            introView.addSubview(titleLabel)
            titleLabel.snp_makeConstraints { (make) -> Void in
                make.top.equalTo(introView)
                make.bottom.equalTo(label.snp_top)
                make.left.equalTo(titleLabel.superview!).offset(20)
                make.width.equalTo(self.view.frame.width <= 320 ? 260 : 300) // TODO Talk to UX about small screen sizes
            }
        }

    }

    private func setupDynamicFonts() {
        let biggerIt = self.view.frame.width <= 320 ? CGFloat(0) : CGFloat(3)
        startBrowsingButton.titleLabel?.font = UIFont.systemFontOfSize(DynamicFontHelper.defaultHelper.IntroBigFontSize)


        for titleLabel in titleLabels {
            titleLabel.font = UIFont.systemFontOfSize(DynamicFontHelper.defaultHelper.IntroBigFontSize + biggerIt, weight: UIFontWeightBold)
        }

        for label in textLabels {
            label.font = UIFont.systemFontOfSize(DynamicFontHelper.defaultHelper.IntroStandardFontSize + biggerIt)
        }
    }
}

private class IntroOverlayScrollView: UIScrollView {
    weak var signinButton: UIButton?

    private override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
        if let signinFrame = signinButton?.frame {
            let convertedFrame = convertRect(signinFrame, fromView: signinButton?.superview)
            if CGRectContainsPoint(convertedFrame, point) {
                return false
            }
        }

        return CGRectContainsPoint(CGRect(origin: self.frame.origin, size: CGSize(width: self.contentSize.width, height: self.frame.size.height)), point)
    }
}

extension UIColor {
    var components:(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r,g,b,a)
    }
}
