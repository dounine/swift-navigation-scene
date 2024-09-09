//
//  UIViewController+KMNavigationBar.swift
//  NavigationBarScene
//
//  Created by lake on 2024/9/9.
//

import UIKit

public extension UIViewController {
    var navigationBarHelper: KMNavigationBarHelper {
        if let helper: KMNavigationBarHelper = associatedObject(for: &UIViewController.barHelperKey) {
            return helper
        } else {
            let helper = KMNavigationBarHelper(viewController: self)
            setAssociatedObject(helper, forKey: &UIViewController.barHelperKey, policy: .retainNonatomic)
            return helper
        }
    }
    /// barHelperKey
    private static var barHelperKey: Void?
}

public class KMNavigationBarHelper: NSObject {

    public fileprivate(set) var option: KMNavigationBarOption = KMNavigationBarOption.default.option() //()
    fileprivate weak var viewController: UIViewController?
    fileprivate weak var navigationBar: UINavigationBar?
    required init(viewController: UIViewController) {
        print("转换")
        self.viewController = viewController
        self.navigationBar = viewController.navigationController?.navigationBar
        if let preference = viewController.navigationController?.preference.mutableCopy() as? KMNavigationBarOption {
            print("转换come in")
            self.option = preference
        }
        super.init()
    }

    public func performUpdate(_ update: ((KMNavigationBarOption) -> Void)? = nil) {
        guard let bar = self.navigationBar as? KMNavigationBar else {
            return
        }
        print("performUpdate")
        update?(option)
        bar.updateToOption(option)
    }
}
