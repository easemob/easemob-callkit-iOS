//
//  CallKitManager.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 6/24/25.
//

import Foundation
import AgoraRtcKit
import AVKit
import AVFAudio

public let CallKitVersion = "1.0.0"

@objcMembers public class CallKitManager: NSObject {
    /// Cache for user profiles
    public var usersCache: [String: CallUserProfile] = [:]
    
    /// CallKitManager shared instance
    public static let shared = CallKitManager()
    
    /// Provider for user profiles
    public var profileProvider: CallUserProfileProvider?
    
    /// Provider for user profiles in Objective-C
    public var profileProviderOC: CallUserProfileProviderOC?
    
    /// Provider for call token
    public var tokenProvider: CallTokenProvider?
    
    /// Provider for call token in Objective-C
    public var tokenProviderOC: CallTokenProviderOC?
    
    /// Ringtone URL for incoming calls customized.
    public var ringSoundURL: URL?
    
    /// Current call information
    public internal(set) var callInfo : CallInfo? = nil
    
    public internal(set) var receivedCalls = [String:CallInfo]()
        
    /// Cache for call stream views
    public internal(set) var canvasCache: [String: CallStreamView] = [:]
    
    public internal(set) var itemsCache: [String: CallStreamItem] = [:] {
        willSet {
            
        }
    }
    
    /// Listeners for call events
    public internal(set) var listeners:NSHashTable<CallServiceListener> = NSHashTable<CallServiceListener>.weakObjects()
    
    /// AgoraRtcEngineKit instance
    public private(set) var engine:AgoraRtcEngineKit?
    
    public internal(set) var callVC: UIViewController?
    
    public internal(set) var joinChannelName = ""
    
    public var currentUserInfo: CallUserProfileProtocol?
    
    public var token: String?
    
    /// Indicates whether to enable Picture-in-Picture mode for 1v1 video calls
    public var enablePIPOn1V1VideoScene: Bool = false
    
    /// Last Picture-in-Picture frame
    public internal(set) var lastPIPFrame = CGRect.zero
    
    public internal(set) var isVideoExchanged = false
    
    public internal(set) var alreadyVideoSetup = false
    
    public internal(set) var popup: CallPopupView?
    
    /// Ringtone player
    public private(set) lazy var player: AVAudioPlayer? = {
        var url = URL(fileURLWithPath: "")
        if let ringPath = self.ringSoundURL {
            url = ringPath
        } else {
            guard let path = Bundle.callBundle.path(forResource: "ring", ofType: "mp3") else {
                consoleLogInfo("Ringtone bundle file not found", type: .error)
                return nil
            }
            url = URL(fileURLWithPath: path)
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            return nil
        }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.prepareToPlay()
        return player
    }()
    

    private override init() {
        super.init()
        // Initialize CallKit related services or configurations here
    }
    
    @objc public func setup() {
        self.engine = AgoraRtcEngineKit.sharedEngine(withAppId: "c8a78f1878ec4a0d92c6a16d18c8b498", delegate: self)
        self.engine?.setDefaultAudioRouteToSpeakerphone(true)
        self.engine?.setVideoFrameDelegate(self)
        _ = self.player
        self.prepareRingtone()
        ChatClient.shared().chatManager?.add(self, delegateQueue: .main)
        self.checkCameraPermission()
        self.checkMicrophonePermission()
    }

    /// 检查并请求摄像头权限
    func checkCameraPermission() {
        // 检查当前摄像头权限状态
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .notDetermined:
            // 首次请求权限
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("摄像头权限已授予")
                        // 权限通过，可初始化摄像头相关功能（如预览层、拍摄等）
                    } else {
                        print("摄像头权限被拒绝")
                        // 提示用户去设置中开启权限
                    }
                }
            }
        case .authorized:
            // 已授予权限
            print("摄像头权限已授权")
        case .denied, .restricted:
            // 权限被拒绝或受限制（如家长控制）
            print("摄像头权限被拒绝，无法使用")
            // 可引导用户去设置中开启：Settings -> 应用名称 -> 摄像头
        @unknown default:
            print("未知的摄像头权限状态")
        }
    }
    
    /// 检查并请求麦克风权限
    func checkMicrophonePermission() {
        // 检查当前麦克风权限状态
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .notDetermined:
            // 首次请求权限
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("麦克风权限已授予")
                        // 权限通过，可初始化麦克风相关功能（如录音）
                    } else {
                        print("麦克风权限被拒绝")
                        // 提示用户去设置中开启权限
                    }
                }
            }
        case .authorized:
            // 已授予权限
            print("麦克风权限已授权")
        case .denied, .restricted:
            // 权限被拒绝或受限制
            print("麦克风权限被拒绝，无法使用")
            // 引导用户去设置中开启：Settings -> 应用名称 -> 麦克风
        @unknown default:
            print("未知的麦克风权限状态")
        }
    }
    
    @objc public func tearDown() {
        self.itemsCache.removeAll()
        self.canvasCache.removeAll()
        self.usersCache.removeAll()
        self.listeners.removeAllObjects()
        self.player?.stop()
        self.player = nil
        AgoraRtcEngineKit.destroy()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            consoleLogInfo("Failed to deactivate audio session: \(error.localizedDescription)", type: .error)
        }
        self.callVC = nil
        ChatClient.shared().chatManager?.remove(self)
    }
    
    private func prepareRingtone() {
        do {
            // Configure audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            consoleLogInfo("Failed to set audio session category: \(error.localizedDescription)", type: .error)
            return
        }
    }
    
    func playRingtone() {
        guard let player = self.player else {
            consoleLogInfo("Ringtone player is not initialized", type: .error)
            return
        }
        if !player.isPlaying {
            player.play()
        }
    }
    
    private func stopRingtone() {
        guard let player = self.player else {
            consoleLogInfo("Ringtone player is not initialized", type: .error)
            return
        }
        if player.isPlaying {
            player.stop()
        }
    }
    
    func ringTimeout() {
        DispatchQueue.main.async {
            self.stopRingtone()
            if let call = self.callInfo, call.state == .ringing {
                for listener in self.listeners.allObjects {
                    listener.didEndCall?(callId: call.callId, endReason: .noResponse, error: nil, duration: 0)
                }
                self.callInfo?.state = .idle
            }
        }
    }
    
    func cleanUICache() {
        self.itemsCache.removeAll()
        self.canvasCache.removeAll()
    }
    
    func showMiniAudioView(vc: UIViewController) {
        self.callVC = vc
        if self.lastPIPFrame == .zero {
            let floating = FloatingAudioView.addToWindow()
            floating?.clickDragViewBlock = { [weak self] in
                guard let `self` = self else { return }
                if let callVC = self.callVC {
                    ($0 as? FloatingAudioView)?.present(on: callVC)
                }
            }
        }
    }
    
    func showPIP(vc: UIViewController) {
        if self.enablePIPOn1V1VideoScene {
            if let pipVC = vc as? Call1v1VideoViewController {
                self.callVC = pipVC
            } else {
                consoleLogInfo("PIP is only supported in CallVideoViewController", type: .error)
            }
        } else {
            consoleLogInfo("PIP is not enabled for 1v1 video calls", type: .info)
        }
    }
}

