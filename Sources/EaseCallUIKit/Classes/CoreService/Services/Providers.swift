//
//  Providers.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 7/7/25.
//

import Foundation

/// Profile provider of the ChatUIKit.Only available in Swift language.
public protocol CallUserProfileProvider {
    
    /// Coroutine obtains user information asynchronously.
    /// - Parameter profileIds: The corresponding conversation id string array.
    /// - Returns: Array of the conform``ChatUserProfileProtocol`` object.
    func fetchProfiles(profileIds: [String]) async -> [CallUserProfileProtocol]
}

/// /// Profile provider of the ChatUIKit.Only available in Objective-C language.
@objc public protocol CallUserProfileProviderOC: NSObjectProtocol {
    
    /// Need to obtain the list display information on the current screen.
    /// - Parameters:
    ///   - profileIds: The corresponding conversation id string array.
    ///   - completion: Callback,obtain Array of the ``ChatUserProfileProtocol`` object.
    func fetchProfiles(profileIds: [String],completion: @escaping ([CallUserProfileProtocol]) -> Void)
}

public protocol CallTokenProvider {
    /// Coroutine obtains call token asynchronously.
    /// - Parameter channelName: The channel name for the call.
    /// - Parameter userId: The user ID for which the token is requested.
    /// - Returns: A tuple containing the token and expiration time.
    func fetchCallToken(channelName: String,userId: String) async -> (token: String?, expireTime: Int64)
}

public protocol CallTokenProviderOC: NSObjectProtocol {
    /// Need to obtain the call token.
    /// - Parameters:
    ///   - channelName: The channel name for the call.
    ///   - userId: The user ID for which the token is requested.
    ///   - completion: Callback,obtain a tuple containing the token and expiration time.
    func fetchCallToken(channelName: String,userId: String,completion: @escaping (String?, Int64) -> Void)
}
