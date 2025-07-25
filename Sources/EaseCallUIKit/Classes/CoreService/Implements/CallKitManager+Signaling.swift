//
//  CallKitManager+Signaling.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 7/4/25.
//

import Foundation
import AgoraRtcKit

extension CallKitManager: ChatEventsListener {
    
    public func messagesDidReceive(_ aMessages: [ChatMessage]) {
        for message in aMessages {
            if message.chatType == .chat || message.chatType == .groupChat {
                if let ext = message.ext as? [String: Any],!ext.isEmpty {
                    parseCallInfo(from: message)
                }
            }
        }
    }
    
    public func cmdMessagesDidReceive(_ aCmdMessages: [ChatMessage]) {
        for message in aCmdMessages {
            if message.chatType == .chat || message.chatType == .groupChat {
                if let ext = message.ext as? [String: Any],!ext.isEmpty {
                    parseCallInfo(from: message)
                }
            }
        }
    }
    
    private func parseCallInfo(from message: ChatMessage) {

        if let ext = message.ext as? [String: Any] {
            guard let msgType = ext[kMsgType] as? String,
                  let callId = ext[kCallId] as? String,
                  let callerDevId = ext[kCallerDevId] as? String
                   else {
                consoleLogInfo("Invalid call info in message id:\(message.messageId) : \(String(describing: message.ext))", type: .error)
                return
            }
            let defaultCalleeId = ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? ""
            let calleeDevId = ext[kCalleeDevId] as? String ?? defaultCalleeId
            let callTypeRawValue = ext[kCallType] as? UInt ?? 0
            let callType = CallType(rawValue: callTypeRawValue) ?? .singleAudio
            let channelName = ext[kChannelName] as? String ?? ""
            let isValid = ext[kCallStatus] as? Bool ?? false//呼叫的离线消息是否有效
            let result = ext[kCallResult] as? String ?? ""
            let callExtension: [String: Any] = ext[kExt] as? [String: Any] ?? [:]
            let groupId = callExtension["groupId"] as? String ?? ""
            let groupName = callExtension["groupName"] as? String ?? ""
            let groupAvatar = callExtension["groupAvatar"] as? String ?? ""
            if let userJson = ext[kUserInfo] as? [String: Any] {
                let profile  = CallUserProfile()
                profile.setValuesForKeys(userJson)
                if profile.id.isEmpty {
                    profile.id = message.from
                }
                if CallKitManager.shared.usersCache[profile.id] == nil {
                    CallKitManager.shared.usersCache[profile.id] = profile
                } else {
                    CallKitManager.shared.usersCache[profile.id]?.nickname = profile.nickname
                    CallKitManager.shared.usersCache[profile.id]?.avatarURL = profile.avatarURL
                }
            }
            if msgType == kMsgTypeValue {
                if let action = ext[kAction] as? String {
                    switch action {
                    case kInviteAction://被叫收到邀请
                        if let call = self.callInfo,call.callId == callId {
                            consoleLogInfo("Call already in progress with callId: \(callId)", type: .error)
                            return
                        }
                        if GlobalTimerManager.shared.timerCache[callId] != nil {
                            consoleLogInfo("Invitation signal timer already exists for callId: \(callId)", type: .error)
                            return
                        }
                        if ChatClient.shared().currentUsername ?? "" == message.from {
                            return
                        }
                        if let info = self.callInfo,info.state != .idle {
                            self.answerCall(callId: callId, callerId: message.from, result: kBusyResult, callerDeviceId: callerDevId)
                        } else {
                            let info = CallInfo(callId: callId, callerId: message.from, callerDeviceId: callerDevId, channelName: channelName, type: callType, startMessageId: message.messageId, extensionInfo: callExtension)
                            info.groupId = groupId
                            info.groupName = groupName
                            info.groupAvatar = groupAvatar
                            self.receivedCalls[callId] = info
                            if let calleeId = ChatClient.shared().currentUsername {
                                self.callInfo?.calleeId = calleeId
                                self.callInfo?.calleeDeviceId = ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? ""
                            }
                            self.calleeAnswerCaller(callId: callId, callerId: message.from, callerDeviceId: callerDevId)
                            self.startInvitationSignalTimer(callId: callId)
                        }
                    case kAlertAction://主叫收到被叫回复信息判断本次呼叫是否有效
                        if let call = self.callInfo {
                            self.stopInvitationSignalTimer(callId: callId)
                            if ChatClient.shared().getDeviceConfig(nil).deviceUUID == callerDevId {//主叫回给被叫
                                self.confirmRing(callId: callId, calleeId: message.from, calleeDeviceId: calleeDevId, is_valid: call.callId == callId)
                            } else {
                                consoleLogInfo("Current device:\(call.callerDeviceId) Call accept on other device:\(calleeDevId) messageId:\(message.messageId) ext:\(String(describing: ext))", type: .error)
                            }
                        }
                    case kConfirmRingAction://被叫收到主叫的确认振铃事件后弹窗振铃
                        if let currentDeviceId = ChatClient.shared().getDeviceConfig(nil).deviceUUID, currentDeviceId == calleeDevId {
                            for info in self.receivedCalls.values {
                                self.stopInvitationSignalTimer(callId: info.callId)
                            }
                            if let call = self.callInfo,call.callId != callId,call.state != .idle {
                                self.callerConfirmAnswer(callId: callId, calleeId: message.from, calleeDeviceId: callerDevId, result: kBusyResult)
                                consoleLogInfo("parseCallInfo: Call already in progress with different callId: \(call.callId) for callId: \(callId)", type: .error)
                                return
                            }
                            if calleeDevId == ChatClient.shared().getDeviceConfig(nil).deviceUUID {
                                if let call = self.receivedCalls[callId] {
                                    if isValid {
                                        self.callInfo = call
                                        self.callInfo?.state = .ringing
                                        if call.type == .multiCall {
                                            let currentUserId = ChatClient.shared().currentUsername ?? ""
                                            let item = CallStreamItem(userId: currentUserId, index: 0, isExpanded: false)
                                            item.waiting = false
                                            self.itemsCache[currentUserId] = item
                                            let view = CallStreamView(item: item)
                                            self.canvasCache[currentUserId] = view
                                        }
                                        self.presentCalleePage(call: call)
                                    }
                                    self.receivedCalls.removeAll()
                                    
                                }
                            }
                        }
                    case kCancelCallAction://被叫收到主叫已经取消呼叫的事件
                        if let call = self.callInfo, call.callId == callId,call.state != .answering {
                            self.stopInvitationSignalTimer(callId: callId)
                            self.stopConfirmBuildConnectionTimer(callId: callId)
                            self.callInfo?.state = .idle
                            self.player?.stop()
                            for listener in self.listeners.allObjects {
                                listener.didEndCall?(callId: callId, endReason: .remoteCancel, error: nil, duration: 0)
                            }
                            self.updateCallEndReason(.remoteCancel)
                        } else {
                            self.receivedCalls.removeValue(forKey: callId)
                            self.stopInvitationSignalTimer(callId: callId)
                        }
                        self.dismissCurrentCallPage()
                        
                    case kConfirmCalleeAction://确认被叫
                        if let call = self.callInfo {
                            if call.state == .ringing && call.callId == callId {
                                self.stopConfirmBuildConnectionTimer(callId: callId)
                                let currentDeviceId = ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? ""
                                if currentDeviceId == calleeDevId {//确认自己被叫
                                    switch result {
                                    case kAcceptResult:
                                        self.callInfo?.state = .answering
                                        if call.type == .singleVideo {
                                            self.setupLocalVideo()
                                        }
                                        self.tokenHandler(channelName: channelName)
                                    case kBusyResult:
                                        self.callInfo?.state = .idle
                                        self.updateCallEndReason(.busy)
                                    default:
                                        break
                                    }
                                } else {//其它设备处理
                                    for listener in self.listeners.allObjects {
                                        listener.didEndCall?(callId: callId, endReason: .handleOnOtherDevice, error: nil, duration: 0)
                                    }
                                    self.updateCallEndReason(.handleOnOtherDevice)
                                    self.callInfo?.state = .idle
                                    self.player?.stop()
                                }
                            } else {
                                self.stopInvitationSignalTimer(callId: callId)
                                self.receivedCalls.removeValue(forKey: callId)
                            }
                        }
                    case kAnswerCallAction://主叫收到被叫接受通话
                        if let call = self.callInfo, let currentDeviceId = ChatClient.shared().getDeviceConfig(nil).deviceUUID, currentDeviceId == callerDevId, call.callId == callId {
                            if call.type == .multiCall {
                                if result != kAcceptResult {
                                    self.itemsCache.removeValue(forKey: message.from)
                                    if let vc = UIViewController.currentController as? CallMultiViewController {
                                        vc.callView.updateWithItems()
                                    }
                                    self.updateCallEndReason(self.getEndReason(result: result))
                                }
                                GlobalTimerManager.shared.removeTimeAsSimilarKey("call-\(callId) users:")
                            } else {
                                if call.state == .dialing {
                                    if result == kAcceptResult {
                                        self.callInfo?.state = .answering
                                        self.presentCallerPage(call: call)
                                    } else {
                                        self.callInfo?.state = .idle
                                        self.player?.stop()
                                        self.callerConfirmAnswer(callId: callId, calleeId: call.calleeId, calleeDeviceId: call.calleeDeviceId, result: result)
                                        let endReason = getEndReason(result: result)
                                        for listener in self.listeners.allObjects {
                                            listener.didEndCall?(callId: callId, endReason: endReason, error: nil, duration: 0)
                                        }
                                        self.updateCallEndReason(endReason)
                                        let result = self.engine?.leaveChannel() ?? 0
                                        consoleLogInfo("Remote user refuse then leave channel result: \(result)", type: .info)
                                        self.dismissCurrentCallPage()
                                    }
                                }
                            }
                            self.callerConfirmAnswer(callId: callId, calleeId: call.calleeId, calleeDeviceId: call.calleeDeviceId, result: result)
                            if result == kAcceptResult {
                                if call.type == .multiCall {
                                    callId+" users:"+call.calleeId
                                } else {
                                    self.callStartTimerStop(callId: callId)
                                }
                            }
                        }
                    default:
                        consoleLogInfo("Unknown action type: \(action) in message id:\(message.messageId)", type: .error)
                    }
                }
            }
            
            if !result.isEmpty,result != kAcceptResult {
                for listener in self.listeners.allObjects {
                    listener.didEndCall?(callId: callId, endReason: self.getCallEndReason(result: result), error: nil, duration: 0)
                }
            }
        }
    }
    
    private func dismissCurrentCallPage() {
        if let currentVC = UIViewController.currentController {
            if currentVC is Call1v1AudioViewController || currentVC is Call1v1VideoViewController {
                currentVC.dismiss(animated: true)
                self.quitCall()
            }
            self.popup?.dismiss()
        }
    }
    
    func updateCallEndReason(_ reason: CallEndReason) {
        if let messageId = self.callInfo?.inviteMessageId,let message = ChatClient.shared().chatManager?.getMessageWithMessageId(messageId) {
            let ext = message.ext ?? [:]
            var newExt = ext
            newExt[kCallEndReason] = reason.rawValue
            message.ext = newExt
            Task {
                let result = await ChatClient.shared().chatManager?.update(message)
                if let error = result?.1 {
                    consoleLogInfo("Failed to update call reason:\(reason.rawValue): \(String(describing: error.errorDescription))", type: .error)
                } else {
                    if let message = result?.0 {
                        for listener in self.listeners.allObjects {
                            listener.didUpdateCallEndReason?(message: message)
                        }
                    }
                    
                }
            }
        }
    }
    private func presentCalleePage(call: CallInfo) {
        startRingTimer(callId: call.callId)
        self.player?.play()
        popup = CallPopupView(frame: UIScreen.main.bounds)
        if let user = self.usersCache[call.callerId] {
            popup?.refresh(profile: user,type: call.type)
            
        }
        popup?.show()
        popup?.callCardAction = { [weak self] in
            guard let `self` = self else { return }
            switch $0 {
            case .accept:
                stopRingTimer(callId: call.callId)
                self.callInfo?.state = .answering
                self.accept()
            case .decline:
                self.hangup()
            case .other:
                self.callInfo?.state = .ringing
            default:
                break
            }
            if call.state != .idle {
                var vc: UIViewController = Call1v1AudioViewController(role: .callee)
                switch call.type {
                case .singleAudio:
                    vc = Call1v1AudioViewController(role: .callee)
                case .singleVideo:
                    vc = Call1v1VideoViewController(role: .callee)
                case .multiCall:
                    vc = CallMultiViewController(role: .callee)
                default:
                    break
                }
                DispatchQueue.main.asyncAfter(wallDeadline: .now()+0.35) {
                    UIApplication.shared.call.keyWindow?.rootViewController?.present(vc, animated: true)
                }
            }
        }
    }
    
    private func presentCallerPage(call: CallInfo) {
        startRingTimer(callId: call.callId)
        var vc: UIViewController = Call1v1AudioViewController(role: .caller)
        switch call.type {
        case .singleAudio:
            vc = Call1v1AudioViewController(role: .caller)
        case .singleVideo:
            vc = Call1v1VideoViewController(role: .caller)
        case .multiCall:
            vc = CallMultiViewController(role: .caller)
        default:
            break
        }
        DispatchQueue.main.asyncAfter(wallDeadline: .now()+0.25) {
            UIApplication.shared.call.keyWindow?.rootViewController?.present(vc, animated: true)
        }
    }
    
    private func getEndReason(result: String) -> CallEndReason {
        var endReason = CallEndReason.remoteCancel
        switch result {
        case kRefuseResult: endReason = .refuse
        case kBusyResult: endReason = .busy
        case kRefuseResult: endReason = .refuse
        default:
            break
        }
        return endReason
    }
    
    private func tokenHandler(channelName: String) {
        if self.tokenProvider != nil || self.tokenProviderOC != nil {
            if let currentUserId = ChatClient.shared().currentUsername {
                if self.tokenProvider != nil {
                    Task {
                        let result = await self.tokenProvider?.fetchCallToken(channelName: channelName, userId: currentUserId)
                        if let token = result?.0,!token.isEmpty {
                            self.token = token
                            let joinResult = self.joinChannel(channelName: channelName)
                            if !joinResult {
                                consoleLogInfo("Failed to join channel with error code: \(joinResult)", type: .error)
                            }
                        } else {
                            consoleLogInfo("Failed to fetch call token: \(result?.1 ?? 0)", type: .error)
                        }
                    }
                }
                if self.tokenProviderOC != nil {
                    self.tokenProviderOC?.fetchCallToken(channelName: channelName, userId: currentUserId, completion: { [weak self] token, expiration in
                        guard let `self` = self else { return }
                        if let token = token,!token.isEmpty {
                            self.token = token
                            let joinResult = self.joinChannel(channelName: channelName)
                            if !joinResult {
                                consoleLogInfo("Failed to join channel with error code: \(joinResult)", type: .error)
                            }
                        } else {
                            consoleLogInfo("Failed to fetch call token: \(expiration)", type: .error)
                        }
                    })
                }
            }
        } else {
            //TODO: - call sdk token api save token join channel
//                                        let token = ChatClient.shared().fetchToken(withUsername: "123", password: "1")
            let joinResult = self.joinChannel(channelName: channelName)
            if !joinResult {
                consoleLogInfo("Failed to join channel with error code: \(joinResult)", type: .error)
            }
        }
    }

    
    private func getCallEndReason(result: String) -> CallEndReason {
        var reason = CallEndReason.remoteNoResponse
        switch result {
        case kRefuseResult:
            reason = .refuse
        case kBusyResult:
            reason = .busy
        default:
            break
        }
        return reason
    }
    
    func answerCall(callId: String,callerId: String,result: String,callerDeviceId: String) {
        if callId.isEmpty || callerId.isEmpty || result.isEmpty || callerDeviceId.isEmpty {
            consoleLogInfo("Invalid parameters for answering call:\ncallId: \(callId), callerId: \(callerId), result: \(result), callerDeviceId: \(callerDeviceId)", type: .error)
            return
        }
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]

        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: kAnswerCallAction,
            kCallId: callId,
            kCalleeDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kCallerDevId: callerDeviceId,
            kCallResult: result,
            kTs: Date().timeIntervalSince1970 * 1000, // Timestamp in milliseconds
        ]
        if !json.isEmpty {
            ext.merge(json) { _, new in
                new
            }
        }
        let message = ChatMessage(conversationID: callerId, body: ChatCMDMessageBody(action: kCall), ext: ext)
        message.deliverOnlineOnly = true
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                consoleLogInfo("Failed to send answer call message: \(String(describing: error.errorDescription))", type: .error)
            }
            self.startConfirmBuildConnectionTimer(callId: callId)
        }
    }
    
    func handleError(_ error: ChatError) {
        let result = CallResult(callId: "")
        result.callError = CallError.error(code: error.code.rawValue, message: String(describing: error.errorDescription))
        for listener in self.listeners.allObjects {
            listener.didOccurError?(result.callError!)
        }
    }
}



extension CallKitManager: CallMessageService {
    
    public func addListener(_ listener: any CallServiceListener) {
        if self.listeners.contains(listener) {
            return
        }
        self.listeners.add(listener)
    }
    
    public func removeListener(_ listener: any CallServiceListener) {
        self.listeners.remove(listener)
    }
    
    
    public func call(with userId: String, type: CallType, extensionInfo: [String : Any]? = nil) {
        if userId.isEmpty {
            consoleLogInfo("User ID cannot be empty", type: .error)
            self.handleError(ChatError(description: "User ID cannot be empty", code: .invalidParam))
            return
        }
        if userId == ChatClient.shared().currentUsername ?? "" {
            consoleLogInfo("Cannot call yourself", type: .error)
            self.handleError(ChatError(description: "Cannot call yourself", code: .invalidParam))
            return
        }
        if type == .multiCall {
            consoleLogInfo("Multi-call requires groupCall", type: .error)
            self.handleError(ChatError(description: "Multi-call requires groupCall", code: .invalidParam))
            return
        }
        if let call = self.callInfo, !call.callId.isEmpty, call.state != .idle {
            self.handleError(ChatError(description: "A call is already in progress: callId:\(call.callId)", code: .invalidParam))
            consoleLogInfo("A call is already in progress: callId:\(call.callId)", type: .error)
            return
        }
        DispatchQueue.main.async {
            self.engine?.setVideoScenario(.application1V1Scenario)
            if type == .singleVideo {
                self.engine?.startPreview()
            }
            let callId = UUID().uuidString
            let channelName = "channel-\(callId)"
            var ext: [String: Any] = [
                kMsgType: kMsgTypeValue,
                kAction: kInviteAction,
                kCallId: callId,
                kCallType: type.rawValue,
                kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
                kChannelName: channelName,
                kTs: Int(Date().timeIntervalSince1970 * 1000), // Timestamp in milliseconds
                kCallDuration: 0,
                kCallEndReason: CallEndReason.remoteNoResponse.rawValue,
            ]
            if extensionInfo != nil {
                ext[kExt] = extensionInfo
            }
            let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
            if !json.isEmpty {
                ext.merge(json) { _, new in
                    new
                }
            }
            let message = ChatMessage(conversationID: userId, body: ChatTextMessageBody(text: (type == .singleAudio ? "invite_info_audio":"invite_info_video").call.localize), ext: ext)
            Task {
                let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
                if let error = result?.1 {
                    self.handleError(error)
                    consoleLogInfo("Failed to send call message: \(String(describing: error.errorDescription))", type: .error)
                    self.callStartTimerStop(callId: callId)
                    self.callInfo?.state = .idle
                    return
                }
                self.callInfo = CallInfo(callId: callId, callerId: ChatClient.shared().currentUsername ?? "", callerDeviceId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "", channelName: channelName, type: type, startMessageId: result?.0?.messageId ?? "", extensionInfo: extensionInfo)
                self.callInfo?.calleeId = userId
                self.callInfo?.state = .dialing
                self.player?.play()
                DispatchQueue.main.async {
                    let joinResult = self.joinChannel(channelName: channelName)
                    if !joinResult {
                        consoleLogInfo("Failed to join channel with error code: \(joinResult)", type: .error)
                        return
                    }
                    var callVC: UIViewController = Call1v1AudioViewController(role: .caller)
                    if type == .singleVideo {
                        callVC = Call1v1VideoViewController(role: .caller)
                    }
                    UIApplication.shared.call.keyWindow?.rootViewController?.present(callVC, animated: true,completion: {
                        if type == .singleVideo {
                            self.setupLocalVideo()
                        }
                    })
                }
                
            }
            self.callStartTimerStart(callId: callId)
        }
    }
    
    public func groupCall(groupId: String, groupName: String? = nil,groupAvatar: String? = nil, extensionInfo: [String : Any]? = nil) {
        let type = CallType.multiCall
        if groupId.isEmpty {
            consoleLogInfo("group id cannot be empty", type: .error)
            return
        }
        DispatchQueue.main.async {
            guard let currentVC = UIViewController.currentController else {
                consoleLogInfo("No current view controller", type: .error)
                return
            }
            
            if currentVC is MultiCallParticipantsController ||
                currentVC.presentedViewController is MultiCallParticipantsController {
                consoleLogInfo("MultiCallParticipantsController is already presented", type: .error)
                return
            }
            var excludeUsers: [String] = []
            for item in self.itemsCache.values {
                excludeUsers.append(item.userId)
            }
            if let currentUserId = ChatClient.shared().currentUsername {
                excludeUsers.append(currentUserId)
            }
            (currentVC is CallMultiViewController ? currentVC:UIApplication.shared.call.keyWindow?.rootViewController)?.present(MultiCallParticipantsController(groupId: groupId, excludeUsers: excludeUsers, closure: { [weak self] ids in
                guard let `self` = self else { return }
                if ids.isEmpty {
                    consoleLogInfo("No participants selected for multi-call", type: .error)
                    return
                }
                if ids.count+excludeUsers.count > 16 {
                    consoleLogInfo("Cannot start multi-call with more than 16 participants", type: .error)
                    self.handleError(ChatError(description: "Cannot start multi-call with more than 16 participants", code: .invalidParam))
                    return
                }
                startGroupCall(ids: ids)
            }), animated: true)
            
            func startGroupCall(ids: [String]) {
                self.engine?.setVideoScenario(.applicationMeetingScenario)
                var callId = UUID().uuidString
                var channelName = "channel-\(callId)"
                if let call = self.callInfo, !call.callId.isEmpty,call.state == .answering {
                    callId = call.callId
                    channelName = call.channelName
                    if call.groupId != groupId {
                        self.handleError(ChatError(description: "Call already in progress with different group ID", code: .invalidParam))
                        consoleLogInfo("Call already in progress with different group ID:\(String(describing: call.groupId)) call group:\(groupId)", type: .error)
                        return
                    }
                }
                let chatGroup = ChatGroup(id: groupId)
                let group_name = groupName ?? (chatGroup?.groupName ?? "")
                let group_avatar = groupAvatar ?? (chatGroup?.groupAvatar ?? "")
                var ext: [String: Any] = [:]
                if groupId == self.callInfo?.groupId ?? "" {
                    ext = [
                        kMsgType: kMsgTypeValue,
                        kAction: kInviteAction,
                        kCallId: callId,
                        kCallType: type.rawValue,
                        kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
                        kChannelName: channelName,
                        kTs: Int(Date().timeIntervalSince1970 * 1000), // Timestamp in milliseconds
                        kExt: ["groupId": groupId,
                               "groupName": self.callInfo?.groupName ?? group_name,
                               "groupAvatar": self.callInfo?.groupAvatar ?? group_avatar],
                        kCallDuration: 0,
                        kCallEndReason: CallEndReason.remoteNoResponse.rawValue,
                    ]
                } else {
                    ext = [
                        kMsgType: kMsgTypeValue,
                        kAction: kInviteAction,
                        kCallId: callId,
                        kCallType: type.rawValue,
                        kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
                        kChannelName: channelName,
                        kTs: Int(Date().timeIntervalSince1970 * 1000), // Timestamp in milliseconds
                        "groupId": groupId,
                        "groupName": groupName ?? group_name,
                        "groupAvatar": groupAvatar ?? group_avatar
                    ]
                }
                if extensionInfo != nil {
                    ext[kExt] = extensionInfo
                }
                let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
                if !json.isEmpty {
                    ext.merge(json) { _, new in
                        new
                    }
                }
                let message = ChatMessage(conversationID: groupId, body: ChatTextMessageBody(text: "group_invite_info".call.localize), ext: ext)
                message.receiverList = ids.filter({ $0 != ChatClient.shared().currentUsername ?? "" })
                message.chatType = .groupChat
                Task {
                    let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
                    if let error = result?.1 {
                        self.handleError(error)
                        consoleLogInfo("Failed to send group call message: \(String(describing: error.errorDescription))", type: .error)
                        self.callStartTimerStop(callId: callId+" users:"+ids.joined(separator: "-"))
                        self.callInfo?.state = .idle
                        return
                    }
                    self.player?.play()
                    if self.callInfo?.callId.isEmpty ?? true {
                        self.callInfo = CallInfo(callId: callId, callerId: ChatClient.shared().currentUsername ?? "", callerDeviceId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "", channelName: channelName, type: type, startMessageId: result?.0?.messageId ?? "", extensionInfo: extensionInfo)
//                        self.callInfo?.calleeId = ids.joined(separator: "-")
                        
                        if self.callInfo?.groupId == nil {
                            self.callInfo?.groupId = groupId
                        }
                        if self.callInfo?.groupName == nil {
                            self.callInfo?.groupName = groupName
                        }
                        if self.callInfo?.groupAvatar == nil {
                            self.callInfo?.groupAvatar = groupAvatar
                        }
                    } else {
                        self.callInfo?.callerId = ChatClient.shared().currentUsername ?? ""
//                        self.callInfo?.calleeId = ids.joined(separator: "-")
                        self.callInfo?.callerDeviceId = ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? ""
                        self.callInfo?.inviteMessageId = result?.0?.messageId ?? ""
                    }
                    self.callInfo?.state = .dialing
                    DispatchQueue.main.async {
                        var lastIndex = 0
                        if self.itemsCache.count > 0 {
                            lastIndex = self.itemsCache.values.map { $0.index }.max() ?? 0
                        }
                        for (index,id) in ids.enumerated() {
                            if self.itemsCache[id] == nil {
                                let item = CallStreamItem(userId: id, index: lastIndex+index+1, isExpanded: false)
                                item.waiting = true
                                self.itemsCache[id] = item
                                let view = CallStreamView(item: item)
                                self.canvasCache[id] = view
                            }
                        }
                        if currentVC is CallMultiViewController {
                            (currentVC as? CallMultiViewController)?.callView.updateWithItems()
                        } else {
                            let joinResult = self.joinChannel(channelName: self.callInfo?.channelName ?? "")
                            if !joinResult {
                                consoleLogInfo("Failed to join channel with error code: \(joinResult)", type: .error)
                                return
                            }
                            self.setupLocalVideo()
                            DispatchQueue.main.asyncAfter(wallDeadline: .now()+0.3) {
                                UIApplication.shared.call.keyWindow?.rootViewController?.present(CallMultiViewController(role: .caller), animated: true)
                            }
                        }
                    }
                }
                let timerKey = callId+" users:"+ids.joined(separator: "-")
                self.callStartTimerStart(callId:timerKey)
            }
        }
    }
    
    
    public func calleeAnswerCaller(callId: String, callerId: String, callerDeviceId: String) {
        if callId.isEmpty || callerId.isEmpty || callerDeviceId.isEmpty {
            consoleLogInfo("Invalid parameters for call: callId: \(callId), callerId: \(callerId), callerDeviceId: \(callerDeviceId)", type: .error)
            return
        }
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: kAlertAction,
            kCallId: callId,
            kCallerDevId: callerDeviceId,
            kCalleeDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kTs: Int(Date().timeIntervalSince1970 * 1000) // Timestamp in milliseconds
        ]
        if !json.isEmpty {
            ext.merge(json) { _, new in
                new
            }
        }
        let message = ChatMessage(conversationID: callerId, body: ChatCMDMessageBody(action: kCall), ext: ext)
        message.deliverOnlineOnly = true
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                self.handleError(error)
                self.callInfo?.state = .idle
                consoleLogInfo("Failed to send calleeAnswerCaller message: \(String(describing: error.errorDescription))", type: .error)
            }
        }
    }
    
    public func cancelCall(callId: String, calleeId: String) {
        if callId.isEmpty || calleeId.isEmpty {
            consoleLogInfo("Invalid parameters for cancelling call: callId: \(callId), calleeId: \(calleeId)", type: .error)
            return
        }
        self.sendCancelSignal(callId: callId, calleeId: calleeId)
    }
    
    public func sendCancelSignal(callId: String, calleeId: String) {
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: kCancelCallAction,
            kCallId: callId,
            kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kTs: Int(Date().timeIntervalSince1970 * 1000) // Timestamp in milliseconds
        ]
        if !json.isEmpty {
            ext.merge(json) { _, new in
                new
            }
        }
        let message = ChatMessage(conversationID: calleeId, body: ChatCMDMessageBody(action: kCall), ext: ext)
        message.deliverOnlineOnly = true
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                self.handleError(error)
                consoleLogInfo("Failed to send cancel call message: \(String(describing: error.errorDescription))", type: .error)
            }
        }
        if let call = self.callInfo,call.callId == callId,call.callerId == ChatClient.shared().currentUsername ?? "" {
            self.updateCallEndReason(.cancel)
        }
    }
    
    public func confirmRing(callId: String,calleeId: String, calleeDeviceId: String, is_valid: Bool) {
        if callId.isEmpty || calleeId.isEmpty || calleeDeviceId.isEmpty {
            consoleLogInfo("Invalid parameters for confirming ring: callId: \(callId), calleeId: \(calleeId), calleeDeviceId: \(calleeDeviceId)", type: .error)
            return
        }
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: kConfirmRingAction,
            kCallId: callId,
            kCalleeDevId: calleeDeviceId,
            kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kTs: Int(Date().timeIntervalSince1970 * 1000), // Timestamp in milliseconds
            kCallStatus: is_valid ? 1 : 0
        ]
        if !json.isEmpty {
            ext.merge(json) { _, new in
                new
            }
        }
        let message = ChatMessage(conversationID: calleeId, body: ChatCMDMessageBody(action: kCall), ext: ext)
        message.deliverOnlineOnly = true
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                self.handleError(error)
                self.callInfo?.state = .idle
                consoleLogInfo("Failed to send confirm ring message: \(String(describing: error.errorDescription))", type: .error)
            }
        }
    }
    
    public func callerConfirmAnswer(callId: String,calleeId: String,calleeDeviceId: String,result: String) {
        if callId.isEmpty || calleeId.isEmpty || calleeDeviceId.isEmpty || result.isEmpty {
            consoleLogInfo("Invalid parameters for confirming answer: callId: \(callId), calleeId: \(calleeId), calleeDeviceId: \(calleeDeviceId), result: \(result)", type: .error)
            return
        }
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: kConfirmCalleeAction,
            kCallId: callId,
            kCalleeDevId: calleeDeviceId,
            kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kCallResult: result,
            kTs: Int(Date().timeIntervalSince1970 * 1000) // Timestamp in milliseconds
        ]
        if !json.isEmpty {
            ext.merge(json) { _, new in
                new
            }
        }
        let message = ChatMessage(conversationID: calleeId, body: ChatCMDMessageBody(action: kCall), ext: ext)
        message.deliverOnlineOnly = true
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                self.handleError(error)
                self.callInfo?.state = .idle
                consoleLogInfo("Failed to send confirm answer message: \(String(describing: error.errorDescription))", type: .error)
            }
        }
    }
    
    public func hangup() {
        if let call = self.callInfo {
            switch call.state {
            case .answering:
                self.updateCallEndReason(.hangup)
                for listener in self.listeners.allObjects {
                    listener.didEndCall?(callId: call.callId, endReason: .hangup, error: nil,duration: call.duration)
                }
            case .dialing:
                self.updateCallEndReason(.cancel)
                self.player?.stop()
                self.cancelCall(callId: call.callId, calleeId: call.calleeId)
                for listener in self.listeners.allObjects {
                    listener.didEndCall?(callId: call.callId, endReason: .cancel, error: nil, duration: 0)
                }
            case .ringing:
                self.updateCallEndReason(.refuse)
                self.player?.stop()
                self.answerCall(callId: call.callId, callerId: call.callerId, result: kRefuseResult, callerDeviceId: call.callerDeviceId)
                for listener in self.listeners.allObjects {
                    listener.didEndCall?(callId: call.callId, endReason: .refuse, error: nil, duration: 0)
                }
            default:
                break
            }
            self.quitCall()
        }
    }
    
    public func accept() {
        self.player?.stop()
        if let call = self.callInfo {
            let joinResult = self.joinChannel(channelName: call.channelName)
            if !joinResult {
                consoleLogInfo("Failed to join channel with error code: \(joinResult)", type: .error)
                return
            }
            if call.type == .singleVideo {
                self.setupLocalVideo()
            } else {
                self.enableLocalVideo(false)
            }
            self.answerCall(callId: call.callId, callerId: call.callerId, result: kAcceptResult, callerDeviceId: call.callerDeviceId)
        }
    }
    
    private func convertCallTypeString(_ type: CallType) -> String {
        var callTypeString = ""
        switch type {
        case .singleAudio:
            callTypeString = "singleAudio".call.localize
        case .singleVideo:
            callTypeString = "singleVideo".call.localize
        case .multiCall:
            callTypeString = "multiCall".call.localize
        default:
            break
        }
        return callTypeString
    }
    
    func joinChannel(channelName: String) -> Bool {
        self.engine?.enableInstantMediaRendering()
        var joinResult = false
        if let call = self.callInfo,call.state == .answering {
            let leaveResult = self.engine?.leaveChannel()
            if leaveResult != 0 {
                consoleLogInfo("leaveChannel result: \(String(describing: leaveResult)) channelName:\(channelName)", type: .error)
            }
        }
        let config = AgoraRtcChannelMediaOptions()
        config.autoSubscribeAudio = true
        config.autoSubscribeVideo = true
        config.publishCameraTrack = true
        config.publishMicrophoneTrack = true
        config.clientRoleType = .broadcaster
        config.channelProfile = .liveBroadcasting
        let token = ChatClient.shared().accessUserToken ?? ""
        let currentUser = ChatClient.shared().currentUsername ?? ""
        let result = self.engine?.joinChannel(byToken: nil, channelId: channelName, userAccount: currentUser, mediaOptions: config, joinSuccess: { [weak self] channel, uid, elapsed in
            guard let `self` = self else { return  }
            
            var errorCode: AgoraErrorCode = .noError // Initialize with default success value
            let userInfo = withUnsafeMutablePointer(to: &errorCode) { errorPtr in
                self.engine?.getUserInfo(byUid: uid, withError: errorPtr)
            }
            self.joinChannelName = channel
            consoleLogInfo("\(currentUser) joined channel: \(channel) with uid: \(uid) elapsed: \(elapsed): account \(userInfo?.userAccount ?? "")", type: .debug)
            UIApplication.shared.isIdleTimerDisabled = true
            if let call = self.callInfo {
                switch call.type  {
                case .singleVideo:
                    self.engine?.enableVideo()
                case .singleAudio:
                    self.engine?.enableAudio()
                case .multiCall:
                    self.setupLocalVideo()
                default:
                    break
                }
            }
            GlobalTimerManager.shared.registerListener(self, timerIdentify: "call-\(channel)-answering-timer")
            joinResult = true
        }) ?? 0
        if result != 0 {
            consoleLogInfo("\(currentUser) failed to join channel: \(channelName) error code: \(result) token:\(token)", type: .error)
            GlobalTimerManager.shared.invalidate()
            for listener in self.listeners.allObjects {
                listener.didOccurError?(CallError.error(code: Int(result), message: "Failed to join channel: \(channelName) error code: \(result)"))
            }
        } else {
            joinResult = true
            consoleLogInfo("\(currentUser) successfully joined channel: \(channelName)", type: .debug)
            GlobalTimerManager.shared.registerListener(self, timerIdentify: "call-\(channelName)-answering-timer")
        }
        return joinResult
    }
    
    func quitCall() {
        if self.callInfo != nil {
            GlobalTimerManager.shared.invalidate()
            UIApplication.shared.isIdleTimerDisabled = false
            self.callVC?.dismiss(animated: false)
            self.callVC = nil
            self.isVideoExchanged = false
            self.alreadyVideoSetup = false
            FloatingAudioView.removeFromWindow()
            let result = self.engine?.leaveChannel()
            consoleLogInfo("quitCall leaveChannel result: \(String(describing: result))", type: .debug)
            self.engine?.stopPreview()
            self.engine?.disableVideo()
            self.engine?.disableAudio()
            self.callInfo?.callId = ""
            self.callInfo?.callerId = ""
            self.callInfo?.callerDeviceId = ""
            self.callInfo?.calleeId = ""
            self.callInfo?.calleeDeviceId = ""
            self.callInfo?.channelName = ""
            self.callInfo?.groupId = nil
            self.callInfo?.groupName = nil
            self.callInfo?.groupAvatar = nil
            self.callInfo?.inviteMessageId = ""
            self.cleanUICache()
            self.callInfo?.calleeDeviceId = ""
            self.callInfo?.extensionInfo = nil
            self.callInfo?.state = .idle
            self.callInfo?.duration = 0
            
        }
    }
    
    fileprivate func startInvitationSignalTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-invitation-signal-timer"
        GlobalTimerManager.shared.registerListener(self, timerIdentify: timerIdentify)
    }
    
    fileprivate func stopInvitationSignalTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-invitation-signal-timer"
        GlobalTimerManager.shared.removeTimeAsSimilarKey(timerIdentify)
        GlobalTimerManager.shared.removeListener(self, timerIdentify: timerIdentify)
        consoleLogInfo("stopInvitationSignalTimer", type: .debug)
    }
    
    fileprivate func startConfirmBuildConnectionTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-confirm-build-connection-timer"
        GlobalTimerManager.shared.registerListener(self, timerIdentify: timerIdentify)
    }
    
    fileprivate func stopConfirmBuildConnectionTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-confirm-build-connection-timer"
        GlobalTimerManager.shared.removeTimeAsSimilarKey(timerIdentify)
        GlobalTimerManager.shared.removeListener(self, timerIdentify: timerIdentify)
        consoleLogInfo("stopConfirmBuildConnectionTimer", type: .debug)
    }
    
    func startRingTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-ring-timer"
        GlobalTimerManager.shared.registerListener(self, timerIdentify: timerIdentify)
    }
    
    func stopRingTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-ring-timer"
        GlobalTimerManager.shared.removeTimeAsSimilarKey(timerIdentify)
        GlobalTimerManager.shared.removeListener(self, timerIdentify: timerIdentify)
        consoleLogInfo("stopRingTimer", type: .debug)
    }
    
    fileprivate func callStartTimerStart(callId: String) {
        let timerIdentify = "call-\(callId)-start-timer"
        GlobalTimerManager.shared.registerListener(self, timerIdentify: timerIdentify)
    }
    
    fileprivate func callStartTimerStop(callId: String) {
        let timerIdentify = "call-\(callId)-start-timer"
        GlobalTimerManager.shared.removeTimeAsSimilarKey(timerIdentify)
        GlobalTimerManager.shared.removeListener(self, timerIdentify: timerIdentify)
    }
}

//MARK: - Time changed
extension CallKitManager: TimerServiceListener {
    public func timeChanged(_ timerIdentify: String, interval seconds: UInt) {
        guard let call = self.callInfo else { return }
        print("CallKitManager timeChanged: \(timerIdentify) seconds: \(seconds)")
        let startInvitationSignalTimer = "call-\(call.callId)-start-invitation-signal-timer"
        let startConfirmBuildConnectionTimer = "call-\(call.callId)-start-confirm-build-connection-timer"
        let callStartTimerKey = "call-\(call.callId)-start-timer"
        let timerIdentifyRing = "call-\(call.callId)-start-ring-timer"
        let answeringTimerKey = "call-\(call.channelName)-answering-timer"
        switch timerIdentify {
        case timerIdentifyRing:
            if seconds >= ringingTimeout {
                self.stopRingTimer(callId: call.callId)
                self.cancelCall(callId: call.callId, calleeId: call.calleeId)
                self.ringTimeout()
                self.updateCallEndReason(.remoteNoResponse)
                if let vc = UIViewController.currentController {
                     if vc is Call1v1AudioViewController || vc is Call1v1VideoViewController {
                        vc.dismiss(animated: true)
                    }
                }
                if FloatingAudioView.isFloatingViewVisible() {
                    FloatingAudioView.removeFromWindow()
                }
                self.popup?.dismiss()
            }
        case startInvitationSignalTimer:
            if seconds >= callTimeout,call.calleeId == ChatClient.shared().currentUsername ?? "" {
                self.updateCallEndReason(.remoteNoResponse)
                self.stopInvitationSignalTimer(callId: call.callId)
                self.callInfo?.state = .idle
                self.player?.stop()
                for listener in self.listeners.allObjects {
                    listener.didEndCall?(callId: call.callId, endReason: .noResponse, error: nil, duration: 0)
                }
            }
        case startConfirmBuildConnectionTimer:
            if seconds >= callTimeout {
                self.stopConfirmBuildConnectionTimer(callId: call.callId)
                self.callInfo?.state = .idle
                self.player?.stop()
                for listener in self.listeners.allObjects {
                    listener.didEndCall?(callId: call.callId, endReason: .noResponse, error: nil, duration: 0)
                }
            }
        case answeringTimerKey:
            if call.state == .answering {
                self.callInfo?.duration = seconds
                if let floating = UIApplication.shared.call.keyWindow?.viewWithTag(floatingViewTag) as? FloatingAudioView,!floating.isHidden {
                    floating.updateSeconds(seconds: Int(seconds))
                }
                if seconds%updateDuration == 0 {
                    if let messageId = self.callInfo?.inviteMessageId,let message = ChatClient.shared().chatManager?.getMessageWithMessageId(messageId) {
                        let ext = message.ext ?? [:]
                        var newExt = ext
                        newExt[kCallDuration] = seconds
                        message.ext = newExt
                        Task {
                            let result = await ChatClient.shared().chatManager?.update(message)
                            if let error = result?.1 {
                                consoleLogInfo("Failed to update call duration: \(String(describing: error.errorDescription))", type: .error)
                            }
                        }
                    }
                }
            }
            
        default:
            
            if timerIdentify.contains(" users:") {
                if seconds >= ringingTimeout {
                    if call.type == .multiCall {
                        if let currentVC = UIViewController.currentController as? CallMultiViewController {
                            let inviteGroupUserTimerKeys = GlobalTimerManager.shared.timerCache.keys.filter { $0.components(separatedBy: " users:").count > 0 }
                            var removeUsers: [String] = []
                            let currentUserId = ChatClient.shared().currentUsername ?? ""
                            for key in inviteGroupUserTimerKeys {
                                if timerIdentify == key,seconds >= ringingTimeout {
                                    let users = key.components(separatedBy: " users:").last?.components(separatedBy: "-") ?? [].filter({ $0 != "start" && $0 != "timer" })
                                    for userId in users {
                                        if let item = self.itemsCache[userId],item.waiting {
                                            if currentUserId != userId {
                                                removeUsers.append(userId)
                                                self.itemsCache.removeValue(forKey: userId)
                                                self.cancelCall(callId: call.callId, calleeId: userId)
                                            }
                                        }
                                    }
                                }
                            }
                            if !removeUsers.isEmpty {
                                currentVC.callView.updateWithItems(removeUsers)
                            }
                            self.callInfo?.calleeId = ""
                            GlobalTimerManager.shared.removeTimeAsSimilarKey(timerIdentify)
                        }
                    }
                }
            }
            
            break
        }
    }
    
    
}
