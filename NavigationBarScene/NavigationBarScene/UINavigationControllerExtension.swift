//
//  UINavigationControllerExtension.swift
//  MiniUiFramework
//
//  Created by lake on 2024/9/2.
//

import SwiftUI
import UIKit

import UIKit

public extension UIColor {
    // System default bar tint color
    class var defaultNavBarTintColor: UIColor {
        return UIColor(red: 244/255.0, green: 137/255.0, blue: 50/255.0, alpha: 1.0)
    }
}

//
//// 标题默认样式
let defaultAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)]
////
extension DispatchQueue {
    private static var onceTracker = [String]()

    public class func once(token: String, block: () -> Void) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if onceTracker.contains(token) {
            return
        }

        onceTracker.append(token)
        block()
    }
}

//
////
extension UINavigationController: UIGestureRecognizerDelegate {
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        return topViewController?.preferredStatusBarStyle ?? .default
    }

    override open var childForStatusBarHidden: UIViewController? {
        return topViewController
    }

    override open var childForStatusBarStyle: UIViewController? {
        return topViewController
    }

    override open func viewDidLoad() {
        UINavigationController.swizzle()
        super.viewDidLoad()
        let popGesture = interactivePopGestureRecognizer
        let popTarget = popGesture?.delegate
        let popView = popGesture!.view!
        popGesture?.isEnabled = false

        let popSelector = NSSelectorFromString("handleNavigationTransition:")
        let fullScreenPoGesture = UIPanGestureRecognizer(target: popTarget, action: popSelector)
        fullScreenPoGesture.delegate = self

        popView.addGestureRecognizer(fullScreenPoGesture)
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if viewControllers.count > 1 {
            return true
        }
        return false
    }

    private static let onceToken = UUID().uuidString

    class func swizzle() {
//        guard self == UINavigationController.self else { return }
        DispatchQueue.once(token: onceToken) {
            let needSwizzleSelectorArr = [
                NSSelectorFromString("_updateInteractiveTransition:"), // 系统左右切换动画方法
                #selector(popToViewController),
                #selector(pushViewController),
                #selector(popToRootViewController)
            ]

            for selector in needSwizzleSelectorArr {
                let str = ("et_" + selector.description).replacingOccurrences(of: "__", with: "_")

                let originalMethod = class_getInstanceMethod(self, selector) // 原方法
                let swizzledMethod = class_getInstanceMethod(self, Selector(str)) // 自定义方法
                if originalMethod != nil, swizzledMethod != nil {
                    method_exchangeImplementations(originalMethod!, swizzledMethod!) // 交换
                }
            }
        }
    }

    @objc func et_updateInteractiveTransition(_ percentComplete: CGFloat) { // 导航左右切换过程
        guard let topViewController = topViewController, let coordinator = topViewController.transitionCoordinator else {
            et_updateInteractiveTransition(percentComplete)
            return
        }

        let fromViewController = coordinator.viewController(forKey: .from)
        let toViewController = coordinator.viewController(forKey: .to)
        // Bg Alpha
        let fromAlpha = objc_getAssociatedObject(fromViewController!, &UIViewController.navBarBgAlphaKey) as? CGFloat ?? 1.0
        let toAlpha = objc_getAssociatedObject(toViewController!, &UIViewController.navBarBgAlphaKey) as? CGFloat ?? 1.0
        let newAlpha = fromAlpha + (toAlpha - fromAlpha) * percentComplete
        print("update from:\(fromAlpha) to:\(toAlpha) newAlpha:\(newAlpha)")
        setNeedsNavigationBackground(alpha: newAlpha)

        // Tint Color
//        let fromColor = objc_getAssociatedObject(fromViewController!, &nameKeys.navBarTintColor) as? UIColor ?? .black
//        let toColor = objc_getAssociatedObject(toViewController!, &nameKeys.navBarTintColor) as? UIColor ?? .black
//        let newColor = averageColor(fromColor: fromColor, toColor: toColor, percent: percentComplete)
//        navigationBar.tintColor = newColor
//        navigationBar.titleTextAttributes = topViewController.titleTextAttributes
        et_updateInteractiveTransition(percentComplete)
        coordinator.notifyWhenInteractionChanges { [weak self] context in
            if !context.isCancelled {
                self?.dealInteractionChanges(context)
            }
        }
    }

    // Calculate the middle Color with translation percent
    private func averageColor(fromColor: UIColor, toColor: UIColor, percent: CGFloat) -> UIColor {
        var fromRed: CGFloat = 0
        var fromGreen: CGFloat = 0
        var fromBlue: CGFloat = 0
        var fromAlpha: CGFloat = 0
        fromColor.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)

        var toRed: CGFloat = 0
        var toGreen: CGFloat = 0
        var toBlue: CGFloat = 0
        var toAlpha: CGFloat = 0
        toColor.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)

        let nowRed = fromRed + (toRed - fromRed) * percent
        let nowGreen = fromGreen + (toGreen - fromGreen) * percent
        let nowBlue = fromBlue + (toBlue - fromBlue) * percent
        let nowAlpha = fromAlpha + (toAlpha - fromAlpha) * percent

        return UIColor(red: nowRed, green: nowGreen, blue: nowBlue, alpha: nowAlpha)
    }

    @objc func et_popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        print("导航返回\(viewController.navigationItem.hashValue)")
        setNeedsNavigationBackground(alpha: viewController.navBarBgAlpha)
//        navigationBar.tintColor = viewController.navBarTintColor
//        navigationBar.titleTextAttributes = viewController.titleTextAttributes
        return et_popToViewController(topViewController!, animated: animated)
    }

    @objc func et_pushViewController(_ viewController: UIViewController, animated: Bool) {
        print("导航进入\(viewController.description)")
        et_pushViewController(viewController, animated: animated)
    }

    @objc func et_popToRootViewControllerAnimated(_ animated: Bool) -> [UIViewController]? {
        setNeedsNavigationBackground(alpha: viewControllers.first?.navBarBgAlpha ?? 0)
//        navigationBar.tintColor = viewControllers.first?.navBarTintColor
//        navigationBar.titleTextAttributes = viewControllers.first?.titleTextAttributes
        return et_popToRootViewControllerAnimated(animated)
    }

    fileprivate func setNeedsNavigationBackground(alpha: CGFloat, bar: UINavigationBar? = nil) {
        if !navigationBar.isTranslucent {
            return
        }
        guard let barBackgroundView = (bar ?? navigationBar).subviews.first else { return }

        barBackgroundView.subviews.filter { $0.isKind(of: UIVisualEffectView.self) }.forEach { $0.alpha = alpha }
        barBackgroundView.subviews.filter { $0.isKind(of: UIVisualEffectView.self) }.first?.isHidden = alpha == 0

        guard let backgroundEffectView = barBackgroundView.subviews.first as? UIVisualEffectView else { return }
        if navigationBar.backgroundImage(for: .default) == nil {
            backgroundEffectView.subviews[0].alpha = alpha
            return
        }

        barBackgroundView.alpha = alpha
    }
}

struct HookView: UIViewControllerRepresentable {
    typealias UIViewControllerType = Controller
    let onViewDidAppear: ((UIViewController) -> Void)?
    let onViewDidLayoutSubviews: ((UIViewController) -> Void)?
    let onViewWillAppear: ((UIViewController) -> Void)?
    func makeUIViewController(context: Context) -> Controller {
        let vc = Controller()
        vc.onViewDidAppear = onViewDidAppear
        vc.onViewDidLayoutSubviews = onViewDidLayoutSubviews
        vc.onViewWillAppear = onViewWillAppear
        return vc
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    class Controller: UIViewController {
        var onViewDidAppear: ((UIViewController) -> Void)?
        var onViewWillAppear: ((UIViewController) -> Void)?
        var onViewDidLayoutSubviews: ((UIViewController) -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let coordinator = transitionCoordinator else {
                return
            }

            let fromViewController = coordinator.viewController(forKey: .from)
            let toViewController = coordinator.viewController(forKey: .to)

            print("viewDidAppear", fromViewController?.description, toViewController?.description, fromViewController?.hid, toViewController?.hid)
            onViewDidAppear?(self)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            onViewWillAppear?(self)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            onViewDidLayoutSubviews?(self)
        }
    }
}

struct VCHookViewModifier: ViewModifier {
    var onViewDidAppear: ((UIViewController) -> Void)? = nil
    var onViewWillAppear: ((UIViewController) -> Void)? = nil
    var onViewDidLayoutSubviews: ((UIViewController) -> Void)? = nil
    func body(content: Content) -> some View {
        content
            .background(HookView(onViewDidAppear: onViewDidAppear, onViewDidLayoutSubviews: onViewDidLayoutSubviews, onViewWillAppear: onViewWillAppear))
    }
}

extension View {
    func onViewWillAppear(perform onViewWillAppear: @escaping ((UIViewController) -> Void)) -> some View {
        modifier(VCHookViewModifier(onViewWillAppear: onViewWillAppear))
    }

    func onViewDidAppear(perform onViewDidAppear: @escaping ((UIViewController) -> Void)) -> some View {
        modifier(VCHookViewModifier(onViewDidAppear: onViewDidAppear))
    }

    func onViewDidLayoutSubviews(perform onViewDidLayoutSubviews: @escaping ((UIViewController) -> Void)) -> some View {
        modifier(VCHookViewModifier(onViewDidLayoutSubviews: onViewDidLayoutSubviews))
    }
}

//
extension UINavigationController: UINavigationBarDelegate {
    public func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
//        navigationBar.titleTextAttributes = topViewController?.titleTextAttributes
        if let topVC = topViewController, let coor = topVC.transitionCoordinator, coor.initiallyInteractive {
            coor.notifyWhenInteractionChanges { context in
                self.dealInteractionChanges(context)
            }
            return true
        }

        let itemCount = navigationBar.items?.count ?? 0
        let n = viewControllers.count >= itemCount ? 1 : 0
        let popToVC = viewControllers[n]
        popToViewController(popToVC, animated: true)
        return true
    }

//    public func navigationBar(_ navigationBar: UINavigationBar, shouldPush item: UINavigationItem) -> Bool {
    ////        print("导航前进\(item.hashValue)")
    ////        navigationBar.alpha = topViewController?.navBarBgAlpha ?? 0
    ////        setNeedsNavigationBackground(alpha: topViewController?.navBarBgAlpha ?? 0)
    ////        navigationBar.tintColor = topViewController?.navBarTintColor
    ////        navigationBar.titleTextAttributes = topViewController?.titleTextAttributes
//        return true
//    }

    private func dealInteractionChanges(_ context: UIViewControllerTransitionCoordinatorContext) {
        let animations: (UITransitionContextViewControllerKey) -> Void = {
            let nowAlpha = context.viewController(forKey: $0)?.navBarBgAlpha ?? 0
            self.setNeedsNavigationBackground(alpha: nowAlpha)
//            self.navigationBar.titleTextAttributes = context.viewController(forKey: $0)?.titleTextAttributes
//            self.navigationBar.tintColor = context.viewController(forKey: $0)?.navBarTintColor
        }

        if context.isCancelled { // 手势失败
            let cancelDuration: TimeInterval = context.transitionDuration * Double(context.percentComplete)

            UIView.animate(withDuration: cancelDuration) {
                animations(.from)
            }
        } else { // 手势成功
            let finishDuration: TimeInterval = context.transitionDuration * Double(1 - context.percentComplete)

            UIView.animate(withDuration: finishDuration) {
                animations(.to)
            }
        }
    }
}

public extension UIViewController {
    static var navBarBgAlphaKey: Void?
    var hid: Int {
        hashValue
    }

    /** 导航栏背景透明度**/
    var navBarBgAlpha: CGFloat {
        get {
            guard let alpha = objc_getAssociatedObject(navigationController!, &UIViewController.navBarBgAlphaKey) as? CGFloat else {
                return 1.0
            }
            return alpha
        }
        set {
            let alpha = max(min(newValue, 1), 0) // 必须在 0~1的范围
            objc_setAssociatedObject(navigationController!, &UIViewController.navBarBgAlphaKey, alpha, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            // Update UI
            let navigationBar = navigationController?.view.superview?.superview?.superview?.subviews[1] as? UINavigationBar ?? navigationController?.navigationBar
            navigationController?.setNeedsNavigationBackground(alpha: alpha, bar: navigationBar)
//            print("set alpha:\(alpha) \(navigationBar)")
//            guard let coordinator = navigationController?.topViewController?.transitionCoordinator else {
            ////                et_updateInteractiveTransition(percentComplete)
//                return
//            }
//            print("获取\(objc_getAssociatedObject(navigationController, &nameKeys.navBarBgAlpha) as? CGFloat)")
//
//            let fromViewController = coordinator.viewController(forKey: .from)
//            let toViewController = coordinator.viewController(forKey: .to)
//            print("获取from \(fromViewController?.navBarBgAlpha)")
//            print("获取to \(toViewController?.navBarBgAlpha)")
//            objc_setAssociatedObject(toViewController, &nameKeys.navBarBgAlpha, alpha, .OBJC_ASSOCIATION_COPY_NONATOMIC)
//            toViewController?.navBarBgAlpha = alpha
//            print(fromViewController?.navBarBgAlpha, toViewController?.navBarBgAlpha)
        }
    }

    /** barTintColor颜色**/
//    var navBarTintColor: UIColor {
//        get {
//            guard let tintColor = objc_getAssociatedObject(self, &nameKeys.navBarTintColor) as? UIColor else {
//                return UIColor.link
//            }
//            return tintColor
//        }
//        set {
//            navigationController?.navigationBar.tintColor = newValue
//            objc_setAssociatedObject(self, &nameKeys.navBarTintColor, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
//        }
//    }
//
//    /**title样式**/
//    var titleTextAttributes: [NSAttributedString.Key: Any] {
//        get {
//            guard let attribute = objc_getAssociatedObject(self, &nameKeys.titleTextAttributes) as? [NSAttributedString.Key: Any] else {
//                return defaultAttributes
//            }
//            return attribute
//        }
//        set {
//            navigationController?.navigationBar.titleTextAttributes = newValue
//            objc_setAssociatedObject(self, &nameKeys.titleTextAttributes, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
//        }
//    }
}

// import UIKit
//
//// MARK: - Public
//
// public enum WXBNavigationBar {
//    /// APP 启动时调用, 在 didFinishLaunchingWithOptions 方法中
////    public static let registerRuntime: Void = { // 使用静态属性以保证只调用一次(该属性是个方法)
////        UINavigationController.navLoad
////        UIViewController.vcLoad
////    }()
// }
//
// public extension UIViewController {
//    private var testesfw: CGFloat {
//        return 1
//    }
//
//    /// 导航栏透明度，默认 1
//    var wxb_navBarBackgroundAlpha: CGFloat {
//        get {
//            let alpha = objc_getAssociatedObject(self, &AssociatedKeys.wxb_navBarBackgroundAlpha) as? CGFloat
//            return alpha ?? 1
//        }
//        set {
//            objc_setAssociatedObject(self, &AssociatedKeys.wxb_navBarBackgroundAlpha, newValue, .OBJC_ASSOCIATION_ASSIGN)
//            navigationController?.navigationBar.updateNavBarBackgroundAlpha(newValue)
//            print("set value \(newValue)")
//        }
//    }
//
//    ///  是否禁止返回手势，默认 false
//    var wxb_interactivePopDisabled: Bool {
//        get {
//            return objc_getAssociatedObject(self, &AssociatedKeys.wxb_interactivePopDisabled) as? Bool ?? false
//        }
//        set {
//            objc_setAssociatedObject(self, &AssociatedKeys.wxb_interactivePopDisabled, newValue, .OBJC_ASSOCIATION_ASSIGN)
//        }
//    }
//
//    ///  是否隐藏导航栏，默认 false
//    var wxb_prefersNavigationBarHidden: Bool {
//        get {
//            return objc_getAssociatedObject(self, &AssociatedKeys.wxb_prefersNavigationBarHidden) as? Bool ?? false
//        }
//        set {
//            objc_setAssociatedObject(self, &AssociatedKeys.wxb_prefersNavigationBarHidden, newValue, .OBJC_ASSOCIATION_ASSIGN)
//        }
//    }
// }
//
//// MARK: - Private
//
// private let popDuration = 0.35
// private var popDisplayCount = 0
// private let pushDuration = 0.35
// private var pushDisplayCount = 0
//
// private typealias _WXBViewControllerWillAppearInjectBlock = (UIViewController, Bool) -> Void
//
// private enum AssociatedKeys {
//    static var wxb_willAppearInjectBlock = "wxb_willAppearInjectBlock"
//    static var wxb_viewControllerBasedNavigationBarAppearanceEnabled = "wxb_vcbasenavbarae"
//    static var wxb_popGestureRecognizerDelegate = "wxb_popGestureRecognizerDelegate"
//    static var wxb_fullscreenPopGestureRecognizer = "wxb_fullscreenPopGestureRecognizer"
//
//    static var wxb_navBarBackgroundAlpha = "wxb_navBarBackgroundAlpha"
//    static var wxb_interactivePopDisabled = "wxb_interactivePopDisabled"
//    static var wxb_prefersNavigationBarHidden = "wxb_prefersNavigationBarHidden"
// }
//
// private extension UINavigationBar {
//    func updateNavBarBackgroundAlpha(_ alpha: CGFloat) {
//        // 修正translucent为YES，此属性可能被隐式修改，在使用 setBackgroundImage:forBarMetrics: 方法时，如果 image 里的像素点没有 alpha 通道或者 alpha 全部等于 1 会使得 translucent 变为 NO 或者 nil。
////        isTranslucent = true
//        // shadowImage = alpha < 1 ? UIImage() : nil
//
//        guard let barBackgroundView = subviews.first else { return }
//        barBackgroundView.subviews.forEach { $0.alpha = alpha }
//        barBackgroundView.subviews.first?.isHidden = alpha == 0
//        barBackgroundView.alpha = alpha
//    }
// }
//
// public extension UIViewController {
//    // 使用静态属性以保证只调用一次(该属性是个方法)
////    static let vcLoad: Void = {
////        let needSwizzleSelectorArr = [
////            #selector(viewWillAppear(_:)),
////        ]
////
////        for selector in needSwizzleSelectorArr {
////            let str = ("wxb_" + selector.description)
////            if let originalMethod = class_getInstanceMethod(UIViewController.self, selector),
////               let swizzledMethod = class_getInstanceMethod(UIViewController.self, Selector(str))
////            {
////                method_exchangeImplementations(originalMethod, swizzledMethod)
////            }
////        }
////    }()
//
////    @objc func wxb_viewWillAppear(_ animated: Bool) {
////        wxb_viewWillAppear(animated)
////        navigationController?.wxb_setupViewControllerBasedNavigationBarAppearanceIfNeeded(self)
////        if wxb_willAppearInjectBlock != nil {
////            wxb_willAppearInjectBlock?(self, animated)
////        }
////    }
////
////    var wxb_willAppearInjectBlock: _WXBViewControllerWillAppearInjectBlock? {
////        get {
////            return objc_getAssociatedObject(self, &AssociatedKeys.wxb_willAppearInjectBlock) as? _WXBViewControllerWillAppearInjectBlock
////        }
////        set {
////            objc_setAssociatedObject(self, &AssociatedKeys.wxb_willAppearInjectBlock, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
////        }
////    }
// }
//
// public extension UINavigationController {
//
//    private static let onceToken = UUID().uuidString
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        DispatchQueue.once(token: UINavigationController.onceToken) {
//            let needSwizzleSelectorArr = [
//                NSSelectorFromString("_updateInteractiveTransition:"),
//                #selector(popViewController(animated:)),
//                #selector(popToViewController(_:animated:)),
//                #selector(popToRootViewController(animated:)),
//                #selector(pushViewController(_:animated:)),
//            ]
//
//            print("come in")
//            for selector in needSwizzleSelectorArr {
//                let str = ("wxb_" + selector.description).replacingOccurrences(of: "__", with: "_")
//                if let originalMethod = class_getInstanceMethod(UINavigationController.self, selector),
//                   let swizzledMethod = class_getInstanceMethod(UINavigationController.self, Selector(str))
//                {
//                    method_exchangeImplementations(originalMethod, swizzledMethod)
//                }
//            }
//        }
//    }
//
//    // 使用静态属性以保证只调用一次(该属性是个方法)
////    static let navLoad: Void = {
////        let needSwizzleSelectorArr = [
////            NSSelectorFromString("_updateInteractiveTransition:"),
////            #selector(popViewController(animated:)),
////            #selector(popToViewController(_:animated:)),
////            #selector(popToRootViewController(animated:)),
////            #selector(pushViewController(_:animated:)),
////        ]
////
////        print("come in")
////        for selector in needSwizzleSelectorArr {
////            let str = ("wxb_" + selector.description).replacingOccurrences(of: "__", with: "_")
////            if let originalMethod = class_getInstanceMethod(UINavigationController.self, selector),
////               let swizzledMethod = class_getInstanceMethod(UINavigationController.self, Selector(str))
////            {
////                method_exchangeImplementations(originalMethod, swizzledMethod)
////            }
////        }
////    }()
//
//    @objc func wxb_updateInteractiveTransition(_ percentComplete: CGFloat) {
//        // print(#function)
//        print(#function)
//        wxb_updateInteractiveTransition(percentComplete)
//        if topViewController != nil {
//            let coor = topViewController?.transitionCoordinator
//            if coor != nil {
//                // 随着滑动的过程设置导航栏透明度渐变
//                let fromAlpha = coor?.viewController(forKey: .from)?.wxb_navBarBackgroundAlpha ?? 1
//                let toAlpha = coor?.viewController(forKey: .to)?.wxb_navBarBackgroundAlpha ?? 1
//                let nowAlpha = fromAlpha + (toAlpha - fromAlpha) * percentComplete
//
//                print(fromAlpha, toAlpha)
//
//                navigationBar.updateNavBarBackgroundAlpha(nowAlpha)
//
//                coor?.notifyWhenInteractionChanges { [weak self] context in
//                    self?.dealInteractionChanges(context)
//                }
//            }
//        }
//    }
//
//    @objc func wxb_popViewControllerAnimated(_ animated: Bool) -> UIViewController? {
//        var displayLink: CADisplayLink? = CADisplayLink(target: self, selector: #selector(popNeedDisplay))
//        displayLink?.add(to: RunLoop.main, forMode: .common)
//        CATransaction.setCompletionBlock {
//            displayLink?.invalidate()
//            displayLink = nil
//            popDisplayCount = 0
//        }
//        CATransaction.setAnimationDuration(popDuration)
//        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
//        CATransaction.begin()
//        let vc = wxb_popViewControllerAnimated(animated)
//        CATransaction.commit()
//        return vc
//    }
//
//    @objc func wxb_popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
//        var displayLink: CADisplayLink? = CADisplayLink(target: self, selector: #selector(popNeedDisplay))
//        displayLink?.add(to: RunLoop.main, forMode: .common)
//        CATransaction.setCompletionBlock {
//            displayLink?.invalidate()
//            displayLink = nil
//            popDisplayCount = 0
//        }
//        CATransaction.setAnimationDuration(popDuration)
//        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
//        CATransaction.begin()
//        let vc = wxb_popToViewController(viewController, animated: animated)
//        CATransaction.commit()
//        return vc
//    }
//
//    @objc func wxb_popToRootViewControllerAnimated(_ animated: Bool) -> [UIViewController]? {
//        var displayLink: CADisplayLink? = CADisplayLink(target: self, selector: #selector(popNeedDisplay))
//        displayLink?.add(to: RunLoop.main, forMode: .common)
//        CATransaction.setCompletionBlock {
//            displayLink?.invalidate()
//            displayLink = nil
//            popDisplayCount = 0
//        }
//        CATransaction.setAnimationDuration(popDuration)
//        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
//        CATransaction.begin()
//        let vc = wxb_popToRootViewControllerAnimated(animated)
//        CATransaction.commit()
//        return vc
//    }
//
//    @objc func wxb_pushViewController(_ viewController: UIViewController, animated: Bool) {
//        // 处理系统分享打开Message没有标题和取消按钮
//        if let cls = NSClassFromString("MFMessageComposeViewController"), isKind(of: cls) {
//            wxb_pushViewController(viewController, animated: animated)
//            return
//        }
//        if let flag = interactivePopGestureRecognizer?.view?.gestureRecognizers?.contains(wxb_fullscreenPopGestureRecognizer),
//           flag == false
//        {
//            // Add our own gesture recognizer to where the onboard screen edge pan gesture recognizer is attached to.
//            interactivePopGestureRecognizer?.view?.addGestureRecognizer(wxb_fullscreenPopGestureRecognizer)
//
//            // Forward the gesture events to the private handler of the onboard gesture recognizer.
//            let internalTargets = interactivePopGestureRecognizer?.value(forKey: "targets") as? [NSObject]
//            let internalTarget = internalTargets?.first?.value(forKey: "target") as Any
//            let internalAction = NSSelectorFromString("handleNavigationTransition:")
//            wxb_fullscreenPopGestureRecognizer.delegate = wxb_popGestureRecognizerDelegate
//            wxb_fullscreenPopGestureRecognizer.addTarget(internalTarget, action: internalAction)
//
//            // Disable the onboard gesture recognizer.
//            interactivePopGestureRecognizer?.isEnabled = false
//        }
//
//        // Handle perferred navigation bar appearance.
//        // wxb_setupViewControllerBasedNavigationBarAppearanceIfNeeded(viewController)
//
//        var displayLink: CADisplayLink? = CADisplayLink(target: self, selector: #selector(pushNeedDisplay))
//        displayLink?.add(to: RunLoop.main, forMode: .common)
//        CATransaction.setCompletionBlock {
//            displayLink?.invalidate()
//            displayLink = nil
//            pushDisplayCount = 0
//        }
//        CATransaction.setAnimationDuration(pushDuration)
//        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
//        CATransaction.begin()
//        wxb_pushViewController(viewController, animated: animated)
//        CATransaction.commit()
//    }
//
//    func wxb_setupViewControllerBasedNavigationBarAppearanceIfNeeded(_ appearingViewController: UIViewController) {
//        if wxb_viewControllerBasedNavigationBarAppearanceEnabled == false {
//            return
//        }
//        let block: _WXBViewControllerWillAppearInjectBlock = { [weak self] vc, animated in
//            self?.setNavigationBarHidden(vc.wxb_prefersNavigationBarHidden, animated: animated)
//        }
//        // Setup will appear inject block to appearing view controller.
//        // Setup disappearing view controller as well, because not every view controller is added into
//        // stack by pushing, maybe by "-setViewControllers:".
////        appearingViewController.wxb_willAppearInjectBlock = block
////        let disappearingViewController = viewControllers.last
////        if disappearingViewController?.wxb_willAppearInjectBlock == nil {
////            disappearingViewController?.wxb_willAppearInjectBlock = block
////        }
//    }
// }
//
// private extension UINavigationController {
//    var wxb_viewControllerBasedNavigationBarAppearanceEnabled: Bool {
//        get {
//            if let isEnabled = objc_getAssociatedObject(self, &AssociatedKeys.wxb_viewControllerBasedNavigationBarAppearanceEnabled) as? Bool {
//                return isEnabled
//            }
//            objc_setAssociatedObject(self, &AssociatedKeys.wxb_viewControllerBasedNavigationBarAppearanceEnabled, true, .OBJC_ASSOCIATION_ASSIGN)
//            return true
//        }
//        set {
//            objc_setAssociatedObject(self, &AssociatedKeys.wxb_viewControllerBasedNavigationBarAppearanceEnabled, newValue, .OBJC_ASSOCIATION_ASSIGN)
//        }
//    }
//
//    var wxb_popGestureRecognizerDelegate: _WXBFullscreenPopGestureRecognizerDelegate {
//        var delegate = objc_getAssociatedObject(self, &AssociatedKeys.wxb_popGestureRecognizerDelegate) as? _WXBFullscreenPopGestureRecognizerDelegate
//        if delegate == nil {
//            delegate = _WXBFullscreenPopGestureRecognizerDelegate()
//            delegate?.navigationController = self
//            objc_setAssociatedObject(self, &AssociatedKeys.wxb_popGestureRecognizerDelegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
//        }
//        return delegate!
//    }
//
//    var wxb_fullscreenPopGestureRecognizer: UIPanGestureRecognizer {
//        var panGesture = objc_getAssociatedObject(self, &AssociatedKeys.wxb_fullscreenPopGestureRecognizer) as? UIPanGestureRecognizer
//        if panGesture == nil {
//            panGesture = UIPanGestureRecognizer()
//            panGesture?.maximumNumberOfTouches = 1
//            objc_setAssociatedObject(self, &AssociatedKeys.wxb_fullscreenPopGestureRecognizer, panGesture, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
//        }
//        return panGesture!
//    }
//
//    func dealInteractionChanges(_ context: UIViewControllerTransitionCoordinatorContext) {
//        // 自动取消了返回手势
//        if context.isCancelled {
//            let cancelDuration = context.transitionDuration * TimeInterval(context.percentComplete)
//            UIView.animate(withDuration: cancelDuration) { [weak self] in
//                let nowAlpha = context.viewController(forKey: .from)?.wxb_navBarBackgroundAlpha ?? 1
//                self?.navigationBar.updateNavBarBackgroundAlpha(nowAlpha)
//            }
//        }
//        // 自动完成了返回手势
//        else {
//            let finishDuration = context.transitionDuration * TimeInterval(1 - context.percentComplete)
//            UIView.animate(withDuration: finishDuration) { [weak self] in
//                let nowAlpha = context.viewController(forKey: .to)?.wxb_navBarBackgroundAlpha ?? 1
//                self?.navigationBar.updateNavBarBackgroundAlpha(nowAlpha)
//            }
//        }
//    }
//
//    @objc func popNeedDisplay() {
//        guard let coor = topViewController?.transitionCoordinator else {
//            return
//        }
//        popDisplayCount += 1
//        let progress = popProgress()
//        let fromAlpha = coor.viewController(forKey: .from)?.wxb_navBarBackgroundAlpha ?? 1
//        let toAlpha = coor.viewController(forKey: .to)?.wxb_navBarBackgroundAlpha ?? 1
//        let nowAlpha = fromAlpha + (toAlpha - fromAlpha) * progress
//        navigationBar.updateNavBarBackgroundAlpha(nowAlpha)
//    }
//
//    @objc func pushNeedDisplay() {
//        guard let coor = topViewController?.transitionCoordinator else {
//            return
//        }
//        pushDisplayCount += 1
//        let progress = pushProgress()
//        let fromAlpha = coor.viewController(forKey: .from)?.wxb_navBarBackgroundAlpha ?? 1
//        let toAlpha = coor.viewController(forKey: .to)?.wxb_navBarBackgroundAlpha ?? 1
//        print(fromAlpha, toAlpha)
//        let nowAlpha = fromAlpha + (toAlpha - fromAlpha) * progress
//        navigationBar.updateNavBarBackgroundAlpha(nowAlpha)
//    }
//
//    func popProgress() -> CGFloat {
//        let all = 90 * popDuration
//        let current = min(all, Double(popDisplayCount))
//        return CGFloat(current / all)
//    }
//
//    func pushProgress() -> CGFloat {
//        let all = 90 * pushDuration
//        let current = min(all, Double(pushDisplayCount))
//        return CGFloat(current / all)
//    }
// }
//
// private class _WXBFullscreenPopGestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
//    var navigationController: UINavigationController?
//
//    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
//        guard let nav = navigationController else {
//            return true
//        }
//        // Ignore when no view controller is pushed into the navigation stack.
//        if nav.viewControllers.count < 1 {
//            return false
//        }
//        // Disable when the active view controller doesn't allow interactive pop.
//        if let topVC = navigationController?.viewControllers.last, topVC.wxb_interactivePopDisabled {
//            return false
//        }
//        // Ignore pan gesture when the navigation controller is currently in transition.
//        if let flag = navigationController?.value(forKey: "_isTransitioning") as? Bool, flag {
//            return false
//        }
//        // Prevent calling the handler when the gesture begins in an opposite direction.
//        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
//            let translation = panGesture.translation(in: gestureRecognizer.view)
//            if translation.x <= 0 {
//                return false
//            }
//        }
//        return true
//    }
// }
