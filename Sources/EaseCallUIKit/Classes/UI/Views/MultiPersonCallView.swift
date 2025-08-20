//
//  MultiPersonCallView.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 7/1/25.
//

import UIKit

public class MultiPersonCallView: UIView {
    
    private weak var expandedView: CallStreamView?
    private var scrollView: UIScrollView?
    private var activeConstraints: [NSLayoutConstraint] = []
    public var touchOtherArea: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Public Methods
    func updateWithItems(_ removeUsers: [String] = []) {
        
        // 更新 items cache
//        let items = CallKitManager.shared.itemsCache.values.sorted { $0.index > $1.index }

        // 1. 找出所有需要删除的视图
        var viewsInScrollView: [CallStreamView] = []
        let currentUserIds = Set(CallKitManager.shared.itemsCache.keys)

        
        // 检查 scrollView 中的 CallStreamView
        if let scrollView = scrollView {
            for subview in scrollView.subviews {
                if let streamView = subview as? CallStreamView {
                    if !currentUserIds.contains(streamView.item.userId) {
                        viewsInScrollView.append(streamView)
                    }
                }
            }
        }
        
        // 修改这里的逻辑：只有在确实需要删除用户或者需要重新布局时才调用setupViews
        if removeUsers.isEmpty {
            // 检查是否有新用户需要添加视图
            setupViews()
            return
        }
        
        var viewsToRemove: [CallStreamView] = []
        // 2. 判断删除逻辑
        for user in removeUsers {
            if let view = CallKitManager.shared.canvasCache[user] {
                viewsToRemove.append(view)
            }
        }
        let isRemovingExpandedView = viewsToRemove.contains { $0 == expandedView }
        
        if isRemovingExpandedView {
            // 删除的是展开视图，需要回归常规状态
            animateRemovalAndReturnToNormal(viewsToRemove: viewsToRemove)
        } else if expandedView != nil {
            // 在展开状态下删除非展开视图
            animateRemovalInExpandedState(viewsToRemove: viewsToRemove, viewsInScrollView: viewsInScrollView)
        } else {
            viewsToRemove.forEach { $0.removeFromSuperview() }
            // 在常规状态下删除视图
            self.setupViews()
        }
        // 不在这里单独设置 displayMode，使用统一方法
        updateAllDisplayModes()
    }

    // MARK: - 辅助动画方法

    private func animateRemovalAndReturnToNormal(viewsToRemove: [CallStreamView]) {
        // 从 canvasCache 中移除
        for view in viewsToRemove {
            CallKitManager.shared.canvasCache.removeValue(forKey: view.item.userId)
        }
        
        // 淡出所有要删除的视图
        UIView.animate(withDuration: 0.3, animations: {
            for view in viewsToRemove {
                view.alpha = 0
            }
            self.scrollView?.alpha = 0
        }, completion: { _ in
            // 移除视图
            for view in viewsToRemove {
                view.removeFromSuperview()
            }
            for subview in self.scrollView?.subviews ?? [] {
                subview.removeFromSuperview()
            }
            self.scrollView?.removeFromSuperview()
            self.scrollView = nil
            self.expandedView = nil
            
            // 重新设置视图
            self.setupViews()
        })
    }

    private func animateRemovalInExpandedState(viewsToRemove: [CallStreamView], viewsInScrollView: [CallStreamView]) {
        // 从 canvasCache 中移除
        for view in viewsToRemove {
            CallKitManager.shared.canvasCache.removeValue(forKey: view.item.userId)
        }
        
        // 如果只是从 scrollView 中删除缩略图
        if !viewsInScrollView.isEmpty {
            UIView.animate(withDuration: 0.3, animations: {
                for view in viewsInScrollView {
                    view.alpha = 0
                    view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                }
            }, completion: { _ in
                for view in viewsInScrollView {
                    view.removeFromSuperview()
                }
                
                // 检查删除后剩余的视图数量
                let remainingCount = CallKitManager.shared.canvasCache.count
                if remainingCount == 1 {
                    // 只剩一个视图，执行特殊处理
                    self.animateToSingleViewLayout()
                } else {
                    // 重新布局展开状态的缩略图
                    self.updateScrollViewContent()
                }
            })
        }
        
        // 处理主视图中的删除
        let mainViewRemovals = viewsToRemove.filter { !viewsInScrollView.contains($0) }
        if !mainViewRemovals.isEmpty {
            UIView.animate(withDuration: 0.3, animations: {
                for view in mainViewRemovals {
                    view.alpha = 0
                }
            }, completion: { _ in
                for view in mainViewRemovals {
                    view.removeFromSuperview()
                }
                
                // 再次检查剩余视图数量
                let remainingCount = CallKitManager.shared.canvasCache.count
                if remainingCount == 1 {
                    // 只剩一个视图，执行特殊处理
                    self.animateToSingleViewLayout()
                }
            })
        }
    }

    // 新增方法：处理只剩一个视图的情况
    private func animateToSingleViewLayout() {
        guard let lastView = CallKitManager.shared.canvasCache.values.first else { return }
        
        // 清除展开状态
        expandedView = nil
        
        // 更新视图状态
        if let item = CallKitManager.shared.itemsCache[lastView.item.userId] {
            item.isExpanded = false
            lastView.updateItem(item)
        }
        lastView.displayMode = .all
        
        // 如果视图在 scrollView 中，移到主视图
        if lastView.superview == scrollView {
            lastView.removeFromSuperview()
            addSubview(lastView)
        }
        
        // 计算目标尺寸
        let aspectRatio = ScreenHeight / ScreenWidth
        let targetSize: CGFloat
        
        if aspectRatio <= 16.0/9.0 {
            // 屏幕高宽比正好是 16:9
            targetSize = ScreenWidth * 2.0/3.0
        } else {
            // 屏幕高宽比大于 16:9（更高的屏幕）
            targetSize = ScreenWidth - 24
        }
        
        // 清除现有约束
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        
        // 动画过渡到新布局
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.3, options: [.curveEaseInOut], animations: {
            // 淡出 scrollView
            self.scrollView?.alpha = 0
            
            // 设置单个视图的约束
            lastView.translatesAutoresizingMaskIntoConstraints = false
            
            self.activeConstraints = [
                lastView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                lastView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                lastView.widthAnchor.constraint(equalToConstant: targetSize),
                lastView.heightAnchor.constraint(equalToConstant: targetSize)
            ]
            
            NSLayoutConstraint.activate(self.activeConstraints)
            self.layoutIfNeeded()
            
        }, completion: { _ in
            // 清理 scrollView
            self.scrollView?.removeFromSuperview()
            self.scrollView = nil
            
            // 确保视图可见
//            lastView.ensureVisible()
        })
    }


    // 更新 scrollView 中的内容布局
    private func updateScrollViewContent() {
        guard let scrollView = scrollView, let expandedView = expandedView else { return }
        
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        
        let thumbnailSize: CGFloat = 72
        let thumbnailSpacing: CGFloat = 6
        let padding: CGFloat = 12
        
        // 重新布局 scrollView 中的视图
        let remainingViews = scrollView.subviews
            .compactMap { $0 as? CallStreamView }
            .sorted { $0.item.index > $1.item.index }
        
        for (index, view) in remainingViews.enumerated() {
            view.translatesAutoresizingMaskIntoConstraints = false
            let leadingConstant = padding + CGFloat(index) * (thumbnailSize + thumbnailSpacing)
            
            activeConstraints += [
                view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: leadingConstant),
                view.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
                view.widthAnchor.constraint(equalToConstant: thumbnailSize),
                view.heightAnchor.constraint(equalToConstant: thumbnailSize)
            ]
        }
        
        // 确保展开视图的约束正确
        activeConstraints += [
            expandedView.centerXAnchor.constraint(equalTo: centerXAnchor),
            expandedView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            expandedView.widthAnchor.constraint(equalToConstant: ScreenWidth - 24),
            expandedView.heightAnchor.constraint(equalToConstant: ScreenWidth - 24)
        ]
        
        // 更新 scrollView 的 contentSize
        let contentWidth = padding + CGFloat(remainingViews.count) * (thumbnailSize + thumbnailSpacing) - thumbnailSpacing + padding
        scrollView.contentSize = CGSize(width: contentWidth, height: thumbnailSize)
        
        NSLayoutConstraint.activate(activeConstraints)
    }
    
    func updateItem(_ item: CallStreamItem) {
        CallKitManager.shared.canvasCache[item.userId]?.updateItem(item)
    }
    
    // MARK: - Private Methods
    private func setupViews() {
        // Clear existing views
        for subview in scrollView?.subviews ?? [] {
            subview.removeFromSuperview()
        }
        for subview in subviews {
            if let streamView = subview as? CallStreamView {
                streamView.removeFromSuperview()
            }
        }
        for streamView in CallKitManager.shared.canvasCache.values {
            streamView.removeFromSuperview()
        }
        scrollView?.removeFromSuperview()
        scrollView = nil
        
        self.addGestureHandlers()
        layoutItemsForNormalState()
        updateAllDisplayModes()

    }
    
    private func addGestureHandlers() {
        for canvas in CallKitManager.shared.canvasCache.values {
            canvas.onTap = { [weak self] tappedView in
                self?.handleItemTap(tappedView)
            }
            canvas.onPinchToShrink = { [weak self] view in
                self?.handlePinchToShrink(view)
            }
            canvas.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    private func updateAllDisplayModes() {
        let itemViews = CallKitManager.shared.canvasCache.values
        let totalCount = itemViews.count
        if expandedView != nil {
            for view in itemViews {
                view.displayMode = (view == expandedView ? .all:.hidden)
            }
        } else {
            for view in itemViews {
                if totalCount > 6 {
                    view.displayMode = .buttonsOnly
                } else {
                    if ScreenHeight/ScreenWidth > 1.8,totalCount <= 4 {
                        view.displayMode = .all
                    } else {
                        view.displayMode = .buttonsOnly
                    }
                }
            }
        }
        self.addGestureHandlers()
    }
    
    private func handleItemTap(_ tappedView: CallStreamView) {
        if CallKitManager.shared.canvasCache.count <= 1 {
            // 如果只有一个视图，直接返回,不再特殊处理点击变化
            return
        }
        if let currentExpanded = expandedView {
            if currentExpanded == tappedView {
                // Tapped the expanded view, return to normal
                animateToNormalStateSmooth()
            } else {
                // Switching to a different expanded view
                switchExpandedViewWithSmartSpace(from: currentExpanded, to: tappedView)
            }
        } else {
            // No expanded view, expand the tapped one
            animateExpandViewImproved(tappedView)
        }
        
        // 统一更新所有视图的 displayMode
        updateAllDisplayModes()
    }
    
    
    private func handlePinchToShrink(_ view: CallStreamView) {
        if expandedView == view {
            animateToNormalStateSmooth()
        }
    }
    
    // Helper method to create smooth position interpolation
    private func animateViewTransition(from startFrame: CGRect, to endFrame: CGRect, view: UIView, duration: TimeInterval = 0.5) {
        // Create a container view for the animation
        let animationContainer = UIView(frame: startFrame)
        animationContainer.backgroundColor = .clear
        addSubview(animationContainer)
        
        // Add the view to the container
        view.frame = animationContainer.bounds
        animationContainer.addSubview(view)
        
        // Animate the container
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.3, options: [.curveEaseInOut], animations: {
            animationContainer.frame = endFrame
        }, completion: { _ in
            // Move view back to its parent and remove container
            view.removeFromSuperview()
            self.addSubview(view)
            view.frame = endFrame
            animationContainer.removeFromSuperview()
        })
    }
    
    private func layoutItemsForNormalState() {
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        let itemViews = CallKitManager.shared.canvasCache.values.sorted { $0.item.index > $1.item.index }
        // 确保所有视图都在当前视图层级中
        for view in itemViews {
            if view.superview != self {
                // 从原有父视图移除
                view.removeFromSuperview()
                // 添加到当前视图
                addSubview(view)
            }
        }
        let count = itemViews.count
        let padding: CGFloat = 8
        let availableWidth = bounds.width - (padding * 2)
        let availableHeight = bounds.height - (padding * 2)
        let heightWidthRatio: CGFloat = ScreenHeight/ScreenWidth // Square views
        switch count {
        case 1:
            // Single view - square, centered
            var size: CGFloat = 0
            if heightWidthRatio <= 16.0/9.0 {
                // 屏幕高宽比正好是 16:9
                size = ScreenWidth * 2.0/3.0
            } else {
                // 屏幕高宽比大于 16:9（更高的屏幕）
                size = ScreenWidth - 24
            }
            let view = itemViews[0]
            activeConstraints += [
                view.centerXAnchor.constraint(equalTo: centerXAnchor),
                view.centerYAnchor.constraint(equalTo: centerYAnchor),
                view.widthAnchor.constraint(equalToConstant: size),
                view.heightAnchor.constraint(equalToConstant: size)
            ]
        case 2:
            // Two views - side by side squares
            let maxSize = min((availableWidth - padding) / 2, availableHeight, 250)
            
            activeConstraints += [
                itemViews[0].centerXAnchor.constraint(equalTo: centerXAnchor, constant: -(maxSize + padding) / 2),
                itemViews[0].centerYAnchor.constraint(equalTo: centerYAnchor),
                itemViews[0].widthAnchor.constraint(equalToConstant: maxSize),
                itemViews[0].heightAnchor.constraint(equalToConstant: maxSize),
                
                itemViews[1].centerXAnchor.constraint(equalTo: centerXAnchor, constant: (maxSize + padding) / 2),
                itemViews[1].centerYAnchor.constraint(equalTo: centerYAnchor),
                itemViews[1].widthAnchor.constraint(equalToConstant: maxSize),
                itemViews[1].heightAnchor.constraint(equalToConstant: maxSize)
            ]
            
        case 3:
            // Special case: 2 rows, second row centered
            let maxSize = min((availableWidth - padding) / 2, (availableHeight - padding) / 2, 200)
            
            // First row - 2 items
            activeConstraints += [
                itemViews[0].centerXAnchor.constraint(equalTo: centerXAnchor, constant: -(maxSize + padding) / 2),
                itemViews[0].centerYAnchor.constraint(equalTo: centerYAnchor, constant: -(maxSize + padding) / 2),
                itemViews[0].widthAnchor.constraint(equalToConstant: maxSize),
                itemViews[0].heightAnchor.constraint(equalToConstant: maxSize),
                
                itemViews[1].centerXAnchor.constraint(equalTo: centerXAnchor, constant: (maxSize + padding) / 2),
                itemViews[1].centerYAnchor.constraint(equalTo: centerYAnchor, constant: -(maxSize + padding) / 2),
                itemViews[1].widthAnchor.constraint(equalToConstant: maxSize),
                itemViews[1].heightAnchor.constraint(equalToConstant: maxSize)
            ]
            
            // Second row - 1 item centered
            activeConstraints += [
                itemViews[2].centerXAnchor.constraint(equalTo: centerXAnchor),
                itemViews[2].centerYAnchor.constraint(equalTo: centerYAnchor, constant: (maxSize + padding) / 2),
                itemViews[2].widthAnchor.constraint(equalToConstant: maxSize),
                itemViews[2].heightAnchor.constraint(equalToConstant: maxSize)
            ]
            
        case 4:
            // 2x2 grid
            let maxSize = min((availableWidth - padding) / 2, (availableHeight - padding) / 2, 200)
            
            activeConstraints += [
                itemViews[0].centerXAnchor.constraint(equalTo: centerXAnchor, constant: -(maxSize + padding) / 2),
                itemViews[0].centerYAnchor.constraint(equalTo: centerYAnchor, constant: -(maxSize + padding) / 2),
                itemViews[0].widthAnchor.constraint(equalToConstant: maxSize),
                itemViews[0].heightAnchor.constraint(equalToConstant: maxSize),
                
                itemViews[1].centerXAnchor.constraint(equalTo: centerXAnchor, constant: (maxSize + padding) / 2),
                itemViews[1].centerYAnchor.constraint(equalTo: centerYAnchor, constant: -(maxSize + padding) / 2),
                itemViews[1].widthAnchor.constraint(equalToConstant: maxSize),
                itemViews[1].heightAnchor.constraint(equalToConstant: maxSize),
                
                itemViews[2].centerXAnchor.constraint(equalTo: centerXAnchor, constant: -(maxSize + padding) / 2),
                itemViews[2].centerYAnchor.constraint(equalTo: centerYAnchor, constant: (maxSize + padding) / 2),
                itemViews[2].widthAnchor.constraint(equalToConstant: maxSize),
                itemViews[2].heightAnchor.constraint(equalToConstant: maxSize),
                
                itemViews[3].centerXAnchor.constraint(equalTo: centerXAnchor, constant: (maxSize + padding) / 2),
                itemViews[3].centerYAnchor.constraint(equalTo: centerYAnchor, constant: (maxSize + padding) / 2),
                itemViews[3].widthAnchor.constraint(equalToConstant: maxSize),
                itemViews[3].heightAnchor.constraint(equalToConstant: maxSize)
            ]
            
        case 5 where heightWidthRatio > 1.8:
            
            // Special case: 3 rows (2+2+1), last row centered
            let columns = 2
            let rows = 3
            let maxSize = min((availableWidth - padding * CGFloat(columns - 1)) / CGFloat(columns),
                             (availableHeight - padding * CGFloat(rows - 1)) / CGFloat(rows), 180)
            
            let totalGridHeight = CGFloat(rows) * maxSize + CGFloat(rows - 1) * padding
            let gridStartY = (bounds.height - totalGridHeight) / 2
            
            // First two rows (2+2)
            for i in 0..<4 {
                let row = i / 2
                let col = i % 2
                let x = bounds.width / 2 + (CGFloat(col) - 0.5) * (maxSize + padding)
                let y = gridStartY + CGFloat(row) * (maxSize + padding) + maxSize / 2
                
                activeConstraints += [
                    itemViews[i].centerXAnchor.constraint(equalTo: leadingAnchor, constant: x),
                    itemViews[i].centerYAnchor.constraint(equalTo: topAnchor, constant: y),
                    itemViews[i].widthAnchor.constraint(equalToConstant: maxSize),
                    itemViews[i].heightAnchor.constraint(equalToConstant: maxSize)
                ]
            }
            
            // Third row - 1 item centered
            let y = gridStartY + 2 * (maxSize + padding) + maxSize / 2
            activeConstraints += [
                itemViews[4].centerXAnchor.constraint(equalTo: centerXAnchor),
                itemViews[4].centerYAnchor.constraint(equalTo: topAnchor, constant: y),
                itemViews[4].widthAnchor.constraint(equalToConstant: maxSize),
                itemViews[4].heightAnchor.constraint(equalToConstant: maxSize)
            ]
            
        case 6 where heightWidthRatio > 1.8:
            // 3 rows x 2 columns grid (not 2x3)
            // Use same size as 4 items (2x2 grid)
            let maxSizeForWidth = (availableWidth - padding) / 2
            let maxSizeForHeight = (availableHeight - padding * 2) / 3  // 3 rows
            let maxSize = min(maxSizeForWidth, maxSizeForHeight, 180)
            
            let totalGridWidth = 2 * maxSize + padding
            let totalGridHeight = 3 * maxSize + 2 * padding
            let gridStartX = (bounds.width - totalGridWidth) / 2
            let gridStartY = (bounds.height - totalGridHeight) / 2
            
            // Layout in 3 rows, 2 columns
            for i in 0..<6 {
                let row = i / 2  // 2 columns per row
                let col = i % 2  // column within row
                
                let x = gridStartX + CGFloat(col) * (maxSize + padding) + maxSize / 2
                let y = gridStartY + CGFloat(row) * (maxSize + padding) + maxSize / 2
                itemViews[i].displayMode = .all
                activeConstraints += [
                    itemViews[i].centerXAnchor.constraint(equalTo: leadingAnchor, constant: x),
                    itemViews[i].centerYAnchor.constraint(equalTo: topAnchor, constant: y),
                    itemViews[i].widthAnchor.constraint(equalToConstant: maxSize),
                    itemViews[i].heightAnchor.constraint(equalToConstant: maxSize)
                ]
            }
            
        case 7, 8:
            // Special case for 7-8 items: 3x3 grid with last row centered
            let columns = 3
            let rows = 3
            let maxSize = min((availableWidth - padding * CGFloat(columns - 1)) / CGFloat(columns),
                             (availableHeight - padding * CGFloat(rows - 1)) / CGFloat(rows), 150)
            
            let totalGridHeight = CGFloat(rows) * maxSize + CGFloat(rows - 1) * padding
            let gridStartY = (bounds.height - totalGridHeight) / 2
            
            // Layout all items
            for (index, view) in itemViews.enumerated() {
                let row = index / columns
                let col = index % columns
                
                // Check if this is the last row
                let isLastRow = row == rows - 1
                let itemsInLastRow = count - row * columns
                
                if isLastRow && itemsInLastRow < columns {
                    // Center the last row items
                    let totalLastRowWidth = CGFloat(itemsInLastRow) * maxSize + CGFloat(itemsInLastRow - 1) * padding
                    let lastRowStartX = (bounds.width - totalLastRowWidth) / 2
                    let x = lastRowStartX + CGFloat(col) * (maxSize + padding)
                    let y = gridStartY + CGFloat(row) * (maxSize + padding)
                    
                    activeConstraints += [
                        view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: x),
                        view.topAnchor.constraint(equalTo: topAnchor, constant: y),
                        view.widthAnchor.constraint(equalToConstant: maxSize),
                        view.heightAnchor.constraint(equalToConstant: maxSize)
                    ]
                } else {
                    // Normal grid positioning
                    let totalGridWidth = CGFloat(columns) * maxSize + CGFloat(columns - 1) * padding
                    let gridStartX = (bounds.width - totalGridWidth) / 2
                    let x = gridStartX + CGFloat(col) * (maxSize + padding)
                    let y = gridStartY + CGFloat(row) * (maxSize + padding)
                    
                    activeConstraints += [
                        view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: x),
                        view.topAnchor.constraint(equalTo: topAnchor, constant: y),
                        view.widthAnchor.constraint(equalToConstant: maxSize),
                        view.heightAnchor.constraint(equalToConstant: maxSize)
                    ]
                }
            }
            
        default:
            // For more items, use flexible grid with special centering rules
            let columns: Int
            let rows: Int
            
            // Determine grid size based on count
            if count <= 9 {
                columns = 3
                rows = Int(ceil(Double(count) / Double(columns)))
            } else if count <= 12 {
                columns = 3
                rows = Int(ceil(Double(count) / Double(columns)))
            } else {
                columns = 4
                rows = Int(ceil(Double(count) / Double(columns)))
            }
            
            let maxSizeByWidth = (availableWidth - padding * CGFloat(columns - 1)) / CGFloat(columns)
            let maxSizeByHeight = (availableHeight - padding * CGFloat(rows - 1)) / CGFloat(rows)
            let size = min(maxSizeByWidth, maxSizeByHeight, 150)
            
            let totalGridHeight = CGFloat(rows) * size + CGFloat(rows - 1) * padding
            let gridStartY = (bounds.height - totalGridHeight) / 2
            
            // Layout all rows
            for (index, view) in itemViews.enumerated() {
                let row = index / columns
                let col = index % columns
                
                // Check if this is the last row
                let isLastRow = row == rows - 1
                let itemsInLastRow = count - row * columns
                
                if isLastRow && itemsInLastRow < columns {
                    // Center the last row items
                    let totalLastRowWidth = CGFloat(itemsInLastRow) * size + CGFloat(itemsInLastRow - 1) * padding
                    let lastRowStartX = (bounds.width - totalLastRowWidth) / 2
                    let x = lastRowStartX + CGFloat(col) * (size + padding)
                    let y = gridStartY + CGFloat(row) * (size + padding)
                    
                    activeConstraints += [
                        view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: x),
                        view.topAnchor.constraint(equalTo: topAnchor, constant: y),
                        view.widthAnchor.constraint(equalToConstant: size),
                        view.heightAnchor.constraint(equalToConstant: size)
                    ]
                } else {
                    // Normal grid positioning
                    let totalGridWidth = CGFloat(columns) * size + CGFloat(columns - 1) * padding
                    let gridStartX = (bounds.width - totalGridWidth) / 2
                    let x = gridStartX + CGFloat(col) * (size + padding)
                    let y = gridStartY + CGFloat(row) * (size + padding)
                    
                    activeConstraints += [
                        view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: x),
                        view.topAnchor.constraint(equalTo: topAnchor, constant: y),
                        view.widthAnchor.constraint(equalToConstant: size),
                        view.heightAnchor.constraint(equalToConstant: size)
                    ]
                }
            }
        }
        
        NSLayoutConstraint.activate(activeConstraints)
    }
    
    private func layoutItemsForExpandedState() {
        guard let expandedView = expandedView else { return }
        
        // Clear all existing constraints first
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        
        let padding: CGFloat = 20
        let expandedHeight = ScreenWidth-24
        let thumbnailSize: CGFloat = 72
        let thumbnailSpacing: CGFloat = 6
        
        // Setup scroll view for thumbnails
        if scrollView == nil {
            scrollView = UIScrollView()
            scrollView!.showsHorizontalScrollIndicator = false
            scrollView!.translatesAutoresizingMaskIntoConstraints = false
            scrollView!.bounces = false
            scrollView!.alpha = 0
            scrollView!.backgroundColor = UIColor.clear
            addSubview(scrollView!)
            
            UIView.animate(withDuration: 0.3) {
                self.scrollView!.alpha = 1
            }
        }
        
        // Ensure expanded view is in the main view (not in scroll view)
        if expandedView.superview != self {
            expandedView.removeFromSuperview()
            addSubview(expandedView)
        }
        
        // Make sure expanded view is visible
        expandedView.ensureVisible()
        
        // Ensure correct view hierarchy
        if let scrollView = scrollView {
            // Make sure scrollView is at the correct position in hierarchy
            insertSubview(scrollView, at: 0)
        }
        
        // Move expanded view to the absolute front
        bringSubviewToFront(expandedView)
        
        // Layout expanded view (square and centered)
        expandedView.translatesAutoresizingMaskIntoConstraints = false
        
        // Remove any existing constraints on the expanded view
        expandedView.removeFromSuperview()
        addSubview(expandedView)
        
        activeConstraints += [
            expandedView.centerXAnchor.constraint(equalTo: centerXAnchor),
            expandedView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -padding*2),
            expandedView.widthAnchor.constraint(equalToConstant: expandedHeight),
            expandedView.heightAnchor.constraint(equalToConstant: expandedHeight)
        ]
        // Removed the extra padding
        activeConstraints += [
            scrollView!.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView!.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView!.topAnchor.constraint(equalTo: expandedView.bottomAnchor, constant: 12),
            scrollView!.heightAnchor.constraint(equalToConstant: thumbnailSize)
        ]
        let itemViews = CallKitManager.shared.canvasCache.values.sorted { $0.item.index > $1.item.index }
        // Add thumbnail views to scroll view (all square) - sorted by index
        let otherViews = itemViews.filter { $0 != expandedView }.sorted { $0.item.index > $1.item.index }
        
        // Clear scroll view content first
        scrollView!.subviews.forEach { $0.removeFromSuperview() }
        
        var contentWidth = CGFloat(otherViews.count) * (thumbnailSize + thumbnailSpacing) - thumbnailSpacing

        for (index, view) in otherViews.enumerated() {
            // Ensure view is visible before adding to scroll view
            view.ensureVisible()
            view.displayMode = .buttonsOnly
            scrollView!.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            
            let leadingConstant = 12 + CGFloat(index) * (thumbnailSize + thumbnailSpacing)
            
            activeConstraints += [
                view.leadingAnchor.constraint(equalTo: scrollView!.leadingAnchor, constant: leadingConstant),
                view.centerYAnchor.constraint(equalTo: scrollView!.centerYAnchor),
                view.widthAnchor.constraint(equalToConstant: thumbnailSize),
                view.heightAnchor.constraint(equalToConstant: thumbnailSize)
            ]
        }
        expandedView.displayMode = .all
        contentWidth = 12 + CGFloat(otherViews.count) * (thumbnailSize + thumbnailSpacing) - thumbnailSpacing + padding
        scrollView!.contentSize = CGSize(width: contentWidth, height: thumbnailSize)
        
        // Activate all constraints at once
        NSLayoutConstraint.activate(activeConstraints)
        
        // Final check: ensure expanded view is visible and on top
        expandedView.ensureVisible()
        bringSubviewToFront(expandedView)
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 检查是否点击到 CallStreamView
        var hitCallStreamView = false
        
        for subview in subviews {
            if let streamView = subview as? CallStreamView,
               streamView.frame.contains(location) {
                hitCallStreamView = true
                break
            }
        }
        
        // 也检查 scrollView 中的视图
        if let scrollView = scrollView {
            let scrollLocation = touch.location(in: scrollView)
            for subview in scrollView.subviews {
                if let streamView = subview as? CallStreamView,
                   streamView.frame.contains(scrollLocation) {
                    hitCallStreamView = true
                    break
                }
            }
        }
        
        if !hitCallStreamView {
            // 点击了空白区域
            self.touchOtherArea?()
        }
    }
}

// MARK: - 改进现有动画方法（最简单的方案）
extension MultiPersonCallView {
    
    private func animateExpandViewImproved(_ viewToExpand: CallStreamView) {
        // Store current frame before any changes
        let originalFrame = viewToExpand.frame
        
        // Ensure the view to expand is visible and properly configured
        viewToExpand.ensureVisible()
        
        // If switching from another expanded view, ensure the new view is in the main view
        if viewToExpand.superview != self {
            viewToExpand.removeFromSuperview()
            addSubview(viewToExpand)
        }
        
        expandedView = viewToExpand
        // 不在这里单独设置 displayMode，使用统一方法
        
        for view in CallKitManager.shared.canvasCache.values {
            view.displayMode = (view == viewToExpand ? .all:.hidden)
            view.item.isExpanded = view == viewToExpand
            if viewToExpand.item.userId == view.item.userId {
                CallKitManager.shared.engine?.setRemoteVideoStream(UInt(view.item.uid), type: .high)
            } else {
                CallKitManager.shared.engine?.setRemoteVideoStream(UInt(view.item.uid), type: CallKitManager.shared.getStreamRenderQuality(with: UInt(CallKitManager.shared.canvasCache.count)))
            }
        }
        
        viewToExpand.item.isExpanded = true
        // Position view at original location
        viewToExpand.translatesAutoresizingMaskIntoConstraints = false
        viewToExpand.removeFromSuperview()
        addSubview(viewToExpand)
        viewToExpand.frame = originalFrame
        
        // Layout everything else without animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layoutItemsForExpandedState()
        layoutIfNeeded()
        
        // Get the final expanded frame
        let expandedFrame = viewToExpand.frame
        
        // Reset to original position
        viewToExpand.frame = originalFrame
        CATransaction.commit()
        
        // 使用更平滑的动画参数
        UIView.animate(
            withDuration: 0.35,  // 稍微延长动画时间
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction], // 允许用户交互
            animations: {
                viewToExpand.frame = expandedFrame
                
                // 添加轻微的透明度变化，增强视觉效果
                viewToExpand.alpha = 0.95
            },
            completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    viewToExpand.alpha = 1.0
                }
                self.layoutIfNeeded()
            }
        )
    }
    
    // 缩小动画也需要相应改进
    private func animateToNormalStateSmooth() {
        guard let currentExpanded = expandedView else { return }
        
        let expandedFrame = currentExpanded.frame
        expandedView = nil
        
        CallKitManager.shared.itemsCache.values.forEach { $0.isExpanded = false }
        var itemViews = CallKitManager.shared.canvasCache.values.sorted { $0.item.index > $1.item.index }

        // 不在这里单独设置 displayMode，使用统一方法
        updateAllDisplayModes()
        
        
        // Sort and prepare views
        itemViews.sort { $0.item.index < $1.item.index }
        itemViews.forEach { view in
            if view.superview != self {
                view.removeFromSuperview()
                addSubview(view)
            }
            view.ensureVisible()
        }
        
        // Get target frame
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layoutItemsForNormalState()
        layoutIfNeeded()
        let finalFrame = currentExpanded.frame
        currentExpanded.frame = expandedFrame
        CATransaction.commit()
        
        // Use keyframe animation for smoother shrinking
        UIView.animateKeyframes(withDuration: 0.5, delay: 0, options: [.calculationModeCubic], animations: {
            // First phase - start shrinking
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.6) {
                let intermediateSize = CGSize(
                    width: expandedFrame.width - (expandedFrame.width - finalFrame.width) * 0.7,
                    height: expandedFrame.height - (expandedFrame.height - finalFrame.height) * 0.7
                )
                let intermediateOrigin = CGPoint(
                    x: expandedFrame.origin.x + (finalFrame.origin.x - expandedFrame.origin.x) * 0.7,
                    y: expandedFrame.origin.y + (finalFrame.origin.y - expandedFrame.origin.y) * 0.7
                )
                currentExpanded.frame = CGRect(origin: intermediateOrigin, size: intermediateSize)
            }
            
            // Final phase - settle into position
            UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.4) {
                currentExpanded.frame = finalFrame
            }
            
            // Fade out scroll view
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
                self.scrollView?.alpha = 0
            }
        }, completion: { _ in
            self.scrollView?.removeFromSuperview()
            self.scrollView = nil
            self.layoutItemsForNormalState()
            self.layoutIfNeeded()
            itemViews.forEach { $0.ensureVisible() }
        })
    }
    
}

// MARK: - 智能空间腾挪的切换动画
extension MultiPersonCallView {
    
    private func switchExpandedViewWithSmartSpace(from oldView: CallStreamView, to newView: CallStreamView) {
        // 1. Record position of oldView
        let oldExpandedFrame = oldView.frame
        
        // 2. Get position of newView
        var newThumbnailFrame: CGRect = .zero
        var newViewOriginalIndex: Int = -1
        
        if let scrollView = scrollView, newView.superview == scrollView {
            newThumbnailFrame = scrollView.convert(newView.frame, to: self)
            
            // Find the original index of newView in scrollView
            let sortedViews = scrollView.subviews.compactMap { $0 as? CallStreamView }
                .sorted { $0.item.index > $1.item.index }
            newViewOriginalIndex = sortedViews.firstIndex(of: newView) ?? -1
        } else {
            newThumbnailFrame = newView.frame
        }
        for view in CallKitManager.shared.canvasCache.values {
            view.displayMode = (view == newView ? .all:.hidden)
            if newView.item.userId == view.item.userId {
                CallKitManager.shared.engine?.setRemoteVideoStream(UInt(view.item.uid), type: .high)
            } else {
                CallKitManager.shared.engine?.setRemoteVideoStream(UInt(view.item.uid), type: CallKitManager.shared.getStreamRenderQuality(with: UInt(CallKitManager.shared.canvasCache.count)))
            }
        }
        // update expanded view
        expandedView = newView
        oldView.item.isExpanded = false
        newView.item.isExpanded = true
        
        // 4. Move newView to the main view if it's in scrollView
        if newView.superview == scrollView {
            newView.removeFromSuperview()
            addSubview(newView)
            newView.frame = newThumbnailFrame
        }
        
        // 5. Calculate the target position for oldView
        let oldViewIndex = oldView.item.index
        var oldViewTargetPosition: Int = 0
        var needsSpaceAnimation = true
        
        // Calculate the target position for oldView in scrollView
        if let scrollView = scrollView {
            let existingViews = scrollView.subviews.compactMap { $0 as? CallStreamView }
                .sorted { $0.item.index > $1.item.index }
            
            for view in existingViews {
                if view.item.index < oldViewIndex {
                    oldViewTargetPosition += 1
                }
            }
            
            // Whether we need space animation depends on the target position
            let totalPositions = existingViews.count + 1 // Add going back old view
            if oldViewTargetPosition == totalPositions - 1 {
                // oldView will be the last one, no need for space animation
                needsSpaceAnimation = false
            }
        }
        
        // 6. Ready for move view animation
        var viewsToMove: [(view: CallStreamView, startX: CGFloat, endX: CGFloat)] = []
        let thumbnailSize: CGFloat = 72
        let thumbnailSpacing: CGFloat = 6
        let padding: CGFloat = 12
        
        if let scrollView = scrollView, needsSpaceAnimation {
            // Get the current stream views in scrollView
            let currentViews = scrollView.subviews.compactMap { $0 as? CallStreamView }
                .sorted { $0.item.index > $1.item.index }
            
            // Record the current positions of all views
            for (index, view) in currentViews.enumerated() {
                let currentX = view.frame.origin.x
                var targetX = currentX
                
                if oldViewTargetPosition == 0 {
                    // oldView will be the first, all views need to move right
                    targetX = padding + CGFloat(index + 1) * (thumbnailSize + thumbnailSpacing)
                } else if index >= oldViewTargetPosition {
                    // oldView will be the middle, shift views to the right
                    targetX = padding + CGFloat(index + 1) * (thumbnailSize + thumbnailSpacing)
                } else {
                    // The views before oldView stay in place
                    targetX = padding + CGFloat(index) * (thumbnailSize + thumbnailSpacing)
                }
                
                viewsToMove.append((view: view, startX: currentX, endX: targetX))
            }
            
            // 如果 newView 原本在 scrollView 中，需要调整它留下的空隙
            if newViewOriginalIndex >= 0 {
                // 重新计算，因为 newView 离开后的布局
                for i in 0..<viewsToMove.count {
                    let view = viewsToMove[i].view
                    if view.item.index > newView.item.index {
                        // 这些视图可以向左移动填补 newView 的空缺
                        viewsToMove[i].endX -= (thumbnailSize + thumbnailSpacing)
                    }
                }
            }
        }
        
        // 7. 创建 oldView 的快照并计算最终布局
        guard let oldViewSnapshot = oldView.snapshotView(afterScreenUpdates: false) else {
            print("⚠️ Failed to create snapshot")
            return
        }
        
        oldViewSnapshot.frame = oldExpandedFrame
        addSubview(oldViewSnapshot)
        
        // 隐藏原始 oldView
        oldView.isHidden = true
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // 将真实的 oldView 提前放入 scrollView 的正确位置
        if let scrollView = scrollView {
            oldView.removeFromSuperview()
            
            // 根据 index 插入到正确的层级位置
            let sortedViews = scrollView.subviews.compactMap { $0 as? CallStreamView }
                .sorted { $0.item.index > $1.item.index }
            
            var insertAtIndex = 0
            for view in sortedViews {
                if view.item.index < oldView.item.index {
                    insertAtIndex += 1
                } else {
                    break
                }
            }
            //TODO: - oldview 变为小流
            scrollView.insertSubview(oldView, at: insertAtIndex)
        }
        
        layoutItemsForExpandedState()
        layoutIfNeeded()
        
        let newExpandedFrame = newView.frame
        var oldThumbnailFrameInScrollView: CGRect = .zero
        var oldThumbnailFrameInMainView: CGRect = .zero
        
        if let scrollView = scrollView {
            oldThumbnailFrameInScrollView = oldView.frame
            oldThumbnailFrameInMainView = scrollView.convert(oldView.frame, to: self)
            
            // 设置真实 oldView 的初始状态：完全透明但可见
            oldView.alpha = 0
            oldView.isHidden = false
        }
        
        // 重置 newView 到动画开始位置
        newView.frame = newThumbnailFrame
        
        CATransaction.commit()
        
        // 8. 执行动画
        // 第一步：快速为 oldView 腾出空间（如果需要）
        if needsSpaceAnimation && !viewsToMove.isEmpty {
            UIView.animate(withDuration: 0.25,
                          delay: 0,
                          options: [.curveEaseOut],
                          animations: {
                // 快速移动视图，腾出空间
                for (view, _, endX) in viewsToMove {
                    view.frame.origin.x = endX
                }
            })
        }
        
        self.scrollView?.addSubview(oldView)
        oldView.translatesAutoresizingMaskIntoConstraints = false
        
        let leadingConstant = 12 + CGFloat(oldViewIndex) * (thumbnailSize + thumbnailSpacing)
        
        self.activeConstraints += [
            oldView.leadingAnchor.constraint(equalTo: self.scrollView!.leadingAnchor, constant: leadingConstant),
            oldView.centerYAnchor.constraint(equalTo: self.scrollView!.centerYAnchor),
            oldView.widthAnchor.constraint(equalToConstant: thumbnailSize),
            oldView.heightAnchor.constraint(equalToConstant: thumbnailSize)
        ]
        oldView.alpha = 0
        // 第二步：主动画 - 使用纯线性动画
        UIView.animate(withDuration: 0.37,
                      delay: needsSpaceAnimation ? 0.1 : 0,
                      options: [.curveLinear], // 使用线性曲线
                      animations: {
            // oldView 快照线性缩小到目标位置
            oldViewSnapshot.frame = oldThumbnailFrameInMainView
            
            // 真实 oldView 线性渐显
            oldView.alpha = 1.0
        }, completion: { _ in
            // 移除快照
            oldViewSnapshot.removeFromSuperview()
            
        })
        
        // newView 展开动画 - 同样使用线性动画
        UIView.animate(withDuration: 0.39,
                      delay: 0.05,
                      options: [.curveLinear], // 线性曲线
                      animations: {
            // 线性展开到目标位置
            newView.frame = newExpandedFrame
            
            // 确保层级正确
            self.bringSubviewToFront(newView)
        }, completion: { _ in
            // 确保视图可见
            newView.ensureVisible()
            self.updateAllDisplayModes()
        })
    }
}
