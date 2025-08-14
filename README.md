
# EaseCallUIKit for iOS

本指南将介绍环信新EaseCallUIKit（V4.16.0）。新EaseCallUIKit致力于为开发者提供高效集成、功能全面、设计美观的通话场景，轻松满足即时通信呼叫绝大多数场景。请下载示例进行体验。

# 示例Demo

在本项目中，“Example”文件夹中有一个最佳实践演示项目，供您构建自己的业务能力。

如需体验EaseCallUIKit的完整功能（包含LiveCommunicationKit），您可以扫描以下二维码试用demo。

![Demo](./Documentation/demo.png)

# CallKit 指南

## 简介

本指南介绍了 EaseCallUIKit 框架在 iOS 开发中的概述和使用示例
- EaseCallUIKit支持的通话类型（音频通话、视频通话、群组通话）必须与环信IM SDK一起使用

## 目录

- [示例Demo](#示例demo)
- [开发环境](#开发环境)
- [安装](#安装)
  - [CocoaPods](#cocoapods)
- [结构](#结构)
- [运行示例项目](#运行示例项目)
- [快速开始](#快速开始)
  - [第一步：初始化EaseCallUIKit](#第一步初始化easecalluikit)
  - [第二步：登录IM SDK](#第2步登录im-sdk)
  - [第三步：实现呼叫功能](#第三步写一个呼叫按钮一个呼叫人userid输入框)
- [集成文档](#集成文档)
  - [1.初始化EaseCallUIKit（进阶）](#1初始化easecalluikit)
  - [2.登录](#2登录)
  - [3.Provider配置](#3easecalluikit中的provider)
  - [4.创建呼叫页面并调用呼叫Api](#4创建呼叫页面并调用呼叫api)
  - [5.监听事件和错误](#5监听easecalluikit事件和错误)
- [自定义](#自定义)
  - [1.修改UI可配置项](#1修改ui可配置项)
  - [2.修改资源原有](#2修改资源原有)
  - [3.修改业务可配置项](#3修改业务可配置项)
  - [4.如果想进一步修改业务逻辑，请源码集成后修改](#4如果想进一步修改业务逻辑请源码集成后修改)
- [文档](#文档)
- [设计指南](#设计指南)
- [贡献](#贡献)
- [许可证](#许可证)
- [更新日志](#更新日志)

# 开发环境

- Xcode 16.0及以上版本 
- 最低支持系统：iOS 14.0
- 请确保您的项目已设置有效的开发者签名
- cocoapods v1.14.3 above

# 安装

您可以使用 CocoaPods 安装 EaseCallUIKit 作为 Xcode 项目的依赖项。

## CocoaPods

在podfile中添加如下依赖

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '14.0'

target 'YourTarget' do
  use_frameworks!

  pod 'EaseCallUIKit'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
    end
  end
end
```

然后cd到终端下podfile所在文件夹目录执行

```
    pod install
```

>⚠️Xcode15编译报错 ```Sandbox: rsync.samba(47334) deny(1) file-write-create...```

> 解决方法: Build Setting里搜索 ```ENABLE_USER_SCRIPT_SANDBOXING```把```User Script Sandboxing```改为```NO```

> 如果`pod install`失败报错 RuntimeError - `PBXGroup` attempted to initialize an object with unknown ISA `PBXFileSystemSynchronizedRootGroup` from attributes: `{"isa"=>"PBXFileSystemSynchronizedRootGroup"`，请尝试升级pod版本为1.14.3
 Xcode16及其以下版本打开会报错 `Adjust the project format using a compatible version of Xcode to allow it to be opened by this version of Xcode.`

# 结构

### EaseCallUIKit 基本项目结构

```
Classes
├─ CoreService // 核心协议层以及定义。
│ ├─ Provider //EaseCallUIKit 用户信息获取缓存等。
│ ├─ Service // 业务协议。
│ │ ├─ `CallMessageService` // 呼叫api以及部分回调，以及常量枚举定义。
│ └─ Implements // 上面对应协议的实现组件。核心`CallKitManager`实现，分别为扩展处理`CallKitManager+Signaling.swift`、`CallKitManager+RTC.swift`等
├─ Resource // 图像或本地化文件。
├─ Commons
       ├─ Utils // 一些CallKitManager用到的工具类（AudioPlayerManager、LiveCommunicationManager、GlobalTimerManager）以及相关UI类。
       ├─ Appearance // UI以及资源配置相关。
       ├─ ConsoleLog // 日志打印相关。
       ├─ Theme // 主题相关组件，包括颜色、字体、换肤协议及其组件。
       └─ Extension // 一些方便的系统类扩展。
│
└─ UI // 基本UI组件，不带业务。
    ├─ Controllers // 视图控制器。
    ├─ Views // 所有UIView。
    └─ Cells // 所有UITableViewCell。
```
# 运行示例项目

- [注册环信AppKey](https://docs-im-beta.easemob.com/product/enable_and_configure_IM.html#%E8%8E%B7%E5%8F%96%E7%8E%AF%E4%BF%A1%E5%8D%B3%E6%97%B6%E9%80%9A%E8%AE%AF-im-%E7%9A%84%E4%BF%A1%E6%81%AF)
- [开通RTC功能](./DocumentationImages/open_rtc.png)

- 在Appdelegate.swift 中找到
```Swift
let option = ChatOptions(appkey: <#环信AppKey#>)
```
将注册的AppKey填入其中。
- 如果想要自定义的头像昵称显示信息，在ViewController.swift中找到loginAction方法后填入您要显示的当前用户id对应的昵称头像`profile.nickname` `profile.avatarURL`信息即可，然后运行项目即可，出现登录界面后需要您去创建用户以及获取用户token // 。 [使用控制台生成的临时Token登录](https://docs-im-beta.easemob.com/product/enable_and_configure_IM.html#%E5%88%9B%E5%BB%BA-im-%E7%94%A8%E6%88%B7)，将用户名以及token复制粘贴填写在输入框中->然后点击登录->选择呼叫类型->输入呼叫用户的userId->点击呼叫


# 快速开始

本指南提供了不同 EaseCallUIKit 组件的多个使用示例。 请参阅“示例”文件夹以获取显示各种用例的详细代码片段和项目。

参考以下步骤在 Xcode 中创建一个 iOS 平台下的App，创建设置如下：

* Product Name 填入EaseCallUIKitQuickStart。
* Organization Identifier 设为 您的identifier。
* User Interface 选择 Storyboard。
* Language 选择 你的常用开发语言。
* 添加权限 在项目 `info.plist` 中添加相关权限：

Add related privileges in the `info.plist` project:

```
Privacy - Photo Library Usage Description //相册权限    Album privileges.
Privacy - Microphone Usage Description //麦克风权限     Microphone privileges.
Privacy - Camera Usage Description //相机权限    Camera privileges.
```

- 如要配置画中画，[PictureInPicture.md](./PictureInPicture.md)。
- 如要配置LiveCommunicationKit，[LiveCommunicationKit.md](./LiveCommunicationKit.md)。

### 第一步：初始化EaseCallUIKit

```Swift
import EaseCallUIKit

@UIApplicationMain
class AppDelegate：UIResponder，UIApplicationDelegate {

     var window: UIWindow？

     func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
         // 您可以在应用程序加载时或使用之前初始化 EaseCallUIKit。
         // 需要传入App Key。
         // 获取App Key，请访问
         // https://docs-im-beta.easemob.com/product/enable_and_configure_IM.html#%E8%8E%B7%E5%8F%96%E7%8E%AF%E4%BF%A1%E5%8D%B3%E6%97%B6%E9%80%9A%E8%AE%AF-im-%E7%9A%84%E4%BF%A1%E6%81%AF
        let option = ChatSDKOptions(appkey: AppKey)//首先需要登录SDK
        option.enableConsoleLog = true//开启日志
        option.isAutoLogin = false//此处只是示例项目，真实使用时参考环信Demo源码，自动登录更方便
        ChatClient.shared().initializeSDK(with: option)//初始化SDK
        CallKitManager.shared.setup()//初始化EaseCallUIKit
     }
}
```

### 第2步：登录IM SDK

``` Swift
        ChatClient.shared().login(withUsername: userId, token: token) { [weak self] userId,error  in
            if let error = error {
                self?.showCallToast(toast: "Login failed: \(error.errorDescription ?? "")")
            } else {
                self?.showCallToast(toast: "Login successful")
//if !userId.isEmpty { //如有需要透传头像昵称请打开
//    let profile = CallUserProfile()
//    profile.id = userId
//    profile.avatarURL = "https://xxxxx"
//    profile.nickname = "\(userId)昵称"
//    CallKitManager.shared.currentUserInfo = profile
//}
                self?.userIdField.isHidden = true
                self?.tokenField.isHidden = true
                self?.loginButton.isHidden = true 
            }
        }
// token生成参见快速开始中登录步骤中链接。
// 需要从您的应用服务器获取token。 您也可以使用控制台生成的临时Token登录。
// 在控制台生成用户和临时用户 token，请参见
// https://docs-im-beta.easemob.com/product/enable_and_configure_IM.html#%E5%88%9B%E5%BB%BA-im-%E7%94%A8%E6%88%B7。
```

### 第三步：写一个呼叫按钮一个呼叫人userId输入框

```Swift
        // 在Console中创建一个新用户，新用户使用一样的快速开始工程登录后，将这个用id复制后传入下面构造方法参数中，跳转页面即可。
        func callAction(type: CallType) {
                
            guard let input = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
                self.showCallToast(toast: "Please enter a valid username or group id")
                return
            }
            if type != .groupCall {
                CallKitManager.shared.call(with: input, type: type)
            } else {
                CallKitManager.shared.groupCall(groupId: input)
            }
        }

```

# 集成文档

以下是进阶用法的部分示例。会话列表页面、消息列表页、联系人列表均可分开使用。

## 1.初始化EaseCallUIKit
相比于上面快速开始的EaseCallUIKit初始化这里多了ChatOptions的参数，主要是对SDK中是否打印log以及是否自动登录，是否默认使用用户属性的开关配置。ChatOptions即IMSDK的Option类，内中有诸多开关属性可参见环信官网IMSDK文档
```Swift
    private func setupCallKit() {
        //初始化环信CallKit
        let config = EaseCallUIKit.CallKitConfig()
        config.enableVOIP = true//开启voip功能后会自动开启LiveCommunicationKit，需要在develop.apple.com申请证书时勾选
        config.enablePIPOn1V1VideoScene = true//开启画中画，同时需要开启应用后台摄像头采集权限，详见[PictureInPicture.md](./PictureInPicture.md)。
        CallKitManager.shared.setup(config)
    }
```

## 2.登录

```Swift
            ChatClient.shared().login(withUsername: userId, token: token) { [weak self] userId,error  in
            if let error = error {
                self?.showCallToast(toast: "Login failed: \(error.errorDescription ?? "")")
            } else {
                self?.showCallToast(toast: "Login successful")
//if !userId.isEmpty { //如有需要透传头像昵称请打开
//    let profile = CallUserProfile()
//    profile.id = userId
//    profile.avatarURL = "https://xxxxx"
//    profile.nickname = "\(userId)昵称"
//    CallKitManager.shared.currentUserInfo = profile
//}
                self?.userIdField.isHidden = true
                self?.tokenField.isHidden = true
                self?.loginButton.isHidden = true 
            }
        }
// token生成参见快速开始中登录步骤中链接。
// 需要从您的应用服务器获取token。 您也可以使用控制台生成的临时Token登录。
// 在控制台生成用户和临时用户 token，请参见
// https://docs-im-beta.easemob.com/product/enable_and_configure_IM.html#%E5%88%9B%E5%BB%BA-im-%E7%94%A8%E6%88%B7。
```

## 3.EaseCallUIKit中的Provider

- 注: 仅用于会话列表以及联系人列表,在只是用快速开始进入聊天页面时不需要实现Provider

Provider是一个数据提供者，当会话列表展示并且滑动减速时候，EaseCallUIKit会向你请求一些当前屏幕上要显示会话的展示信息例如头像昵称等。下面是Provider的具体示例以及用法。

```Swift
        CallKitManager.shared.profileProvider = self//Swift
        //CallKitManager.shared.profileProviderOC = self//OC 与上面profileProvider二者只能设置一个
        CallKitManager.shared.addListener(self)//添加监听，均为可选方法

//MARK: - CallUserProfileProvider 
//For example using conversations controller,as follows.
extension MainViewController: CallUserProfileProvider {
    func fetchGroupProfiles(profileIds: [String]) async -> [any EaseCallUIKit.CallProfileProtocol] {
        consoleLogInfo("fetchGroupProfiles", type: .error)
        return await withTaskGroup(of: [EaseCallUIKit.CallProfileProtocol].self, returning: [EaseCallUIKit.CallProfileProtocol].self) { group in
            var resultProfiles: [EaseCallUIKit.CallProfileProtocol] = []
            group.addTask {
                var resultProfiles: [EaseCallUIKit.CallProfileProtocol] = []
                let result = await self.requestGroupsInfo(groupIds: profileIds)
                if let infos = result {
                    for groupInfo in infos {
                        let profile = EaseCallUIKit.CallUserProfile()
                        profile.id = groupInfo.id
                        profile.nickname = groupInfo.nickname
                        profile.avatarURL = groupInfo.avatarURL
                        resultProfiles.append(profile)
                    }
                }
                return resultProfiles
            }
            //Await all task were executed.Return values.
            for await result in group {
                resultProfiles.append(contentsOf: result)
            }
            return resultProfiles
        }
    }
    
    func fetchUserProfiles(profileIds: [String]) async -> [any EaseCallUIKit.CallProfileProtocol] {
        return await withTaskGroup(of: [EaseCallUIKit.CallProfileProtocol].self, returning: [EaseCallUIKit.CallProfileProtocol].self) { group in
            var resultProfiles: [EaseCallUIKit.CallProfileProtocol] = []
            group.addTask {
                var resultProfiles: [EaseCallUIKit.CallProfileProtocol] = []
                let result = await self.requestUserInfos(profileIds: profileIds) ?? []
                for userInfo in result {
                    let profile = EaseCallUIKit.CallUserProfile()
                    profile.id = userInfo.id
                    profile.nickname = userInfo.nickname
                    profile.avatarURL = userInfo.avatarURL
                    resultProfiles.append(profile)
                }
                return resultProfiles
            }
            //Await all task were executed.Return values.
            for await result in group {
                resultProfiles.append(contentsOf: result)
            }
            return resultProfiles
        }
    }
    
    private func requestUserInfos(profileIds: [String]) async -> [ChatUserProfileProtocol]? {
        var unknownIds = [String]()
        var resultProfiles = [ChatUserProfileProtocol]()
        for profileId in profileIds {
            if let profile = ChatUIKitContext.shared?.userCache?[profileId] {
                if profile.nickname.isEmpty {
                    unknownIds.append(profile.id)
                } else {
                    resultProfiles.append(profile)
                }
            } else {
                unknownIds.append(profileId)
            }
        }
        if unknownIds.isEmpty {
            return resultProfiles
        }
        let result = await ChatClient.shared().userInfoManager?.fetchUserInfo(byId: unknownIds)
        if result?.1 == nil,let infoMap = result?.0 {
            for (userId,info) in infoMap {
                let profile = ChatUserProfile()
                let nickname = info.nickname ?? ""
                profile.id = userId
                profile.nickname = nickname
                if let remark = ChatClient.shared().contactManager?.getContact(userId)?.remark {
                    profile.remark = remark
                }
                profile.avatarURL = info.avatarUrl ?? ""
                resultProfiles.append(profile)
                if (ChatUIKitContext.shared?.userCache?[userId]) != nil {
                    profile.updateFFDB()
                } else {
                    profile.insert()
                }
                ChatUIKitContext.shared?.userCache?[userId] = profile
            }
            return resultProfiles
        }
        return []
    }
    
    private func requestGroupsInfo(groupIds: [String]) async -> [ChatUserProfileProtocol]? {
        var resultProfiles = [ChatUserProfileProtocol]()
        let groups = ChatClient.shared().groupManager?.getJoinedGroups() ?? []
        for groupId in groupIds {
            if let group = groups.first(where: { $0.groupId == groupId }) {
                let profile = ChatUserProfile()
                profile.id = groupId
                profile.nickname = group.groupName
                profile.avatarURL = group.settings.ext
                resultProfiles.append(profile)
                ChatUIKitContext.shared?.groupCache?[groupId] = profile
            }

        }
        return resultProfiles
    }
}
```

## 4.创建呼叫页面并调用呼叫Api

- 页面随用户自行创建即可，可以给AI说明我需要一个呼叫页面名字叫XXX，然后页面中有一个输入框输入呼叫人userId，一个segment选择器选择呼叫类型，一个按钮点击后进行呼叫。待AI给出代码后复制粘贴即可

```Swift 
        //在需要呼叫的页面中调用下面方法即可
        CallKitManager.shared.call(with: input, type: type)//type为CallType枚举类型，详见CallMessageService.swift
        //如果是群组通话则调用下面方法
        CallKitManager.shared.groupCall(groupId: input)
```

## 5.监听EaseCallUIKit事件和错误

您可以调用下面方法来监听 EaseCallUIKit中用户相关状态变更的事件和错误。

```Swift        
        CallKitManager.shared.addListener(self)//添加监听，均为可选方法
```
下面是监听事件的示例代码。
```Swift 
extension MainViewController: CallServiceListener {
    
    func didOccurError(error: CallError) {
        DispatchQueue.main.async {
            self.showToast(toast: "Occur error:\(error.errorMessage) on module:\(error.module.rawValue)")
        }
        switch error { //Swift error handler
        case .im(.invalidURL):
            print("Invalid URL")
        case .rtc(.invalidToken):
            print("Invalid Token")
        case .business(.state):
            print("State error")
        case .business(.param):
            print("Param error")
        default:
            // 注意这里要通过 error.error.message 访问
            print("Other error: \(error.error.message)")
        }
//        switch error.module {//OC error handler
//        case .im:
//            switch error.getIMError() {
//            case .invalidURL:
//                print("")
//            default:
//                break
//            }
//        case .rtc:
//            switch error.getRTCError() {
//            case .invalidToken:
//                print("")
//            default:
//                break
//            }
//        case .business:
//            switch error.getCallBusinessError() {
//            case .state:
//                print("")
//            case .param:
//                print("")
//            case .signaling:
//                print("")
//            default:
//                break
//            }
//        default:
//            break
//        }
    }
        
    func didUpdateCallEndReason(reason: CallEndReason, info: CallInfo) {
        print("didUpdateCallEndReason: \(String(describing: info.inviteMessage?.ext))")
        if let message = info.inviteMessage {
            NotificationCenter.default.post(name: Notification.Name("didUpdateCallEndReason"), object: message)
        }
        
    }
    
    func remoteUserDidJoined(userId: String, uid: UInt, channelName: String, type: CallType) {
        
    }
    
    func remoteUserDidLeft(userId: String, uid: UInt, channelName: String, type: CallType) {
        
    }
    
}
```

# 自定义

## 1.修改UI可配置项

下面示例展示如何更改消息内容显示

```Swift
        // 改变头像圆角
        CallAppearance.avatarRadius = .extraSmall
        // 改变头像占位图
        CallAppearance.avatarPlaceHolder = UIImage(named: "avatar_placeholder")
        //整体替换资源bundle
        CallAppearance.resourceBundle = Bundle.main
        //替换聊天背景图
        CallAppearance.backgroundImage = UIImage(named: "chat_background")
```

## 2.修改资源原有
[资源图](./DocumentationImages/resource_replace.png)
[资源图1](./DocumentationImages/resource_replace1.png)


## 3.修改业务可配置项
```Swift
        let config = EaseCallUIKit.CallKitConfig()
        config.enableVOIP = true //开启voip功能后会自动开启LiveCommunicationKit，需要在develop.apple.com申请证书时勾选
        config.enablePIPOn1V1VideoScene = true //开启画中画，同时需要开启应用后台摄像头采集权限，详见[PictureInPicture.md](./PictureInPicture.md)。
        config.ringTimeOut = 30//默认呼叫超时时间
        CallKitManager.shared.setup(config)
```

4.如果想进一步修改业务逻辑，请源码集成后修改

# 文档

## [文档](/Documentation/EaseCallUIKit.doccarchive)

您可以在 Xcode 中打开“EaseCallUIKit.doccarchive”文件来查看其中的文件。

另外，您可以右键单击该文件以显示包内容并将其中的所有文件复制到一个文件夹中。 然后将此文件夹拖到“terminal”应用程序中并运行以下命令将其部署到本地IP地址上。

```bash
python3 -m http.server 8080
```

部署完成后，您可以在浏览器中访问 http://yourlocalhost:8080/documentation/EaseCallUIKit   其中`yourlocalhost`是您的本地IP地址。 或者，您可以将此文件夹部署在外部网络地址上。


# 设计指南

如果您对设计指南和细节有任何疑问，您可以在 Figma 设计稿中添加评论并提及我们的设计师 Stevie Jiang。

参见[设计图](https://www.figma.com/community/file/1327193019424263350/chat-uikit-for-mobile)。

请参阅[UI设计指南](https://github.com/StevieJiang/Chat-UIkit-Design-Guide/blob/main/README.md)

# 贡献

欢迎贡献和反馈！ 对于任何问题或改进建议，您可以提出问题或提交拉取请求。

## 作者

zjc19891106, [984065974@qq.com](mailto:984065974@qq.com)

## 许可证

EaseCallUIKit 可在 MIT 许可下使用。 有关详细信息，请参阅许可证文件。

## 更新日志

[更新日志](./changeLog.md)

