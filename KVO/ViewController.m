//
//  ViewController.m
//  KVO
//
//  Created by UED on 2020/10/27.
//

#import "ViewController.h"
#import "PersonViewController.h"
#import "Person.h"

@interface ViewController ()

@property (nonatomic, strong) UIButton *button;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
    self.button.backgroundColor = [UIColor redColor];
    [self.button addTarget:self action:@selector(push) forControlEvents:UIControlEventTouchUpInside];
    self.button.frame = CGRectMake(100, 100, 100, 100);
    [self.view addSubview:self.button];
}

- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"person - class = %@", [Person class]);
}

- (void)push {
    PersonViewController *vc = [[PersonViewController alloc] init];
    [self.navigationController pushViewController:vc animated:true];
}

@end
