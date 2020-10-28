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

- (NSUInteger)hash {
    return [self.keyPath hash];
}

- (BOOL)isEqual:(id)object {
    if (nil == object) {
        return false;
    }
    if (self == object) {
        return true;
    }
    if (![object isKindOfClass:self.class]) {
        return false;
    }
    return [self.keyPath isEqualToString:((CTKVOInfo *)object)->_keyPath];
}

@end

static NSString *const kCTKVOPrefix = @"CTKVONotifying_";
static NSString *const kCTKVOAssiociateKey = @"CTKVO_AssiociateKey";

@implementation NSObject (KVO)

+ (void)load {
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        [self customHookOrigInstanceMethod:NSSelectorFromString(@"dealloc") newInstanceMethod:@selector(customDealloc)];
//    });
}

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

- (void)customAddObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context handlerBlock:(nullable CTKVOBlock)handlerBlock {
    // 验证是否存在setter方法
    [self judgeSetterMethodFromKeyPath:keyPath];
    // 动态生成子类
    Class newClass = [self createChildClassWithKeyPath:keyPath];
    // 修改isa指向
    object_setClass(self, newClass);
    // 保存观察者信息
    CTKVOInfo *info = [[CTKVOInfo alloc] initWithObserver:observer forKeyPath:keyPath options:options block:handlerBlock action:NULL context:context];
    NSMutableArray *observerArray = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kCTKVOAssiociateKey));
    if (!observerArray) {
        observerArray = [NSMutableArray arrayWithCapacity:1];
        objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(kCTKVOAssiociateKey), observerArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observerArray addObject:info];
}

#pragma mark - 验证是否存在setter方法
- (void)judgeSetterMethodFromKeyPath:(NSString *)keyPath {
    Class superClass = object_getClass(self);
    SEL setterSelector = NSSelectorFromString(setterForGetter(keyPath));
    Method setterMethod = class_getInstanceMethod(superClass, setterSelector);
    if (!setterMethod) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"当前%@没有实现setter方法", keyPath] userInfo:nil];
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
    NSString *oldClassName = NSStringFromClass(self.class);
    NSString *newClassName = [NSString stringWithFormat:@"%@%@", kCTKVOPrefix, oldClassName];
    Class newClass = NSClassFromString(newClassName);
    // 判断是否已经创建过
    if (newClass) {
        return newClass;
    }
    // 申请类
    newClass = objc_allocateClassPair(self.class, newClassName.UTF8String, 0);
    // 注册类
    objc_registerClassPair(newClass);
    // 添加方法
    SEL setterSel = NSSelectorFromString(setterForGetter(keyPath));
    Method method = class_getInstanceMethod(self.class, setterSel);
    const char *type = method_getTypeEncoding(method);
    class_addMethod(newClass, setterSel, (IMP)customSetter, type);
    return newClass;
}

static void customSetter(id self, SEL _cmd, id newValue) {
    NSString *keyPath = getterForSetter(NSStringFromSelector(_cmd));
    id oldValue = [self valueForKey:keyPath];
    // 消息转发，转发给父类
    void (*ct_msgSendSuper)(void *, SEL, id) = (void *)objc_msgSendSuper;
    struct objc_super superStruct = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self)),
    };
    ct_msgSendSuper(&superStruct, _cmd, newValue);
    
    // 信息数据回调
    NSMutableArray *array = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)kCTKVOAssiociateKey);
    for (CTKVOInfo *info in array) {
        if ([info.keyPath isEqualToString:keyPath] && info.handleBlock) {
            info.handleBlock(info.observer, keyPath, oldValue, newValue, info.context);
            break;
        } else if ([info.keyPath isEqualToString:keyPath] && [info.observer respondsToSelector:@selector(customObserveValueForKeyPath:ofObject:change:context:)]) {
            [info.observer customObserveValueForKeyPath:keyPath ofObject:info.observer change:@{@"oldValue": oldValue ? oldValue : @"", @"newValue": newValue} context:info.context];
        }
    }
}

- (void)customRemoveObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    NSMutableArray *observerArray = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)kCTKVOAssiociateKey);
    if (observerArray.count <= 0) {
        return;
    }
    for (CTKVOInfo *info in observerArray) {
        if ([info.keyPath isEqualToString:keyPath]) {
            [observerArray removeObject:info];
            objc_setAssociatedObject(self, (__bridge const void * _Nonnull)kCTKVOAssiociateKey, observerArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            break;
        }
    }
    
    if (observerArray.count <= 0) {
        // 指回给父类，注当前类为 CTKVONotifying_ 的子类
        Class superClass = [self superclass];
        object_setClass(self, superClass);
    }
}

Class customClass(id self, SEL _cmd) {
    return class_getSuperclass(object_getClass(self));
}

- (void)customDealloc {
    [self customDealloc];
}

@end


