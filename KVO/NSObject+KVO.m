//
//  NSObject+KVO.m
//  KVO
//
//  Created by UED on 2020/10/27.
//

#import "NSObject+KVO.h"
#import <objc/message.h>

@interface CTKVOInfo : NSObject

@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, assign) NSKeyValueObservingOptions options;
@property (nonatomic, copy) CTKVOBlock handleBlock;
@property (nonatomic) SEL action;
@property (nonatomic) void *context;

- (instancetype)initWithObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(nullable CTKVOBlock)block;
- (instancetype)initWithObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options action:(SEL)action;
- (instancetype)initWithObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context;

@end

@implementation CTKVOInfo

- (instancetype)initWithObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(nullable CTKVOBlock)block action:(nullable SEL)action context:(nullable void *)context {
    self = [super init];
    if (self) {
        self.observer = observer;
        self.keyPath = keyPath;
        self.options = options;
        self.handleBlock = block;
        self.action = action;
        self.context = context;
    }
    return self;
}

- (instancetype)initWithObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(nullable CTKVOBlock)block {
    return [self initWithObserver:observer forKeyPath:keyPath options:options block:block action:NULL context:NULL];
}

- (instancetype)initWithObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options action:(SEL)action {
    return [self initWithObserver:observer forKeyPath:keyPath options:options block:NULL action:action context:NULL];
}

- (instancetype)initWithObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context {
    return [self initWithObserver:observer forKeyPath:keyPath options:options block:NULL action:NULL context:context];
}

@end

static NSString *const kCTKVOPrefix = @"CTKVONotifying_";
static NSString *const kCTKVOAssiociateKey = @"CTKVO_AssiociateKey";

@implementation NSObject (KVO)

//+ (void)load {
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        [self customHookOrigInstanceMethod:NSSelectorFromString(@"dealloc") newInstanceMethod:@selector(myDealloc)];
//    });
//}

+ (BOOL)customHookOrigInstanceMethod:(SEL)oriSEL newInstanceMethod:(SEL)swizzledSEL {
    Class cls = self;
    Method oriMethod = class_getInstanceMethod(cls, oriSEL);
    Method swiMethod = class_getInstanceMethod(cls, swizzledSEL);
    
    if (!swiMethod) {
        return NO;
    }
    if (!oriMethod) {
        class_addMethod(cls, oriSEL, method_getImplementation(swiMethod), method_getTypeEncoding(swiMethod));
        method_setImplementation(swiMethod, imp_implementationWithBlock(^(id self, SEL _cmd){ }));
    }
    
    BOOL didAddMethod = class_addMethod(cls, oriSEL, method_getImplementation(swiMethod), method_getTypeEncoding(swiMethod));
    if (didAddMethod) {
        class_replaceMethod(cls, swizzledSEL, method_getImplementation(oriMethod), method_getTypeEncoding(oriMethod));
    } else {
        method_exchangeImplementations(oriMethod, swiMethod);
    }
    return YES;
}

- (void)customAddObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context {
    [self customAddObserver:observer forKeyPath:keyPath options:options context:context handlerBlock:nil];
}

- (void)customAddObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context action:(SEL)action {
    [self customAddObserver:observer forKeyPath:keyPath options:options context:context handlerBlock:nil action:action];
}

- (void)customAddObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context handlerBlock:(CTKVOBlock)handlerBlock {
    [self customAddObserver:observer forKeyPath:keyPath options:options context:context handlerBlock:handlerBlock action:NULL];
}

- (void)customAddObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context handlerBlock:(nullable CTKVOBlock)handlerBlock action:(nullable SEL)action {
    // 验证是否存在setter方法
    [self judgeSetterMethodFromKeyPath:keyPath];
    // 动态生成子类
    Class newClass = [self createChildClassWithKeyPath:keyPath];
    // 添加setter方法
    SEL setterSel = NSSelectorFromString(setterForGetter(keyPath));
    Method method = class_getInstanceMethod(self.class, setterSel);
    const char *type = method_getTypeEncoding(method);
    class_addMethod(newClass, setterSel, (IMP)customSetter, type);
    // 修改isa指向
    object_setClass(self, newClass);
    
    // 保存观察者信息
    CTKVOInfo *info = [[CTKVOInfo alloc] initWithObserver:observer forKeyPath:keyPath options:options block:handlerBlock action:action context:context];
    NSMutableDictionary *observerMap = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kCTKVOAssiociateKey));
    if (!observerMap) {
        observerMap = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(kCTKVOAssiociateKey), observerMap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observerMap setObject:info forKey:info.keyPath];
}

#pragma mark - 验证是否存在setter方法
- (void)judgeSetterMethodFromKeyPath:(NSString *)keyPath {
    Class superClass = object_getClass(self);
    SEL setterSelector = NSSelectorFromString(setterForGetter(keyPath));
    Method setterMethod = class_getInstanceMethod(superClass, setterSelector);
    if (!setterMethod) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"当前%@没有实现setter的%@方法",self, keyPath] userInfo:nil];
    }
}

#pragma mark - 从get方法获取set方法的名称
static NSString *setterForGetter(NSString *getter) {
    if (getter.length <= 0) {
        return nil;
    }
    NSString *firstString = [[getter substringToIndex:1] uppercaseString];
    NSString *leaveString = [getter substringFromIndex:1];
    return [NSString stringWithFormat:@"set%@%@:", firstString, leaveString];
}

#pragma mark - 从set方法获取getter方法的名称
static NSString *getterForSetter(NSString *setter) {
    if (setter.length <= 0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *getter = [setter substringWithRange:range];
    NSString *firstString = [[getter substringToIndex:1] lowercaseString];
    return [getter stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:firstString];
}

#pragma mark - 注册添加子类
- (Class)createChildClassWithKeyPath:(NSString *)keyPath {
    NSString *oldClassName = NSStringFromClass([self class]);
    NSString *newClassName = [NSString stringWithFormat:@"%@%@", kCTKVOPrefix, oldClassName];
    Class newClass = NSClassFromString(newClassName);
    // 判断是否已经创建过
    if (newClass) {
        return newClass;
    }
    // 申请类
    newClass = objc_allocateClassPair([self class], newClassName.UTF8String, 0);
    // 注册类
    objc_registerClassPair(newClass);
    // 添加class方法
    SEL classSel = NSSelectorFromString(@"class");
    Method classMethod = class_getInstanceMethod([self class], classSel);
    const char *classType = method_getTypeEncoding(classMethod);
    class_addMethod(newClass, classSel, (IMP)customClass, classType);
    
    // 添加dealloc方法
    SEL deallocSel = NSSelectorFromString(@"dealloc");
    Method deallocMethod = class_getInstanceMethod([self class], deallocSel);
    const char *deallocType = method_getTypeEncoding(deallocMethod);
    class_addMethod(newClass, deallocSel, (IMP)customDealloc, deallocType);
    // 添加_isKVO方法
//    SEL isKVOSel = NSSelectorFromString(@"_isKVO");
//    Method isKVOMethod = class_getInstanceMethod(self.class, isKVOSel);
//    const char *isKVOType = method_getTypeEncoding(isKVOMethod);
//    class_addMethod(newClass, isKVOSel, (IMP)_isKVO, isKVOType);
    
    return newClass;
}

BOOL _isKVO(id self, SEL _cmd) {
    return true;
}

Class customClass(id self, SEL _cmd) {
    return class_getSuperclass(object_getClass(self));
}

static void customDealloc(id self, SEL _cmd) {
    NSLog(@"走了这里");
//    NSMutableDictionary *observerMap = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)kCTKVOAssiociateKey);
//    if (observerMap.count > 0) {
//        [observerMap removeAllObjects];
//        objc_setAssociatedObject(self, (__bridge const void * _Nonnull)kCTKVOAssiociateKey, observerMap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//    }
    Class superClass = [self class];
    object_setClass(self, superClass);
//    [self customDealloc];
//    NSLog(@"self = %@", self);
}

static void customSetter(id self, SEL _cmd, id newValue) {
    NSLog(@"来了:%@", newValue);
    NSString *keyPath = getterForSetter(NSStringFromSelector(_cmd));
    id oldValue = [self valueForKey:keyPath];
    // 消息转发，转发给父类
    void (*custom_msgSendSuper)(void *, SEL, id) = (void *)objc_msgSendSuper;
    struct objc_super superStruct = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self)),
    };
    custom_msgSendSuper(&superStruct, _cmd, newValue);
    
    // 信息数据回调
    NSMutableDictionary *observerMap = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)kCTKVOAssiociateKey);
    CTKVOInfo *info = [observerMap objectForKey:keyPath];
    if (info) {
        [self customFunctionBlockWithInfo:info oldValue:oldValue newValue:newValue];
    }
}

- (void)customFunctionBlockWithInfo:(CTKVOInfo *)info oldValue:(NSString *)oldValue newValue:(NSString *)newValue {
    NSMutableDictionary<NSKeyValueChangeKey, id> *change = [NSMutableDictionary dictionary];
    if (info.options & (info.options & NSKeyValueObservingOptionNew)) {
        [change setObject:newValue forKey:NSKeyValueChangeNewKey];
    } else {
        [change setObject:oldValue ? oldValue : @"" forKey:NSKeyValueChangeOldKey];
    }
    if (info.handleBlock) {
        info.handleBlock(info.observer, info.keyPath, change, info.context);
    } else if ([info.observer respondsToSelector:@selector(customObserveValueForKeyPath:ofObject:change:context:)]) {
        [info.observer customObserveValueForKeyPath:info.keyPath ofObject:info.observer change:change context:info.context];
    } else if ([info.observer respondsToSelector:info.action]) {
        NSDictionary *infoDic = @{@"observer": info.observer, @"keyPath": info.keyPath, @"change": change};
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [info.observer performSelector:info.action withObject:infoDic];
#pragma clang pop
    } else if ([info.observer respondsToSelector:@selector(observeValueForKeyPath:ofObject:change:context:)]) {
        [info.observer observeValueForKeyPath:info.keyPath ofObject:info.observer change:change context:info.context];
    }
}

- (void)customRemoveObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    NSMutableDictionary *observerMap = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)kCTKVOAssiociateKey);
    [observerMap removeObjectForKey:keyPath];
    objc_setAssociatedObject(self, (__bridge const void * _Nonnull)kCTKVOAssiociateKey, observerMap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // 指回给父类，注当前类为 CTKVONotifying_ 的子类
    if (observerMap.count <= 0) {
//        Class superClass = [self class];
//        object_setClass(self, superClass);
    }
}

@end


