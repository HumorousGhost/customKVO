//
//  NSObject+KVO.h
//  KVO
//
//  Created by UED on 2020/10/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// KVO 响应式 + 函数式
// y = f(x) 可以转化为 y = f(f(z))
// 其中 x = f(z)，即x变成一个函数传入
// 那么x就为block
typedef void(^CTKVOBlock)(id observer, NSString *keyPath, NSDictionary<NSKeyValueChangeKey, id> *change, void * context);

@interface NSObject (KVO)
// 添加监听函数
- (void)customAddObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context;
// 添加监听函数
- (void)customAddObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context handlerBlock:(nullable CTKVOBlock)handlerBlock;

- (void)customAddObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context action:(nullable SEL)action;

// 移除监听函数
- (void)customRemoveObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;

// 监听回调函数
- (void)customObserveValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context;

+ (BOOL)customAutomaticallyNotifiesObserversForKey:(NSString *)akey;

- (void)customWillChangeValueForKey:(NSString *)key;

- (void)customDidChangeValueForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
