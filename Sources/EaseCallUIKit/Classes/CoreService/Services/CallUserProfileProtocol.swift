//
//  CallUserProfileProtocol.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 6/25/25.
//

import Foundation

// Profile of the EaseCallUIKit display needed.
@objc public protocol CallUserProfileProtocol: NSObjectProtocol {
    var id: String {set get}
    var remark: String {set get}
    var selected: Bool {set get}
    var nickname: String {set get}
    var avatarURL: String {set get}
    
    func toJsonObject() -> Dictionary<String,Any>?
}

@objcMembers open class CallUserProfile:NSObject, CallUserProfileProtocol {
    public var remark: String = ""
    
    public func toJsonObject() -> Dictionary<String, Any>? {
        [kUserInfo:["nickname":self.nickname,"avatarURL":self.avatarURL,"userId":self.id]]
    }
    
    
    public var id: String = ""
    
    public var avatarURL: String = ""
    
    public var nickname: String = ""
        
    public var selected: Bool = false
    
    public var modifyTime: Int64 = 0
    
    public var videoEnabled: Bool = false
    
    public var audioEnabled: Bool = false
    
    public var isTalking: Bool = false
    
    public override func setValue(_ value: Any?, forUndefinedKey key: String) {
        
    }
        
}

