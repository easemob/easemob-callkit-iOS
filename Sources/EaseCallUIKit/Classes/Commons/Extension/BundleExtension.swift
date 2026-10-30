//
//  BundleExtension.swift
//  CallUIKit
//
//  Created by 朱继超 on 2023/8/30.
//

import Foundation

public extension Bundle {
    /// The custom resource bundle, or the packaged CallResource.bundle for the integration method.
    class var callBundle: Bundle {
        if CallAppearance.resourceBundle != nil {
            return CallAppearance.resourceBundle!
        } else {

#if COCOAPODS
            return Bundle(for: CallAppearance.self)
                .url(forResource: "EaseCallUIKit.bundle/CallResource", withExtension: "bundle")
                .flatMap { Bundle(url: $0) }!
#elseif SWIFT_PACKAGE
            return Bundle.module
                .url(forResource: "CallResource", withExtension: "bundle")
                .flatMap(Bundle.init(url:))!
#elseif STATIC_LIBRARY
            return Bundle.main
                .url(forResource: "EaseCallUIKit.bundle/CallResource", withExtension: "bundle")
                .flatMap(Bundle.init(url:))!
#else
        return Bundle(for: CallAppearance.self)
#endif
        }
    }
}
