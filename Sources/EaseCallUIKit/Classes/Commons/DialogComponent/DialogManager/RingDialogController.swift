//
//  RingDialogController.swift
//  CallUIKit
//
//  Created by 朱继超 on 2023/9/6.
//

import UIKit
 /**
     A view controller that manages the presentation of a dialog container view and its content.
     - `presentedViewComponent`: An optional `PresentedViewComponent` object that represents the content view to be presented.
     - `customView`: An optional `UIView` object that represents a custom view to be presented.
     */
@objc final public class RingDialogController:  UIViewController, PresentedViewType {
    
    public private(set) var dismissClosure: ((RingAlertAction) -> Void)?
    
    public var presentedViewComponent: PresentedViewComponent? = PresentedViewComponent(contentSize: CGSize(width: ScreenWidth, height: NavigationHeight),destination: .topBaseline,dismissTransitionType: .crossZoom,canTapBGDismiss: false,canPanDismiss: false)

    public private(set) lazy var ringView: RingAlert = {
        RingAlert(frame: CGRect(x: 12, y: StatusBarHeight, width: ScreenWidth-24, height: 80))
    }()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    @objc public init(dismiss: ((RingAlertAction) -> Void)? = nil) {
        self.dismissClosure = dismiss
        super.init(nibName: nil, bundle: nil)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.ringView)
        self.ringView.actionClosure = { [weak self] in
            guard let `self` = self else { return }
            self.dismissClosure?($0)
            self.dismiss(animated: true, completion: nil)
        }

        
    }
    

}


