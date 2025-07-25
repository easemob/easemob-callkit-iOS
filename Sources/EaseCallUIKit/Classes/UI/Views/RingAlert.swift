//
//  RingAlert.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 6/30/25.
//

import UIKit

@objc public enum RingAlertAction: Int {
    case other
    case accept
    case decline
}

public class RingAlert: UIView {
    
    private lazy var profileImageView: ImageView = {
        let imageView = ImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 4
//        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var declineButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.callTheme.errorColor7
        button.setImage(UIImage(named: "phone_hang", in: .callBundle, with: nil), for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 18
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(declineCall), for: .touchUpInside)
        return button
    }()
    
    private lazy var acceptButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.callTheme.secondaryColor4
        button.setImage(UIImage(named: "phone_pick", in: .callBundle, with: nil), for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 18
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(acceptCall), for: .touchUpInside)
        return button
    }()
    
    public var actionClosure: ((RingAlertAction) -> Void)?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        // Configure the main view
        backgroundColor = UIColor(red: 0.173, green: 0.173, blue: 0.18, alpha: 1.0) // #2C2C2E
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 5
        
        self.isUserInteractionEnabled = true
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(otherAction)))
        // Add subviews
        addSubview(profileImageView)
        addSubview(usernameLabel)
        addSubview(messageLabel)
        addSubview(declineButton)
        addSubview(acceptButton)
        
        // Set up constraints
        setupConstraints()
        
        // Set default values
        profileImageView.image = UIImage(systemName: "person.circle.fill") // Placeholder
        usernameLabel.text = NSLocalizedString("Username", comment: "Username label")
        messageLabel.text = NSLocalizedString("Inviting you to an audio call", comment: "Call invitation message")
    }
    
    private func setupConstraints() {
        // Profile image constraints
        NSLayoutConstraint.activate([
            profileImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            profileImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 40),
            profileImageView.heightAnchor.constraint(equalToConstant: 40),
            usernameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 12),
            usernameLabel.topAnchor.constraint(equalTo: profileImageView.topAnchor, constant: 2),
            messageLabel.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
            messageLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -126),
            
            acceptButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            acceptButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            acceptButton.widthAnchor.constraint(equalToConstant: 36),
            acceptButton.heightAnchor.constraint(equalToConstant: 36),
            declineButton.trailingAnchor.constraint(equalTo: acceptButton.leadingAnchor, constant: -16),
            declineButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            declineButton.widthAnchor.constraint(equalToConstant: 36),
            declineButton.heightAnchor.constraint(equalToConstant: 36),
            
        ])
        
        acceptButton.setHitTestEdgeInsets(UIEdgeInsets(top: -5, left: -5, bottom: -5, right: -5))
        declineButton.setHitTestEdgeInsets(UIEdgeInsets(top: -2, left: -2, bottom: -2, right: -2))
        
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
    }
    
    // MARK: - Public Methods
    
    func refresh(profile: CallUserProfileProtocol, type: CallType) {
        usernameLabel.text = profile.nickname.isEmpty ? profile.id:profile.nickname
        profileImageView.image(with: profile.avatarURL, placeHolder: CallAppearance.avatarPlaceHolder)
        switch type {
        case .singleAudio:
            messageLabel.text = "invite_info_audio".call.localize
        case .singleVideo:
            messageLabel.text = "invite_info_video".call.localize
        case .multiCall:
            messageLabel.text = "group_invite_info".call.localize
        }
            
    }
    
    
    // MARK: - Actions
    
    @objc private func declineCall() {
        self.actionClosure?(.decline)
    }
    
    @objc private func acceptCall() {
        self.actionClosure?(.accept)
    }
    
    @objc private func otherAction() {
        self.actionClosure?(.other)
    }
}


public class CallPopupView: UIView {
    
    // MARK: - Properties
    private let backgroundView = UIView()
    private let callCardView = RingAlert()
    public var callCardAction: ((RingAlertAction) -> Void)?
    
    // 灵动岛的位置和大小（iPhone 14 Pro系列）
    private let dynamicIslandFrame = CGRect(x: (UIScreen.main.bounds.width - 126) / 2, y: 20, width: 126, height: 37)
    
    // 约束引用
    private var cardTopConstraint: NSLayoutConstraint!
    private var cardLeadingConstraint: NSLayoutConstraint!
    private var cardTrailingConstraint: NSLayoutConstraint!
    private var cardHeightConstraint: NSLayoutConstraint!
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        self.callCardView.actionClosure = { [weak self] in
            self?.handlerCallCardAction($0)
        }
    }
    
    private func handlerCallCardAction(_ action: RingAlertAction) {
        self.callCardAction?(action)
        self.dismiss()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupViews() {
        // 设置背景视图
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.alpha = 0
        addSubview(backgroundView)
        
        // 背景视图约束
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // 设置呼叫卡片视图
        setupCallCardView()
        
        // 初始状态设置
        callCardView.alpha = 1
        callCardView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
    }
    
    private func setupCallCardView() {
        // 呼叫卡片样式
        callCardView.layer.cornerRadius = 20
        callCardView.layer.shadowColor = UIColor.black.cgColor
        callCardView.layer.shadowOpacity = 0.3
        callCardView.layer.shadowOffset = CGSize(width: 0, height: 10)
        callCardView.layer.shadowRadius = 20
        callCardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(callCardView)
        
        // 设置初始约束（灵动岛位置）
        let initialWidth = dynamicIslandFrame.width
        let initialHeight = dynamicIslandFrame.height
        
        // 创建约束
        cardTopConstraint = callCardView.topAnchor.constraint(equalTo: topAnchor, constant: dynamicIslandFrame.origin.y)
        cardLeadingConstraint = callCardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: dynamicIslandFrame.origin.x)
        cardTrailingConstraint = callCardView.trailingAnchor.constraint(equalTo: leadingAnchor, constant: dynamicIslandFrame.origin.x + initialWidth)
        cardHeightConstraint = callCardView.heightAnchor.constraint(equalToConstant: initialHeight)
        
        // 激活约束
        NSLayoutConstraint.activate([
            cardTopConstraint,
            cardLeadingConstraint,
            cardTrailingConstraint,
            cardHeightConstraint
        ])
    }
    
    // MARK: - Animation
    func show() {
        // 确保视图在最前面
        if let window = UIApplication.shared.call.keyWindow {
            window.addSubview(self)
        }
        
        // 强制初始布局
        self.layoutIfNeeded()
        
        // 计算最终位置
        let statusBarHeight: CGFloat
        if #available(iOS 13.0, *) {
            statusBarHeight = StatusBarHeight
        } else {
            statusBarHeight = UIApplication.shared.statusBarFrame.height
        }
        
        let screenWidth = ScreenWidth
        let finalTop = statusBarHeight
        let finalLeading: CGFloat = 12
        let finalTrailing = screenWidth - 12
        let finalHeight: CGFloat = 80
        
        // 更新约束到最终位置
        cardTopConstraint.constant = finalTop
        cardLeadingConstraint.constant = finalLeading
        cardTrailingConstraint.constant = finalTrailing
        cardHeightConstraint.constant = finalHeight
        
        // 执行动画
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveLinear, animations: {
            // 背景淡入
            self.backgroundView.alpha = 0.3
            
            // 卡片放大
            self.callCardView.transform = .identity
            
            // 应用约束变化
            self.layoutIfNeeded()
        }) { _ in
            // 确保布局正确
            self.callCardView.setNeedsLayout()
            self.callCardView.layoutIfNeeded()
        }
    }
    
    func dismiss() {
        // 更新约束回到灵动岛位置
        cardTopConstraint.constant = dynamicIslandFrame.origin.y
        cardLeadingConstraint.constant = dynamicIslandFrame.origin.x
        cardTrailingConstraint.constant = dynamicIslandFrame.origin.x + dynamicIslandFrame.width
        cardHeightConstraint.constant = dynamicIslandFrame.height
        
        // 执行动画
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
            self.callCardView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            self.backgroundView.alpha = 0
            self.layoutIfNeeded()
        }) { _ in
            self.removeFromSuperview()
        }
    }
    
//    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        super.touchesBegan(touches, with: event)
//        // 处理触摸事件，防止误触
//        if let touch = touches.first
//        {
//            let location = touch.location(in: self)
//            if !callCardView.frame.contains(location) {
//                // 如果点击不在呼叫卡片内，则不处理
//                return
//            }
//        }
//    }
    
}

// MARK: - 使用示例
extension CallPopupView {
    
    // 配置呼叫者信息
    func refresh(profile: CallUserProfileProtocol, type: CallType) {
        callCardView.refresh(profile: profile,type: type)
    }
}

