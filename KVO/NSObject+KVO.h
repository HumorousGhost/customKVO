//
//  NSObject+KVO.h
//  KVO
//
//  Created by UED on 2020/10/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^CTKVOBlock)(id observer, NSString *keyPath, id oldValue, id newValue, void * context);

@interface NSObject (KVO)
// 添加监听函数
- (void)customAddObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context;
// 添加监听函数
- (void)customAddObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context handlerBlock:(nullable CTKVOBlock)handlerBlock;
// 移除监听函数
- (void)customRemoveObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;

// 监听回调函数
- (void)customObserveValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;

@end

NS_ASSUME_NONNULL_END
