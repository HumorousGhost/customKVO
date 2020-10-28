//
//  PersonViewController.m
//  KVO
//
//  Created by UED on 2020/10/28.
//

#import "PersonViewController.h"
#import "NSObject+KVO.h"
#import "Person.h"

@interface PersonViewController ()

@property (strong, nonatomic) Person *person;

@end

@implementation PersonViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor orangeColor];
    self.person = [Person shareHandler];
    [self.person customAddObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:NULL action:@selector(bolck:)];
//    self.person.dataArray = [NSMutableArray array];
//    [self.person customAddObserver:self forKeyPath:@"dataArray" options:NSKeyValueObservingOptionNew context:NULL handlerBlock:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue, void * _Nonnull context) {
//        NSLog(@"newValue = %@", newValue);
//    }];
}

- (void)bolck:(id)info {
    NSLog(@"info = %@", info);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.person.name = [NSString stringWithFormat:@"%@+", self.person.name];
//    [[self.person mutableArrayValueForKey:@"dataArray"] addObject:@"1"];
}

- (void)dealloc {
    [self.person customRemoveObserver:self forKeyPath:@"name"];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
