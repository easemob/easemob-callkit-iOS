//
//  LiveCommunicationManager.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 7/29/25.
//

import Foundation
import PushKit
import AVFAudio
#if canImport(LiveCommunicationKit)
import LiveCommunicationKit
#endif

@available(iOS 17.4, *)
class LiveCommunicationManager: NSObject {
    // 添加单例
    static let shared = LiveCommunicationManager()
    
    // PushKit相关
    private var pushRegistry: PKPushRegistry?
    
    var manager: ConversationManager?
    
    // 私有化初始化方法，确保单例
    private override init() {
        super.init()
    }
    
    // MARK: - PushKit Setup
    public func setupPushKit() {
        if !CallKitManager.shared.config.enableVOIP {
            consoleLogInfo("[LiveCommunicationManager] PushKit is not enabled", type: .debug)
            return
        }
        if pushRegistry == nil {
            pushRegistry = PKPushRegistry(queue: DispatchQueue.main)
            pushRegistry?.delegate = self
            pushRegistry?.desiredPushTypes = [.voIP]
        }
    }
    
    func createConversationManager(){
        if manager != nil {
            return
        }
        let config = ConversationManager.Configuration(
            ringtoneName: "notes_of_the_optimistic",
            iconTemplateImageData: UIImage(named: "AppIcon")?.pngData(),
            maximumConversationGroups: 1,
            maximumConversationsPerConversationGroup: 1,
            includesConversationInRecents: false,
            supportsVideo: false,
            supportedHandleTypes: [.generic]
        )
        manager = ConversationManager(configuration: config)
        manager?.delegate = self
    }
         
    func reportIncomingCall(uuid: UUID, callerName: String) {
        let local = Handle(type: .generic, value: callerName, displayName: callerName)
        let update = Conversation.Update(localMember: local,members: [local],activeRemoteMembers: [local])
         
        Task {
            do {
                try await manager?.reportNewIncomingConversation(uuid: uuid, update: update)
                consoleLogInfo("[LiveCommunicationManager] successfully reported new incoming call", type: .debug)
                CallKitManager.shared.callInfo?.state = .ringing
            } catch {
                consoleLogInfo("[LiveCommunicationManager] failed to report new incoming call: \(error.localizedDescription)", type: .error)
            }
        }
    }
     
    func endCall(){
        self.manager?.invalidate()
        self.manager = nil
        consoleLogInfo("[LiveCommunicationManager] destroy ConversationManager", type: .debug)
    }
}

// MARK: - PKPushRegistryDelegate
@available(iOS 17.4, *)
extension LiveCommunicationManager: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        consoleLogInfo("[LiveCommunicationManager] PushKit token updated", type: .debug)
        ChatClient.shared().bindPushKitToken(pushCredentials.token)
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        consoleLogInfo("[LiveCommunicationManager] didReceiveIncomingPushWith payload: \(payload.dictionaryPayload)", type: .debug)
        ChatClient.shared().applicationWillEnterForeground(UIApplication.shared)
        // 处理呼叫到来的逻辑
        handleIncomingCall(payload: payload)
        Thread.sleep(forTimeInterval: 0.05)
        completion()
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        consoleLogInfo("[LiveCommunicationManager] PushKit token invalidated", type: .debug)
    }
    
    // MARK: - 处理呼叫到来
    private func handleIncomingCall(payload: PKPushPayload) {
        let custom = payload.dictionaryPayload["e"] as? Dictionary<String, Any>
        var callId = ""
        if let id = custom?[kCallId] as? String {
            callId = id
        }
        let callerID = payload.dictionaryPayload["f"] as? String ?? ""
//        let calleeID = ChatClient.shared().currentUsername ?? ""
        var callerNickname = ""
        if let nickname = custom?["callerNickname"] as? String {
            callerNickname = nickname
        }
        if let msgId = payload.dictionaryPayload["m"] as? String {
            if let message = ChatClient.shared().chatManager?.getMessageWithMessageId(msgId) {
                if let callInfo = message.callInfo {
                    callId = callInfo.callId
                    CallKitManager.shared.callInfo = callInfo
                    CallKitManager.shared.callInfo?.inviteMessage = message
                    consoleLogInfo("[LiveCommunicationManager] set callInfo from message: \(callInfo)", type: .debug)
                } else {
                    consoleLogInfo("[LiveCommunicationManager] message does not contain call info", type: .error)
                }
            } else {
                consoleLogInfo("[LiveCommunicationManager] failed to get message with id: \(msgId)", type: .error)
            }
        }
//        var groupId = ""
//        if let group = payload.dictionaryPayload["g"] as? String {
//            groupId = group
//        }

        consoleLogInfo("[LiveCommunicationManager] incoming call:  (\(callerID))", type: .debug)
        LiveCommunicationManager.shared.createConversationManager()
        var uuid = UUID(uuidString: callId)
        if uuid == nil {
            uuid = UUID()
            consoleLogInfo("[LiveCommunicationManager] generated new UUID: \(uuid!.uuidString) callId: \(callId)", type: .debug)
        } else {
            consoleLogInfo("[LiveCommunicationManager] reuse UUID: \(uuid!.uuidString)", type: .debug)
        }
        LiveCommunicationManager.shared.reportIncomingCall(uuid: uuid!, callerName: callerNickname.isEmpty ? callerID:callerNickname)
    }
}

@available(iOS 17.4, *)
extension LiveCommunicationManager: ConversationManagerDelegate
{
    func conversationManager(_ manager: ConversationManager, conversationChanged conversation: Conversation) {
        consoleLogInfo("[LiveCommunicationManager] conversationChanged: uuid=\(conversation.uuid.uuidString),state=\(conversation.state),localMember:\(String(describing: conversation.localMember))",type: .debug)
    }
    
    func conversationManagerDidBegin(_ manager: ConversationManager) {
        consoleLogInfo("[LiveCommunicationManager] conversationManagerDidBegin",type: .debug)
    }
    
    func conversationManagerDidReset(_ manager: ConversationManager) {
        consoleLogInfo("[LiveCommunicationManager] conversationManagerDidReset",type: .debug)
    }
    
    func conversationManager(_ manager: ConversationManager, perform action: ConversationAction) {
        consoleLogInfo("[LiveCommunicationManager] perform action:\(action)",type: .debug)
        switch action.self {
        case let action as LiveCommunicationKit.JoinConversationAction:
            self.joinAction(action: action)
            break
        case let action as LiveCommunicationKit.EndConversationAction:
            self.endAction(action: action)
            break
        case let action as LiveCommunicationKit.MuteConversationAction:
            self.muteAction(action: action)
            break
        default:
            break
        }
    }
    
    private func joinAction(action: JoinConversationAction) {
        DispatchQueue.main.async {
            UIViewController.currentController?.showCallToast(toast: "Connecting".call.localize)
        }
        if let call = CallKitManager.shared.callInfo,!call.callId.isEmpty {
            CallKitManager.shared.accept()
            action.fulfill()
        } else {
            consoleLogInfo("[LiveCommunicationManager] do not have call info", type: .error)
            action.fail()
        }
    }
    
    private func muteAction(action: MuteConversationAction) {
        // 静音操作
        if let call = CallKitManager.shared.callInfo {
            if call.state == .answering {
                CallKitManager.shared.enableLocalAudio(!action.isMuted)
                action.fulfill()
            } else {
                consoleLogInfo("[LiveCommunicationManager] call is not answering", type: .error)
                action.fail()
            }
        } else {
            consoleLogInfo("[LiveCommunicationManager] do not have call info", type: .error)
            action.fail()
        }
    }
    
    private func endAction(action: EndConversationAction) {
        consoleLogInfo("[LiveCommunicationManager] perform endAction:",type: .debug)
        if let call = CallKitManager.shared.callInfo {
            if call.state == .answering || call.state == .ringing {
                CallKitManager.shared.hangup()
                action.fulfill()
            } else {
                consoleLogInfo("[LiveCommunicationManager] call is not answering or ringing, state: \(call.state.rawValue)", type: .error)
                action.fail()
                CallKitManager.shared.quitCall()
            }
        } else {
            consoleLogInfo("[LiveCommunicationManager] do not have call info", type: .error)
            action.fail()
            CallKitManager.shared.quitCall()
        }
    }
    
    func conversationManager(_ manager: ConversationManager, timedOutPerforming action: ConversationAction) {
        // 会话超时
        consoleLogInfo("[LiveCommunicationManager] perform timedOutPerforming:\(action)",type: .debug)
        CallKitManager.shared.quitCall()
    }
    
    func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession) {
        // 会话激活了
        consoleLogInfo("[LiveCommunicationManager] perform didActivate:",type: .debug)
    }
    
    func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession) {
        //会话失效了
        consoleLogInfo("[LiveCommunicationManager] perform didDeactivate:",type: .debug)
        CallKitManager.shared.quitCall()
    }
}

