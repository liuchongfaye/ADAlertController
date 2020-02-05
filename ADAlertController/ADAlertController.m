//
//  ADAlertController.m
//  ADAlertController
//
//  Created by Alan on 2020/2/1.
//  Copyright © 2020 Alan. All rights reserved.
//

#import "ADAlertController.h"
#import "ADAlertController+TransitioningDelegate.h"
#import "ADAlertControllerPresentationController.h"
#import "ADAlertViewAlertStyleTransitionProtocol.h"
#import "ADAlertControllerConfiguration.h"
#import "UIViewController+ADAlertControllerTopVisible.h"
#import "ADAlertView.h"
#import "ADActionSheetView.h"
#import "ADAlertAction+Private.h"
#import "ADAlertGroupAction+Private.h"
#import "ADAlertWindow.h"

@interface ADAlertController ()<UIGestureRecognizerDelegate,ADAlertViewAlertStyleTransitionProtocol>
@property (weak, nonatomic) ADAlertWindow *alertWindow;

@property UIView<ADAlertControllerViewProtocol> *view;

///拖动手势,用于在 alert类型时,拖动移动 alert 内容
@property UIPanGestureRecognizer *panGestureRecognizer;
- (void)panGestureRecognized:(UIPanGestureRecognizer *)gestureRecognizer;

@property (strong, nonatomic) ADAlertControllerConfiguration *configuration;

@property (strong, nonatomic) NSArray<UIButton *> *buttons;
@property (strong, nonatomic) ADAlertAction *actionSheetCancelAction;
@end

@implementation ADAlertController
@dynamic view;
@dynamic maximumWidth;
@dynamic alertViewContentView;
@dynamic message;
@synthesize moveoutScreen;

- (BOOL)canShow
{
    UIViewController *topVisibleVC = [UIViewController ad_topVisibleViewController];
    if ([topVisibleVC isKindOfClass:[UIAlertController class]]) {
        return NO;
    }

    return YES;
}

- (void)dealloc
{
//    NSLog(@"%@ delloc",NSStringFromClass(self.class));
}

- (instancetype)initWithOptions:(ADAlertControllerConfiguration *)configuration
                          title:(NSString *)title
                        message:(NSString *)message
                        actions:(NSArray<ADAlertAction *> *)actions {
    self = [super initWithNibName:nil bundle:nil];
    
    if (self) {
        _configuration = [configuration copy] ?: [ADAlertControllerConfiguration defaultConfigurationWithPreferredStyle:ADAlertControllerStyleAlert];
        _actions = actions;
        _textFields = [NSArray array];
        
        self.modalPresentationStyle = UIModalPresentationCustom;
        self.transitioningDelegate = self;
        
        if (_configuration.preferredStyle == ADAlertControllerStyleAlert) {
            self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
            self.panGestureRecognizer.delegate = self;
            self.panGestureRecognizer.enabled = configuration.swipeDismissalGestureEnabled;
            [self.view addGestureRecognizer:self.panGestureRecognizer];
        }
        
        [self setTitle:title];
        [self setMessage:message];
    }
    
    return self;
}

- (void)loadView {
    switch (self.configuration.preferredStyle) {
        case ADAlertControllerStyleAlert:
        {
            self.view = [[ADAlertView alloc] initWithConfiguration:self.configuration];
            
        }break;
        case ADAlertControllerStyleActionSheet:
        case ADAlertControllerStyleSheet:{
            self.view = [[ADActionSheetView alloc] initWithConfiguration:self.configuration];
        }break;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSMutableArray *buttons = [NSMutableArray array];
    
    for (ADAlertAction *action in self.actions) {
        if ([action isKindOfClass:[ADAlertGroupAction class]]) {
            ((ADAlertGroupAction *)action).separatorColor = self.configuration.separatorColor;
            ((ADAlertGroupAction *)action).showsSeparators = self.configuration.showsSeparators;
        }
        [buttons addObject:action.view];
        action.viewController = self;
    }
    self.buttons = [buttons copy];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.view.actionButtons = self.buttons;
    self.view.textFields = self.textFields;
    [self.view addCancelView:self.actionSheetCancelAction.view];
}

#pragma mark - panGestureRecognized
- (void)panGestureRecognized:(UIPanGestureRecognizer *)gestureRecognizer {
    if ([self.view isKindOfClass:[ADAlertView class]]) {
        ADAlertView *view = (ADAlertView *)self.view;
        
        view.backgroundViewVerticalCenteringConstraint.constant = [gestureRecognizer translationInView:self.view].y;

        ADAlertControllerPresentationController *presentationController = (ADAlertControllerPresentationController *)self.presentationController;
        
        CGFloat windowHeight = CGRectGetHeight([UIApplication sharedApplication].keyWindow.bounds);
        presentationController.backgroundView.alpha = 1 - (fabs([gestureRecognizer translationInView:self.view].y) / windowHeight);
        
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            CGFloat verticalGestureVelocity = [gestureRecognizer velocityInView:self.view].y;
            
            // 如果移动速度过快,就直接移出屏幕,并在最后 dismiss,否则回到原来位置
            if (fabs(verticalGestureVelocity) > 500.0f) {
                CGFloat backgroundViewYPosition;
                
                if (verticalGestureVelocity > 500.0f) {
                    backgroundViewYPosition = CGRectGetHeight(self.view.frame);
                } else {
                    backgroundViewYPosition = -CGRectGetHeight(self.view.frame);
                }
                
                CGFloat animationDuration = 500.0f / fabs(verticalGestureVelocity);
                
                view.backgroundViewVerticalCenteringConstraint.constant = backgroundViewYPosition;
                [UIView animateWithDuration:animationDuration
                                      delay:0.0f
                     usingSpringWithDamping:0.8f
                      initialSpringVelocity:0.2f
                                    options:0
                                 animations:^{
                                     presentationController.backgroundView.alpha = 0.0f;
                                     [self.view layoutIfNeeded];
                                 }
                                 completion:^(BOOL finished) {
                                     self.moveoutScreen = YES;
                                     [self dismissViewControllerAnimated:YES completion:^{
                                         view.backgroundViewVerticalCenteringConstraint.constant = 0.0f;
                                         self.moveoutScreen = NO;
                                     }];
                                 }];
            } else {
                view.backgroundViewVerticalCenteringConstraint.constant = 0.0f;
                [UIView animateWithDuration:0.5f
                                      delay:0.0f
                     usingSpringWithDamping:0.8f
                      initialSpringVelocity:0.4f
                                    options:0
                                 animations:^{
                                     presentationController.backgroundView.alpha = 1;
                                     [self.view layoutIfNeeded];
                                 }
                                 completion:nil];
            }
        }
        
    }
}

#pragma mark - public
- (void)addTextFieldWithConfigurationHandler:(void (^)(UITextField *textField))configurationHandler {
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectZero];
    textField.borderStyle = UITextBorderStyleRoundedRect;
    
    if (configurationHandler) {
        configurationHandler(textField);
    }
    
    _textFields = [self.textFields arrayByAddingObject:textField];
}

- (void)addActionSheetCancelAction:(ADAlertAction *)cancelAction
{
    self.actionSheetCancelAction = cancelAction;
    self.actionSheetCancelAction.viewController = self;
    if ([cancelAction isKindOfClass:[ADAlertGroupAction class]]) {
        ((ADAlertGroupAction *)cancelAction).separatorColor = self.configuration.separatorColor;
        ((ADAlertGroupAction *)cancelAction).showsSeparators = self.configuration.showsSeparators;
    }
}

#pragma mark - Getters/Setters

- (CGFloat)maximumWidth {
    return self.view.maximumWidth;
}

- (void)setMaximumWidth:(CGFloat)maximumWidth {
    self.view.maximumWidth = maximumWidth;
}

- (UIView *)alertViewContentView {
    return self.view.contentView;
}

- (void)setAlertViewContentView:(UIView *)alertViewContentView {
    self.view.contentView = alertViewContentView;
}

- (void)setTitle:(NSString *)title {
    [super setTitle:title];
    
    self.view.title = title;
}

- (void)setMessage:(NSString *)message {
    self.view.message = message;
}

-(NSString *)message
{
    return self.view.message;
}

#pragma mark - ADAlertViewControllerQueueProtocol
- (void)show
{
    dispatch_async(dispatch_get_main_queue(), ^{
        ADAlertWindow *alertWindow = [ADAlertWindow window];
        self.alertWindow = alertWindow;
        [alertWindow presentViewController:self completion:nil];
    });
}

- (BOOL)isShow
{
    return self.presentingViewController;
}

- (void)hiden{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearUp
{
    self.alertWindow.hidden = YES;
    [self.alertWindow cleanUpWithViewController:self];
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
    if (self.presentingViewController) {
        [super dismissViewControllerAnimated:flag completion:^(){
            if (completion) {
                completion();
            }
            [self clearUp];
        }];
    }else{
        [self clearUp];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // Don't recognize the pan gesture in the button, so users can move their finger away after touching down
    if (([touch.view isKindOfClass:[UIButton class]])) {
        return NO;
    }
    
    return YES;
}

@end
