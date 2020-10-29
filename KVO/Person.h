//
//  Person.h
//  KVO
//
//  Created by UED on 2020/10/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Person : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *nickName;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, strong) NSMutableArray *dataArray;

+ (instancetype)shareHandler;

@end

NS_ASSUME_NONNULL_END
