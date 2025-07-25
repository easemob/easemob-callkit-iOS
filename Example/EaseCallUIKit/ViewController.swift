//
//  ViewController.swift
//  EaseCallUIKit
//
//  Created by zjc19891106 on 06/24/2025.
//  Copyright (c) 2025 zjc19891106. All rights reserved.
//

import UIKit
import EaseCallUIKit
import QuickLook

class ViewController: UIViewController {
    
    var callType: CallType = .singleAudio

    @IBOutlet var inputField: UITextField!
        
    @IBOutlet var callButton: UIButton!
    
    @IBOutlet weak var userIdField: UITextField!
    @IBOutlet weak var tokenField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var callTypeSegment: UISegmentedControl!
    @IBOutlet weak var logButton: UIButton!

    
    lazy var joinInfo: UIButton = {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 40, y: 100, width: ScreenWidth-80, height: 40)
        button.setTitle("JoinInfo", for: .normal)
        button.clipsToBounds = true
        button.layer.cornerRadius = 4
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.addTarget(self, action: #selector(getInfo), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        CallKitManager.shared.enablePIPOn1V1VideoScene = true
//        CallKitManager.shared.currentUserInfo = CallUserProfile()
        self.callTypeSegment.selectedSegmentIndex = 0
        self.callTypeSegment.selectedSegmentTintColor = .systemBlue
        self.view.addSubview(self.joinInfo)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @objc func getInfo() {
        self.joinInfo.setTitle(CallKitManager.shared.joinChannelName, for: .normal)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }

    @IBAction func chooseCallType(_ sender: Any) {
        self.callType = CallType(rawValue: UInt(self.callTypeSegment.selectedSegmentIndex)) ?? .singleAudio
    }
    
    @IBAction func loginAction(_ sender: Any) {
        self.view.endEditing(true)
        guard let userId = userIdField.text, !userId.isEmpty,
              let token = tokenField.text, !token.isEmpty else {
            self.showCallToast(toast: "Please enter a valid username and token")
            return
        }
        
        ChatClient.shared().login(withUsername: userId, token: token) { [weak self] userId,error  in
            if let error = error {
                self?.showCallToast(toast: "Login failed: \(error.errorDescription ?? "")")
            } else {
                self?.showCallToast(toast: "Login successful")
                CallKitManager.shared.setup()
                self?.userIdField.isHidden = true
                self?.tokenField.isHidden = true
                self?.loginButton.isHidden = true 
            }
        }
    }
    
    @IBAction func logAction(_ sender: Any) {
        let previewController = QLPreviewController()
        previewController.dataSource = self
        self.present(previewController, animated: true)
    }
    
    @IBAction func callAction(_ sender: Any) {
        self.view.endEditing(true)
        guard let input = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            self.showCallToast(toast: "Please enter a valid username or group id")
            return
        }
        if self.callType != .multiCall {
            CallKitManager.shared.call(with: input, type: self.callType)
        } else {
            CallKitManager.shared.groupCall(groupId: input)
        }
    }
}

extension ViewController: QLPreviewControllerDataSource {
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }
    
    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/HyphenateSDK/easemobLog/easemob.log")
        return fileURL as QLPreviewItem
    }
    
    
}
