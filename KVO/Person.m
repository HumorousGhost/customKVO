//
//  Person.m
//  KVO
//
//  Created by UED on 2020/10/28.
//

#import "Person.h"
#import "NSObject+KVO.h"

@implementation Person

+ (instancetype)shareHandler {
    static Person *person = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        person = [[Person alloc] init];
    });
    return person;
}

+ (BOOL)customAutomaticallyNotifiesObserversForKey:(NSString *)akey {
    return false;
}

- (void)setAge:(NSInteger)age {
    [self customWillChangeValueForKey:@"age"];
    _age = age;
    [self customDidChangeValueForKey:@"age"];
}

//- (void)dealloc {
//    NSLog(@"laile = %s", __func__);
//}

@end
