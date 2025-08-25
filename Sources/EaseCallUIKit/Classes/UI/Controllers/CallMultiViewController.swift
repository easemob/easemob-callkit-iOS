//
//  CallMultiViewController.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 6/25/25.
//

import UIKit

@objc public enum CallRole: Int {
    case caller // 呼叫者
    case callee // 被呼叫者
}

open class CallMultiViewController: UIViewController {
    
    public lazy var background: UIImageView = {
        let imageView = UIImageView(frame: self.view.bounds)
        imageView.image = CallAppearance.backgroundImage
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    public lazy var navigationBar: CallNavigationBar = {
        createNavigationBar()
    }()
    
    @objc func createNavigationBar() -> CallNavigationBar {
        CallNavigationBar(showLeftItem: true,textAlignment: .left, rightImages: [UIImage(named: "person_add", in: .callBundle, with: nil)!]).backgroundColor(.clear)
    }
    
    public lazy var callView: MultiPersonCallView = {
        MultiPersonCallView(frame: CGRect(x: 0, y: NavigationHeight+23, width: ScreenWidth, height: ScreenHeight-NavigationHeight-54-96-20-23)).backgroundColor(.clear)
    }()
    
    public lazy var bottomView: MultiCallBottomView = {
        MultiCallBottomView(frame: CGRect(x: 0, y: ScreenHeight-218-BottomBarHeight, width: ScreenWidth, height: 218+BottomBarHeight), connected: self.connected).backgroundColor(.clear)
    }()
    
    private var connected: Bool {
        if self.role != .callee {
            return true
        } else {
            if let call = CallKitManager.shared.callInfo {
                switch call.state {
                case .ringing:
                    return false
                case .answering:
                    return true
                default:
                    break
                }
            }
        }
        return false
    }
    
    public private(set) var role: CallRole = .caller
    
    @objc public init(role: CallRole) {
        self.role = role
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
        self.groupDetail()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        let state = self.connected
        if state {
            self.addCallTimer()
        }
        self.view.addSubViews([self.background, self.navigationBar,self.bottomView,self.callView])
        self.bottomView.updateButtonSelectedStatus(selectedIndex: 3)
        self.callView.isHidden = !state
        // Do any additional setup after loading the view.
        self.setupNavigationState()
        if let groupId = CallKitManager.shared.callInfo?.groupId, !groupId.isEmpty {
            let groupName = CallKitManager.shared.callInfo?.groupName ?? groupId
            var avatarURL = CallKitManager.shared.callInfo?.groupAvatar ?? ""
            var showName = groupName
            if let chatGroup = ChatGroup(id: groupId) {
                if !chatGroup.groupName.isEmpty {
                    showName = chatGroup.groupName
                    if avatarURL.isEmpty {
                        avatarURL = chatGroup.groupAvatar
                    }
                }
            }
            self.navigationBar.avatarURL = avatarURL
            self.navigationBar.title = showName
        }
        self.navigationBar.clickClosure = { [weak self] in
            self?.navigationClick(type: $0, indexPath: $1)
        }
        self.bottomView.didTapButton = { [weak self] in
            self?.bottomClick(type: $0)
        }
        CallKitManager.shared.enableLocalVideo(false)
    }
    
    private func setupNavigationState() {
        if self.role != .callee {
            self.navigationBar.subtitle = "calling".call.localize
            self.addCallTimer()
        } else {
            if let call = CallKitManager.shared.callInfo {
                switch call.state {
                case .ringing:
                    self.navigationBar.subtitle = "invite_info_video".call.localize
                    if let callId = CallKitManager.shared.callInfo?.callId {
                        CallKitManager.shared.startRingTimer(callId: callId)
                    }
                case .answering:
                    self.navigationBar.subtitle = "Connecting".call.localize
                    self.addCallTimer()
                default:
                    break
                }
            }
        }
    }
    
    @objc open func addCallTimer() {
        if let call = CallKitManager.shared.callInfo {
            GlobalTimerManager.shared.registerListener(self, timerIdentify: "call-\(call.channelName)-answering-timer")
            GlobalTimerManager.shared.registerListener(CallKitManager.shared, timerIdentify: "call-\(call.channelName)-answering-timer")
        }
    }
    
    @objc open func navigationClick(type: ChatNavigationBarClickEvent,indexPath: IndexPath?) {
        switch type {
        case .back,.title,.subtitle: self.pop()
        case .rightItems: self.rightAction()
        default:
            break
        }
    }
    
    @objc open func bottomClick(type: CallButtonType) {
        
        switch type {
        case .mic_on:
            guard let currentUserId = ChatClient.shared().currentUsername,let item = CallKitManager.shared.itemsCache[currentUserId],let canvas = CallKitManager.shared.canvasCache[currentUserId] else {
                consoleLogInfo("CallMultiViewController: Current user not found in items cache.", type: .error)
                return
            }
            CallKitManager.shared.enableLocalAudio(true)
            item.audioMuted = false
            canvas.updateItem(item)
        case .mic_off:
            guard let currentUserId = ChatClient.shared().currentUsername,let item = CallKitManager.shared.itemsCache[currentUserId],let canvas = CallKitManager.shared.canvasCache[currentUserId] else {
                consoleLogInfo("CallMultiViewController: Current user not found in items cache.", type: .error)
                return
            }
            CallKitManager.shared.enableLocalAudio(false)
            item.audioMuted = true
            canvas.updateItem(item)
        case .flip_back: CallKitManager.shared.switchCamera()
        case .flip_front: CallKitManager.shared.switchCamera()
        case .camera_on:
            guard let currentUserId = ChatClient.shared().currentUsername,let item = CallKitManager.shared.itemsCache[currentUserId],let canvas = CallKitManager.shared.canvasCache[currentUserId] else {
                consoleLogInfo("CallMultiViewController: Current user not found in items cache.", type: .error)
                return
            }
            CallKitManager.shared.setupLocalVideo()
            CallKitManager.shared.enableLocalVideo(true)
            item.videoMuted = false
            canvas.updateItem(item)
        case .camera_off:
            guard let currentUserId = ChatClient.shared().currentUsername,let item = CallKitManager.shared.itemsCache[currentUserId],let canvas = CallKitManager.shared.canvasCache[currentUserId] else {
                consoleLogInfo("CallMultiViewController: Current user not found in items cache.", type: .error)
                return
            }
            CallKitManager.shared.enableLocalVideo(false)
            item.videoMuted = true
            canvas.updateItem(item)
        case .speaker_on:
            CallKitManager.shared.turnSpeakerOn(on: true)
        case .speaker_off:
            CallKitManager.shared.turnSpeakerOn(on: false)
        case .decline:
            CallKitManager.shared.callVC = nil
            self.dismiss(animated: true, completion: nil)
            CallKitManager.shared.hangup()
        case .accept:
            if let call = CallKitManager.shared.callInfo {
                GlobalTimerManager.shared.registerListener(self, timerIdentify: "call-\(call.channelName)-answering-timer")
                GlobalTimerManager.shared.registerListener(CallKitManager.shared, timerIdentify: "call-\(call.channelName)-answering-timer")
            }
            CallKitManager.shared.accept()
            self.callView.isHidden = false
        case .end:
            if let call = CallKitManager.shared.callInfo {
                GlobalTimerManager.shared.removeListener(self, timerIdentify: "call-\(call.channelName)-answering-timer")
            }
            CallKitManager.shared.hangup()
            self.dismiss(animated: true, completion: nil)
        default: break
        }
    }
    
    @objc open func pop() {
        if self.navigationController != nil {
            self.navigationController?.popViewController(animated: true)
        } else {
            if CallKitManager.shared.callVC == nil {
                self.dismiss(animated: false)
                CallKitManager.shared.showMiniAudioView(vc: self)
            } else {
                self.dismiss(animated: true)
            }
        }
    }

    @objc open func rightAction() {
        if let call = CallKitManager.shared.callInfo {
            if let groupId = call.groupId, !groupId.isEmpty {
                if CallKitManager.shared.canvasCache.count >= 16 {
                    CallKitManager.shared.handleError(ChatError(description: "group call members limit reached", code: .exceedServiceLimit))
                    self.showCallToast(toast: "group call members limit reached".call.localize)
                    return
                }
                CallKitManager.shared.groupCall(groupId: groupId)
            } else {
                CallKitManager.shared.handleError(ChatError(description: "Group ID is not available", code: .invalidParam))
                consoleLogInfo("CallMultiViewController: Group ID is not available.", type: .error)
            }
            
        } else {
            consoleLogInfo("CallMultiViewController: Call info is not available.", type: .error)
        }
        
    }
    
    open override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
    }
    
    deinit {
        consoleLogInfo("CallMultiViewController deinit", type: .info)
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        guard let touch = touches.first else { return }
        let point = touch.location(in: self.view)
        
        // 检查是否点击在 callView 内
        if self.callView.frame.contains(point) {
            // 将点转换为 callView 的坐标系
            let pointInCallView = touch.location(in: self.callView)
            
            // 检查是否点击在任何 CallStreamView 或 UIScrollView 上
            let isOnStreamViewOrScrollView = checkIfPointIsOnStreamViewOrScrollView(point: pointInCallView, in: self.callView)
            
            // 如果点击在 callView 上但不在 CallStreamView 或 UIScrollView 上
            if !isOnStreamViewOrScrollView {
                toggleNavigationAndBottomView()
            }
        } else if !self.bottomView.frame.contains(point) {
            // 点击在 callView 和 bottomView 之外的区域
            toggleNavigationAndBottomView()
        }
    }

    // 递归检查点是否在 CallStreamView 或 UIScrollView 上
    func checkIfPointIsOnStreamViewOrScrollView(point: CGPoint, in view: UIView) -> Bool {
        for subview in view.subviews {
            // 将点转换为子视图的坐标系
            let pointInSubview = view.convert(point, to: subview)
            
            // 检查点是否在子视图的范围内
            if subview.bounds.contains(pointInSubview) {
                // 如果是 CallStreamView 或 UIScrollView，返回 true
                if subview is CallStreamView || subview is UIScrollView {
                    return true
                }
                
                // 递归检查子视图
                if checkIfPointIsOnStreamViewOrScrollView(point: pointInSubview, in: subview) {
                    return true
                }
            }
        }
        return false
    }

    // 切换导航栏和底部视图的显示/隐藏
    func toggleNavigationAndBottomView() {
        UIView.animate(withDuration: 0.3) {
            if self.navigationBar.alpha == 0 {
                self.navigationBar.alpha = 1
                self.bottomView.alpha = 1
            } else {
                self.navigationBar.alpha = 0
                self.bottomView.alpha = 0
            }
        }
    }
    
    private func groupDetail() {
        if let groupId = CallKitManager.shared.callInfo?.groupId,let group = ChatGroup(id: groupId) {
            if Optional(group.groupName) == nil {
                ChatClient.shared().groupManager?.getGroupSpecificationFromServer(withId: groupId,completion: { group, error in
                    if let group = group {
                        self.navigationBar.title = group.groupName ?? groupId
                    } else {
                        self.showCallToast(toast: "request group detail failed!".call.localize)
                    }
                })
            } else {
                self.navigationBar.title = group.groupName ?? groupId
            }
        }
    }
}

extension CallMultiViewController: TimerServiceListener {
    public func timeChanged(_ timerIdentify: String, interval seconds: UInt) {
        
        if let call = CallKitManager.shared.callInfo, timerIdentify == "call-\(call.channelName)-answering-timer" {
            self.updateSeconds(seconds: Int(seconds))
        }
    }
    
    func updateSeconds(seconds: Int) {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        self.navigationBar.subtitle = String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}
