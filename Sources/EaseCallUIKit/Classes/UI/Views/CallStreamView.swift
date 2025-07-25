//
//  CallStreamView.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 6/25/25.
//

import UIKit

public class CallStreamView: UIImageView {

    var item: CallStreamItem
    var onTap: ((CallStreamView) -> Void)?
    var onPinchToShrink: ((CallStreamView) -> Void)?
    
    public let canvasView = UIView(frame: .zero)
    private let imageView = ImageView(frame: .zero).contentMode(.scaleAspectFill)
    private let coverView = UIView()
    private let loadingView = UIImageView().contentMode(.scaleAspectFit)
    public let userInfoView = UserInfoView()
    
    var displayMode: UserInfoDisplayMode = .all {
        didSet {
            userInfoView.displayMode = displayMode
        }
    }
    
    init(item: CallStreamItem) {
        self.item = item
        super.init(frame: .zero)
        self.alpha = 1.0
        self.isHidden = false
        setupView()
        setupGestures()
        self.updateItem(item)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        self.translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 8
        clipsToBounds = true
        self.isUserInteractionEnabled = true
        
        canvasView.backgroundColor = UIColor.clear
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(canvasView)
        
        // Setup image view (placeholder)
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        imageView.image = CallAppearance.avatarPlaceHolder
        addSubview(imageView)
        
        coverView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        coverView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(coverView)
        coverView.isHidden = true
        
        loadingView.backgroundColor = UIColor.clear
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.image = UIImage(named: "wait_indicator", in: .callBundle, with: nil)
        coverView.addSubview(loadingView)
        // Setup user info view
        userInfoView.translatesAutoresizingMaskIntoConstraints = false
        userInfoView.isUserInteractionEnabled = false
        addSubview(userInfoView)
        
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            coverView.topAnchor.constraint(equalTo: topAnchor),
            coverView.leadingAnchor.constraint(equalTo: leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: trailingAnchor),
            coverView.bottomAnchor.constraint(equalTo: bottomAnchor),
            loadingView.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),
            loadingView.widthAnchor.constraint(equalTo: coverView.widthAnchor, multiplier: 0.33),
            loadingView.heightAnchor.constraint(equalTo: loadingView.widthAnchor),
            userInfoView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            userInfoView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            userInfoView.trailingAnchor.constraint(lessThanOrEqualTo: centerXAnchor),
            userInfoView.heightAnchor.constraint(equalToConstant: 22)
        ])
        userInfoView.cornerRadius(11)
        // Ensure all subviews are visible
        imageView.alpha = 1.0
        userInfoView.alpha = 1.0
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinchGesture)
    }
    
    @objc private func handleTap() {
        onTap?(self)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began || gesture.state == .changed {
            if gesture.scale < 0.9 && item.isExpanded {
                onPinchToShrink?(self)
                gesture.scale = 1.0 // Reset scale to prevent multiple triggers
            }
        }
    }
    
    private func updateUserInfo() {
    }
    
    func updateItem(_ newItem: CallStreamItem) {
        self.item = newItem
        
        self.userInfoView.nickname = CallKitManager.shared.usersCache[newItem.userId]?.nickname ?? item.userId
        self.userInfoView.isAudioMuted = newItem.audioMuted
        let avatarURL = CallKitManager.shared.usersCache[newItem.userId]?.avatarURL ?? ""
        self.imageView.image(with: avatarURL, placeHolder: CallAppearance.avatarPlaceHolder)
        if newItem.videoMuted {
            self.sendSubviewToBack(self.canvasView)
            self.bringSubviewToFront(self.imageView)
            self.coverView.isHidden = !newItem.waiting
            if self.coverView.isHidden {
                self.sendSubviewToBack(self.coverView)
            } else {
                self.bringSubviewToFront(self.coverView)
            }
        } else {
            self.sendSubviewToBack(self.imageView)
            self.bringSubviewToFront(self.canvasView)
        }
        self.canvasView.isHidden = newItem.videoMuted
        self.imageView.isHidden = !newItem.videoMuted
        self.bringSubviewToFront(self.userInfoView)
    }
    
    func ensureVisible() {
        self.alpha = 1.0
        self.isHidden = false
        self.isOpaque = true
        imageView.alpha = 1.0
        imageView.isHidden = false
        userInfoView.alpha = 1.0
        userInfoView.isHidden = false
        // Force layout update
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // Ensure proper corner radius after layout
        layer.cornerRadius = 12
    }

}

// MARK: - Video Call Item Model
public class CallStreamItem: NSObject {
    let userId: String
    var uid = 0
    let index: Int
    var isExpanded: Bool = false
    var videoMuted: Bool = true
    var audioMuted: Bool = false
    var waiting: Bool = true
    
    init(userId: String,index: Int, isExpanded: Bool = false) {
        self.userId = userId
        self.index = index
        self.isExpanded = isExpanded
        if userId == ChatClient.shared().currentUsername ?? "" {
            waiting = false
        }
    }
    
}
// MARK: - User Info Component
public class UserInfoView: UIView {
    
    private let nicknameLabel = UILabel()
    private let audioButton = UIButton(type: .custom)
    private let containerStackView = UIStackView()
    
    // 添加宽度约束的引用
    private var containerTrailingConstraint: NSLayoutConstraint?
    private var nicknameLabelWidthConstraint: NSLayoutConstraint?
    
    var displayMode: UserInfoDisplayMode = .all {
        didSet {
            updateDisplayMode()
        }
    }
    
    var nickname: String = "" {
        didSet {
            updateNickname()
        }
    }
    
    var isAudioMuted: Bool = false {
        didSet {
            updateAudioButton()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        clipsToBounds = true
        
        // 添加圆角
        layer.cornerRadius = 4
        
        // Setup nickname label
        nicknameLabel.textColor = .white
        nicknameLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        nicknameLabel.lineBreakMode = .byTruncatingTail
        nicknameLabel.translatesAutoresizingMaskIntoConstraints = false
        nicknameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nicknameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Setup audio button
        audioButton.tintColor = .white
        audioButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        audioButton.contentMode = .scaleAspectFit
        audioButton.translatesAutoresizingMaskIntoConstraints = false
        audioButton.isUserInteractionEnabled = false // Just for display
        audioButton.setContentHuggingPriority(.required, for: .horizontal)
        audioButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        // Setup container stack view
        containerStackView.axis = .horizontal
        containerStackView.alignment = .center
        containerStackView.spacing = 6
        containerStackView.distribution = .fill
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerStackView.addArrangedSubview(nicknameLabel)
        containerStackView.addArrangedSubview(audioButton)
        
        addSubview(containerStackView)
        
        // 创建可变的约束
        containerTrailingConstraint = containerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6)
        nicknameLabelWidthConstraint = nicknameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80)
        
        // Constraints
        NSLayoutConstraint.activate([
            containerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            containerTrailingConstraint!,
            containerStackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            containerStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            // Nickname label width constraint
            nicknameLabelWidthConstraint!,
            
            // Audio button size
            audioButton.widthAnchor.constraint(equalToConstant: 16),
            audioButton.heightAnchor.constraint(equalToConstant: 16),
        ])
    }
    
    private func updateNickname() {
        nicknameLabel.text = nickname
        
        // 更新布局以适应新文本
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    private func updateAudioButton() {
        if isAudioMuted {
            audioButton.setImage(UIImage(systemName: "mic.slash.fill"), for: .normal)
        } else {
            audioButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        }
    }
    
    private func updateDisplayMode() {
        switch displayMode {
        case .all:
            // 显示所有内容
            nicknameLabel.isHidden = false
            audioButton.isHidden = false
            self.isHidden = false
            
            // 恢复正常的约束和间距
            containerStackView.spacing = 6
            nicknameLabelWidthConstraint?.constant = 80
            
        case .buttonsOnly:
            // 只显示按钮
            nicknameLabel.isHidden = true
            audioButton.isHidden = false
            self.isHidden = false
            
            // 移除间距，因为只有按钮
            containerStackView.spacing = 0
            
        case .hidden:
            // 隐藏整个视图
            self.isHidden = true
        }
        
        // 触发布局更新
        setNeedsLayout()
        layoutIfNeeded()
        
    }
    
    // 重写 intrinsicContentSize 以支持自动布局
    public override var intrinsicContentSize: CGSize {
        // 让 containerStackView 决定大小
        let stackSize = containerStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        
        // 加上内边距
        let width = stackSize.width + 12 // 左右各6的padding
        let height = stackSize.height + 8 // 上下各4的padding
        
        return CGSize(width: width, height: height)
    }
    
    // 当子视图布局变化时，更新 intrinsic content size
    public override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}

// MARK: - Display Mode
public enum UserInfoDisplayMode {
    case all          // 显示昵称和按钮
    case buttonsOnly  // 只显示按钮
    case hidden       // 完全隐藏
}

// MARK: - 便利方法
extension UserInfoView {
    
    /// 配置视图的所有属性
    public func configure(nickname: String, isAudioMuted: Bool, displayMode: UserInfoDisplayMode) {
        self.nickname = nickname
        self.isAudioMuted = isAudioMuted
        self.displayMode = displayMode
    }
    
    /// 获取当前视图的实际宽度
    public var actualWidth: CGFloat {
        switch displayMode {
        case .all:
            // 计算昵称标签的实际宽度
            let nicknameWidth = min(nicknameLabel.intrinsicContentSize.width, 80)
            return 6 + nicknameWidth + 6 + 16 + 6 // padding + nickname + spacing + button + padding
            
        case .buttonsOnly:
            return 6 + 16 + 6 // padding + button + padding
            
        case .hidden:
            return 0
        }
    }
    
    /// 带动画的模式切换
    public func setDisplayMode(_ mode: UserInfoDisplayMode, animated: Bool) {
        guard animated else {
            displayMode = mode
            return
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
            self.displayMode = mode
        })
    }
}

// MARK: - 调试辅助
#if DEBUG
extension UserInfoView {
    
    /// 添加边框以便调试
    public func enableDebugMode() {
        layer.borderWidth = 1
        layer.borderColor = UIColor.red.cgColor
        
        nicknameLabel.layer.borderWidth = 0.5
        nicknameLabel.layer.borderColor = UIColor.green.cgColor
        
        audioButton.layer.borderWidth = 0.5
        audioButton.layer.borderColor = UIColor.blue.cgColor
    }
}
#endif
