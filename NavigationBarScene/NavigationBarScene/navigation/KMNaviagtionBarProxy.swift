//
//  KMNaviagtionBarProxy.swift
//  NavigationBarScene
//
//  Created by lake on 2024/9/9.
//

import UIKit


public class KMNaviagtionBarProxy: NSObject {
    /// navigationController delegate
    public weak var delegate: UINavigationControllerDelegate?
    fileprivate weak var navigationController: UINavigationController?
    required init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
        self.navigationController?.delegate = self
    }
}

extension KMNaviagtionBarProxy: UINavigationControllerDelegate {
    // MARK: - Forwarding message call to UINavigationController.delegate if self (Proxy) don't respond
    override public func responds(to aSelector: Selector!) -> Bool {
        if #selector(KMNaviagtionBarProxy.navigationController(_:willShow:animated:)) == aSelector {
            return true
        } else {
            return self.delegate?.responds(to: aSelector) ?? false
        }
    }
    
    override public func forwardingTarget(for aSelector: Selector!) -> Any? {
        return self.delegate
    }
    
    // MARK: - UINavigationControllerDelegate
    @objc
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        navigationController.transitionHelper.transitionWillShow(viewController: viewController)
        /// call navigationController delegate
        self.delegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
    }
}
