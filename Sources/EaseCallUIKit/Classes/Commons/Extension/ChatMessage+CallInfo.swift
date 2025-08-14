//
//  ChatMessage+CallInfo.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 7/31/25.
//

import Foundation

public extension ChatMessage {
    var callInfo: CallInfo? {
        if let ext = self.ext as? [String: Any] {
            guard let msgType = ext[kMsgType] as? String,
                  let callId = ext[kCallId] as? String,
                  let callerDevId = ext[kCallerDevId] as? String
            else {
                consoleLogInfo("Get info invalid call info in message id:\(self.messageId) : \(String(describing: self.ext))", type: .error)
                return nil
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
                    profile.id = self.from
                }
                if CallKitManager.shared.usersCache[profile.id] == nil {
                    CallKitManager.shared.usersCache[profile.id] = profile
                } else {
                    CallKitManager.shared.usersCache[profile.id]?.nickname = profile.nickname
                    CallKitManager.shared.usersCache[profile.id]?.avatarURL = profile.avatarURL
                }
            }
            let callInfo = CallInfo(callId: callId, callerId: callerDevId, callerDeviceId: callerDevId, channelName: channelName, type: callType)
            callInfo.state = isValid ? .ringing : .idle
            callInfo.extensionInfo = callExtension
            callInfo.groupId = groupId
            callInfo.groupName = groupName
            callInfo.groupAvatar = groupAvatar
            callInfo.duration = ext[kCallDuration] as? UInt ?? 0
            return callInfo
        }
        return nil
    }
    
}
