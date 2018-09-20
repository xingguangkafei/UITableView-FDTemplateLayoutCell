// The MIT License (MIT)
//
// Copyright (c) 2015-2016 forkingdog ( https://github.com/forkingdog )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "UITableView+FDTemplateLayoutCell.h"
#import <objc/runtime.h>

@implementation UITableView (FDTemplateLayoutCell)

/*
 参数：是仅仅用来计算的 cell高度的 布局cell
 */
- (CGFloat)fd_systemFittingHeightForConfiguratedCell:(UITableViewCell *)cell {
    // 获取 布局cell 所在的UITableView的宽度
    CGFloat contentViewWidth = CGRectGetWidth(self.frame);
    // 设置 布局cell 的宽度为UITableView的宽度
    CGRect cellBounds = cell.bounds;
    cellBounds.size.width = contentViewWidth;
    cell.bounds = cellBounds;
    // UITableViewIndex
    CGFloat rightSystemViewsWidth = 0.0;
    for (UIView *view in self.subviews) {
        /*
         NSLog(@"[view class]: %@",[view class]);
         2018-09-20 17:43:41.989039+0800 Demo[2432:80324] [view class]: UIRefreshControl
         2018-09-20 17:43:41.989134+0800 Demo[2432:80324] [view class]: UIView
         2018-09-20 17:43:41.989234+0800 Demo[2432:80324] [view class]: UIView
         2018-09-20 17:43:41.989314+0800 Demo[2432:80324] [view class]: UITableViewIndex
         */
        if ([view isKindOfClass:NSClassFromString(@"UITableViewIndex")]) {
            // view.backgroundColor = [UIColor redColor];
            // 这个View是右侧的View，例如微信的通讯录页面的右侧的字母列表的底部的一个长条View
            // 获取这个View的宽度
            rightSystemViewsWidth = CGRectGetWidth(view.frame);
            break;
        }
    }
    // accessory View 可以参考这里 https://www.jianshu.com/p/c6e73527f987
    // If a cell has accessory view or system accessory type, its content view's width is smaller
    // than cell's by some fixed values.
    if (cell.accessoryView) { // 如果有系统 accesory view 的话 就 再加个额外宽度16
        rightSystemViewsWidth += 16 + CGRectGetWidth(cell.accessoryView.frame);
    } else { // 如果没有  accesory view 
        // 用一个 静态 枚举常量数组，这个写法，还真没见过
        static const CGFloat systemAccessoryWidths[] = {
            [UITableViewCellAccessoryNone] = 0,
            [UITableViewCellAccessoryDisclosureIndicator] = 34,
            [UITableViewCellAccessoryDetailDisclosureButton] = 68,
            [UITableViewCellAccessoryCheckmark] = 40,
            [UITableViewCellAccessoryDetailButton] = 48
        };
        rightSystemViewsWidth += systemAccessoryWidths[cell.accessoryType];
    }
    // 关于 scale 看这里 https://www.jianshu.com/p/878e61c2d047
    // 如果分辨率 >= 3 切 宽大于414 (也就是6p以及以上屏幕大小)
    if ([UIScreen mainScreen].scale >= 3 && [UIScreen mainScreen].bounds.size.width >= 414) {
        rightSystemViewsWidth += 4; // 研究的真是精细
    }
    // 内容宽度为 UITableView的宽度减去 右边需要余下的宽度
    contentViewWidth -= rightSystemViewsWidth;

    
    // If not using auto layout, you have to override "-sizeThatFits:" to provide a fitting size by yourself.
    // This is the same height calculation passes used in iOS8 self-sizing cell's implementation.
    //
    // 1. Try "- systemLayoutSizeFittingSize:" first. (skip this step if 'fd_enforceFrameLayout' set to YES.)
    // 2. Warning once if step 1 still returns 0 when using AutoLayout
    // 3. Try "- sizeThatFits:" if step 1 returns 0
    // 4. Use a valid height or default row height (44) if not exist one
    /*
     如果不用 auto layout, 那么你就一定要重写 -sizeThatFits: 方法 来计算合适的大小
     这个计算结果和 iOS8的 self-sizing 一样
     
     1，先调用 - systemLayoutSizeFittingSize:（如果fd_enforceFrameLayout为YES的话，这一步跳过）
     2，如果第一步调用了还是返回0，那么就给一次警告
     3，如果第一步返回0，那么就尝试一下 - sizeThatFits: 方法
     4，如果还是搞不定，那么就用一个固定值代替
     */
    CGFloat fittingHeight = 0;
    
    // 如果使用layout布局方式，并且，(UITableView这个时候的宽度大于 0（这个什么 ？）)
    if (!cell.fd_enforceFrameLayout && contentViewWidth > 0) {
        // Add a hard width constraint to make dynamic content views (like labels) expand vertically instead
        // of growing horizontally, in a flow-layout manner.
        /*
          Create constraints explicitly.  Constraints are of the form "view1.attr1 = view2.attr2 * multiplier + constant"
         If your equation does not have a second view and attribute, use nil and NSLayoutAttributeNotAnAttribute.
         
         NSLayoutConstraint 这个类
         明确的创建一个约束条件。
         约束条件是这样的一个格式： view1的属性 = view2的属性 乘以 倍数 + 常量
         如果你没有第二个View和属性，那么久传递nil和NSLayoutAttributeNotAnAttribute，这两个参数
         Fence: 栅栏；围墙；
         */
        // 宽度栅栏约束 设置cell的内容View的宽度为 UITableView除去
        NSLayoutConstraint *widthFenceConstraint = [NSLayoutConstraint constraintWithItem:cell.contentView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:contentViewWidth];

        // [bug fix] after iOS 10.3, Auto Layout engine will add an additional 0 width constraint onto cell's content view, to avoid that, we add constraints to content view's left, right, top and bottom.
        // 修复bug，ios10.3 之后，自动布局引擎会添加一个 额外的为0的的约束到 cell的内容View
        // 为了避免那样，我们添加约束到cell的内容View的：左右上下
        // 这个值的赋值方式，实在是值得学习
        static BOOL isSystemVersionEqualOrGreaterThen10_2 = NO;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            isSystemVersionEqualOrGreaterThen10_2 = [UIDevice.currentDevice.systemVersion compare:@"10.2" options:NSNumericSearch] != NSOrderedAscending;
        });
        
        NSArray<NSLayoutConstraint *> *edgeConstraints;
        if (isSystemVersionEqualOrGreaterThen10_2) {
            // To avoid confilicts, make width constraint softer than required (1000)
            widthFenceConstraint.priority = UILayoutPriorityRequired - 1;
            /*
             宽度栅栏约束的优先级只比最高优先级低 1
             UILayoutPriorityRequired： A required constraint.  Do not exceed this.
             UILayoutPriorityRequired：一个必须的约束，不要超过这个数值
             exceed：超过；胜过
             */
            
            // Build edge constraints: 创建边缘约束
            // 左边约束：cell的内容View 的左边 挨着 cell的左边
            NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:cell.contentView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:cell attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0];
            // 右边约束：cell的内容View 的右边 挨着 (cell的右边 - 右边要系统要占用的View的宽度)
            NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:cell.contentView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:cell attribute:NSLayoutAttributeRight multiplier:1.0 constant:-rightSystemViewsWidth];
            // 顶部约束：cell的内容View 的顶部 挨着cell的顶部
            NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:cell.contentView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:cell attribute:NSLayoutAttributeTop multiplier:1.0 constant:0];
            // 底部约束：cell内容View 的底部 挨着cell的底部
            NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:cell.contentView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:cell attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];
            edgeConstraints = @[leftConstraint, rightConstraint, topConstraint, bottomConstraint];
            // 把这几个约束添加到cell上
            [cell addConstraints:edgeConstraints];
        }
        
        [cell.contentView addConstraint:widthFenceConstraint];

        // Auto layout engine does its math
        // 自动布局引擎 根据cell布局计算cell高度
        fittingHeight = [cell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
        
        // Clean-ups
        // 移除view的内容View上的所有约束
        [cell.contentView removeConstraint:widthFenceConstraint];
        if (isSystemVersionEqualOrGreaterThen10_2) {
            [cell removeConstraints:edgeConstraints];
        }
        // 以上约束添加后又移除了，难道是因为cell不显示出来，然后就...
        // 打印系统的自动布局计算出来cell高度
        [self fd_debugLog:[NSString stringWithFormat:@"calculate using system fitting size (AutoLayout) - %@", @(fittingHeight)]];
    }
    // 如果自动布局算出来的高度为0的话
    if (fittingHeight == 0) {
#if DEBUG
        // Warn if using AutoLayout but get zero height.
        if (cell.contentView.constraints.count > 0) {
            // 如果到这里，就说明cell里的布局有问题
            /*
             这里的 objc_getAssociatedObject 用法也挺妙的，因为 _cmd 代表一个selector
             objc_getAssociatedObject(self, _cmd) 这一句相当于拿这个 seletor 做了一个分类的动态添加属性
             这里 https://www.jianshu.com/p/fdb1bc445266
             */
            if (!objc_getAssociatedObject(self, _cmd)) {
                NSLog(@"[FDTemplateLayoutCell] Warning once only: Cannot get a proper cell height (now 0) from '- systemFittingSize:'(AutoLayout). You should check how constraints are built in cell, making it into 'self-sizing' cell.");
                objc_setAssociatedObject(self, _cmd, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
#endif
        // Try '- sizeThatFits:' for frame layout.
        // Note: fitting height should not include separator view.
        // 用sizeThatFits 方法计算cell高度。关于sizeThatFits 看这里 https://www.jianshu.com/p/bdd644b797c3
        fittingHeight = [cell sizeThatFits:CGSizeMake(contentViewWidth, 0)].height;
        
        [self fd_debugLog:[NSString stringWithFormat:@"calculate using sizeThatFits - %@", @(fittingHeight)]];
    }
    
    // Still zero height after all above.
    if (fittingHeight == 0) {
        // Use default row height.
        fittingHeight = 44;
    }
    
    // Add 1px extra space for separator line if needed, simulating default UITableViewCell.
    // 如果有cell的横线，那么高度就加一个像素的高度，模仿默认的UITableViewCell
    if (self.separatorStyle != UITableViewCellSeparatorStyleNone) {
        fittingHeight += 1.0 / [UIScreen mainScreen].scale;
    }
    // 到此计算出了cell的高度
    return fittingHeight;
}
// 用cellid 获取一个cell
- (__kindof UITableViewCell *)fd_templateCellForReuseIdentifier:(NSString *)identifier {
    NSAssert(identifier.length > 0, @"Expect a valid identifier - %@", identifier);
    // cell用一个tableView的字典存储，key是cellid字符串，value是cell
    NSMutableDictionary<NSString *, UITableViewCell *> *templateCellsByIdentifiers = objc_getAssociatedObject(self, _cmd);
    if (!templateCellsByIdentifiers) {
        templateCellsByIdentifiers = @{}.mutableCopy;
        objc_setAssociatedObject(self, _cmd, templateCellsByIdentifiers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // 从字典取出cell
    UITableViewCell *templateCell = templateCellsByIdentifiers[identifier];
    
    if (!templateCell) { // 如果没有
        templateCell = [self dequeueReusableCellWithIdentifier:identifier]; // 如果没有，那么就从系统缓存池里取
        NSAssert(templateCell != nil, @"Cell must be registered to table view for identifier - %@", identifier);
        templateCell.fd_isTemplateLayoutCell = YES; // 标明这是一个仅仅用来计算 布局cell 的 cell
        templateCell.contentView.translatesAutoresizingMaskIntoConstraints = NO; // 关闭cell的contentView的自动布局
        templateCellsByIdentifiers[identifier] = templateCell; // 把cell保存到字典里
        [self fd_debugLog:[NSString stringWithFormat:@"layout cell created - %@", identifier]]; // 打印这个计算 布局cell的 cellid
    }
    
    return templateCell;
}
// 用cellid标识符，获取cell的高度，传进来一个block
- (CGFloat)fd_heightForCellWithIdentifier:(NSString *)identifier configuration:(void (^)(id cell))configuration {
    if (!identifier) {
        return 0;
    }
    // 获取一个仅仅用来计算的 cell高度的 布局cell
    UITableViewCell *templateLayoutCell = [self fd_templateCellForReuseIdentifier:identifier];
    
    // Manually calls to ensure consistent behavior with actual cells. (that are displayed on screen)
    // 手动调用这个方法，可以确保显示到屏幕上的cell，真的计算过一次cell内容了
    // 可以看这里 https://www.jianshu.com/p/e153ec626847
    [templateLayoutCell prepareForReuse];
    
    // Customize and provide content for our template cell.
    // 调用自定义的一些代码，比如我自己写好的cell上的model赋值，cell是否用 布局cell 来布局
    if (configuration) {
        configuration(templateLayoutCell);
    }
    /*
     参数：是仅仅用来计算的 cell高度的 布局cell
     */
    return [self fd_systemFittingHeightForConfiguratedCell:templateLayoutCell];
}

- (CGFloat)fd_heightForCellWithIdentifier:(NSString *)identifier cacheByIndexPath:(NSIndexPath *)indexPath configuration:(void (^)(id cell))configuration {
    if (!identifier || !indexPath) {
        return 0;
    }
    
    // Hit cache
    if ([self.fd_indexPathHeightCache existsHeightAtIndexPath:indexPath]) {
        [self fd_debugLog:[NSString stringWithFormat:@"hit cache by index path[%@:%@] - %@", @(indexPath.section), @(indexPath.row), @([self.fd_indexPathHeightCache heightForIndexPath:indexPath])]];
        return [self.fd_indexPathHeightCache heightForIndexPath:indexPath];
    }
    
    CGFloat height = [self fd_heightForCellWithIdentifier:identifier configuration:configuration];
    [self.fd_indexPathHeightCache cacheHeight:height byIndexPath:indexPath];
    [self fd_debugLog:[NSString stringWithFormat: @"cached by index path[%@:%@] - %@", @(indexPath.section), @(indexPath.row), @(height)]];
    
    return height;
}

- (CGFloat)fd_heightForCellWithIdentifier:(NSString *)identifier cacheByKey:(id<NSCopying>)key configuration:(void (^)(id cell))configuration {
    if (!identifier || !key) {
        return 0;
    }
    
    // Hit cache
    if ([self.fd_keyedHeightCache existsHeightForKey:key]) {
        CGFloat cachedHeight = [self.fd_keyedHeightCache heightForKey:key];
        [self fd_debugLog:[NSString stringWithFormat:@"hit cache by key[%@] - %@", key, @(cachedHeight)]];
        return cachedHeight;
    }
    
    CGFloat height = [self fd_heightForCellWithIdentifier:identifier configuration:configuration];
    [self.fd_keyedHeightCache cacheHeight:height byKey:key];
    [self fd_debugLog:[NSString stringWithFormat:@"cached by key[%@] - %@", key, @(height)]];
    
    return height;
}

@end

@implementation UITableView (FDTemplateLayoutHeaderFooterView)

- (__kindof UITableViewHeaderFooterView *)fd_templateHeaderFooterViewForReuseIdentifier:(NSString *)identifier {
    NSAssert(identifier.length > 0, @"Expect a valid identifier - %@", identifier);
    
    NSMutableDictionary<NSString *, UITableViewHeaderFooterView *> *templateHeaderFooterViews = objc_getAssociatedObject(self, _cmd);
    if (!templateHeaderFooterViews) {
        templateHeaderFooterViews = @{}.mutableCopy;
        objc_setAssociatedObject(self, _cmd, templateHeaderFooterViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    UITableViewHeaderFooterView *templateHeaderFooterView = templateHeaderFooterViews[identifier];
    
    if (!templateHeaderFooterView) {
        templateHeaderFooterView = [self dequeueReusableHeaderFooterViewWithIdentifier:identifier];
        NSAssert(templateHeaderFooterView != nil, @"HeaderFooterView must be registered to table view for identifier - %@", identifier);
        templateHeaderFooterView.contentView.translatesAutoresizingMaskIntoConstraints = NO;
        templateHeaderFooterViews[identifier] = templateHeaderFooterView;
        [self fd_debugLog:[NSString stringWithFormat:@"layout header footer view created - %@", identifier]];
    }
    
    return templateHeaderFooterView;
}

- (CGFloat)fd_heightForHeaderFooterViewWithIdentifier:(NSString *)identifier configuration:(void (^)(id))configuration {
    UITableViewHeaderFooterView *templateHeaderFooterView = [self fd_templateHeaderFooterViewForReuseIdentifier:identifier];
    
    NSLayoutConstraint *widthFenceConstraint = [NSLayoutConstraint constraintWithItem:templateHeaderFooterView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:CGRectGetWidth(self.frame)];
    [templateHeaderFooterView addConstraint:widthFenceConstraint];
    CGFloat fittingHeight = [templateHeaderFooterView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    [templateHeaderFooterView removeConstraint:widthFenceConstraint];
    
    if (fittingHeight == 0) {
        fittingHeight = [templateHeaderFooterView sizeThatFits:CGSizeMake(CGRectGetWidth(self.frame), 0)].height;
    }
    
    return fittingHeight;
}

@end

@implementation UITableViewCell (FDTemplateLayoutCell)

- (BOOL)fd_isTemplateLayoutCell {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_isTemplateLayoutCell:(BOOL)isTemplateLayoutCell {
    objc_setAssociatedObject(self, @selector(fd_isTemplateLayoutCell), @(isTemplateLayoutCell), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)fd_enforceFrameLayout {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_enforceFrameLayout:(BOOL)enforceFrameLayout {
    objc_setAssociatedObject(self, @selector(fd_enforceFrameLayout), @(enforceFrameLayout), OBJC_ASSOCIATION_RETAIN);
}

@end
