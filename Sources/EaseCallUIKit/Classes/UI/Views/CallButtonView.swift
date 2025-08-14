//
//  CallButtonView.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 7/2/25.
//

// MARK: - CallButtonView
@objc public class CallButtonView: UIView {
    
    private let imageView = UIImageView().contentMode(.scaleAspectFit).backgroundColor(.clear)
    private let label = UILabel()
    public let containerView = UIView()
    public var allowSelection: Bool = true
    public var buttonTag = 0
    // 闭包属性，用于处理点击事件
    public var didTap: ((CallButtonView) -> Void)?
    
    public private(set) var data: CallButtonData?
    
    private var containerCornerRadius: CGFloat = 0
    
    // 存储约束以便动态调整
    private var labelTopConstraint: NSLayoutConstraint!
    
    // iconTitleSpace 设置为可修改的计算属性
    public var iconTitleSpace: CGFloat = 4
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.containerCornerRadius = frame.width / 2
    }
    
    convenience public init(frame: CGRect, iconTitleSpace: CGFloat = 4) {
        self.init(frame: frame)
        self.iconTitleSpace = iconTitleSpace
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // 容器视图
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // 图标
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        
        // 标签
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        // 创建标签顶部约束并存储引用
        labelTopConstraint = label.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: iconTitleSpace)
        
        // 约束
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.widthAnchor.constraint(equalTo: widthAnchor),
            containerView.heightAnchor.constraint(equalTo: widthAnchor),
            
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 9),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -9),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 9),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -9),
            
            labelTopConstraint, // 使用存储的约束
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
        
        containerView.layer.cornerRadius = self.containerCornerRadius
        self.isUserInteractionEnabled = true
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(buttonTapped)))
    }
    
    // 更新图标与标题之间的间距
    private func updateIconTitleSpacing() {
        labelTopConstraint.constant = iconTitleSpace
        layoutIfNeeded()
    }
    
    @objc private func buttonTapped() {
        // 触发缩放动画
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = CGAffineTransform.identity
            }
        }
        
        // 调用闭包，通知外部点击事件
        didTap?(self)
    }
    
    func configure(data: CallButtonData) {
        self.data = data
        if allowSelection {
            containerView.backgroundColor = data.isSelected ? UIColor.callTheme.barrageLightColor5:UIColor.callTheme.barrageDarkColor9
            imageView.image = UIImage(named: data.isSelected ? data.selectedImageName:data.imageName, in: .callBundle, with: nil)
            label.text = data.isSelected ? data.selectedTitle:data.title
        } else {
            containerView.backgroundColor = data.color
            imageView.image = UIImage(named: data.imageName, in: .callBundle, with: nil)
            label.text = data.title
        }
    }
    
    // 便捷方法：设置间距并可选择是否带动画
    public func setIconTitleSpacing(_ spacing: CGFloat, animated: Bool = false) {
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.iconTitleSpace = spacing
            }
        } else {
            self.iconTitleSpace = spacing
        }
    }
}

@objc public enum CallButtonType: UInt {
    case mic_on
    case mic_off
    case flip_back
    case flip_front
    case camera_on
    case camera_off
    case speaker_on
    case speaker_off
    case decline
    case accept
    case end
    case virtual_on
    case virtual_off
    case screen_share_on
    case screen_share_off
}

@objc public class CallButtonData: NSObject {
    var title: String
    var selectedTitle: String?
    var imageName: String
    var selectedImageName: String
    var color: UIColor?
    var isSelected: Bool = false
    
    public init(title: String, imageName: String, selectedImageName: String, color: UIColor? = nil, selectedTitle: String? = nil) {
        self.title = title
        self.imageName = imageName
        self.selectedImageName = selectedImageName
        self.color = color
        self.selectedTitle = selectedTitle
        super.init()
    }

}
