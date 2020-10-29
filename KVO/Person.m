//
//  Person.m
//  KVO
//
//  Created by UED on 2020/10/28.
//

#import "Person.h"

@implementation Person

+ (instancetype)shareHandler {
    static Person *person = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        person = [[Person alloc] init];
    });
    return person;
}

//- (void)dealloc {
//    NSLog(@"laile = %s", __func__);
//}

@end
