//
//  IDMPhotoBrowser.m
//  IDMPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "IDMPhotoBrowser.h"
#import "IDMZoomingScrollView.h"
#import "IDMUtils.h"

#import "pop/POP.h"

#import "VIMediaCache.h"

#ifndef IDMPhotoBrowserLocalizedStrings
#define IDMPhotoBrowserLocalizedStrings(key) \
NSLocalizedStringFromTableInBundle((key), nil, [NSBundle bundleWithPath:[[NSBundle bundleForClass: [IDMPhotoBrowser class]] pathForResource:@"IDMPBLocalizations" ofType:@"bundle"]], nil)
#endif

// Private
@interface IDMPhotoBrowser () {
    
    // Data
    NSMutableArray *_photos;
    
    // Views
    UIScrollView *_pagingScrollView;
    
    // Gesture
    UIPanGestureRecognizer *_panGesture;
    
    // Paging
    NSMutableSet *_visiblePages, *_recycledPages;
    NSUInteger _pageIndexBeforeRotation;
    NSUInteger _currentPageIndex;
    
    // Buttons
    UIButton *_doneButton;
    
    // Toolbar
    UIToolbar *_toolbar;
    UIBarButtonItem *_previousButton, *_nextButton, *_actionButton;
    UIBarButtonItem *_counterButton;
    UILabel *_counterLabel;
    
    // Actions
    UIActivityViewController *activityViewController;
    
    // Control
    NSTimer *_controlVisibilityTimer;
    
    // Appearance
    //UIStatusBarStyle _previousStatusBarStyle;
    BOOL _statusBarOriginallyHidden;
    
    // Present
    UIView *_senderViewForAnimation;
    
    // Misc
    BOOL _performingLayout;
    BOOL _rotating;
    BOOL _viewIsActive; // active as in it's in the view heirarchy
    BOOL _autoHide;
    NSInteger _initalPageIndex;
    CGFloat _statusBarHeight;
    
    BOOL _isdraggingPhoto;
    
    CGRect _senderViewOriginalFrame;
    //UIImage *_backgroundScreenshot;
    
    VIResourceLoaderManager *loaderManager;
    
    UIWindow *_applicationWindow;
}

// Private Properties
@property (nonatomic, strong) UIActivityViewController *activityViewController;

// Private Methods

// Layout
- (void)performLayout;

// Paging
- (void)tilePages;
- (BOOL)isDisplayingPageForIndex:(NSUInteger)index;
- (IDMZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index;
- (IDMZoomingScrollView *)pageDisplayingPhoto:(id<IDMPhoto>)photo;
- (IDMZoomingScrollView *)dequeueRecycledPage;
- (void)configurePage:(IDMZoomingScrollView *)page forIndex:(NSUInteger)index;
- (void)didStartViewingPageAtIndex:(NSUInteger)index;

// Frames
- (CGRect)frameForPagingScrollView;
- (CGRect)frameForPageAtIndex:(NSUInteger)index;
- (CGSize)contentSizeForPagingScrollView;
- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index;
- (CGRect)frameForToolbarAtOrientation:(UIInterfaceOrientation)orientation;
- (CGRect)frameForDoneButtonAtOrientation:(UIInterfaceOrientation)orientation;
- (CGRect)frameForCaptionView:(IDMCaptionView *)captionView atIndex:(NSUInteger)index;

// Toolbar
- (void)updateToolbar;

// Navigation
- (void)jumpToPageAtIndex:(NSUInteger)index;
- (void)gotoPreviousPage;
- (void)gotoNextPage;

// Controls
- (void)cancelControlHiding;
- (void)hideControlsAfterDelay;
- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated permanent:(BOOL)permanent;
- (void)toggleControls;
- (BOOL)areControlsHidden;

// Data
- (NSUInteger)numberOfPhotos;
- (id<IDMPhoto>)photoAtIndex:(NSUInteger)index;
- (UIImage *)imageForPhoto:(id<IDMPhoto>)photo;
- (void)loadAdjacentPhotosIfNecessary:(id<IDMPhoto>)photo;
- (void)releaseAllUnderlyingPhotos;

@end

// IDMPhotoBrowser
@implementation IDMPhotoBrowser

// Properties
@synthesize displayDoneButton = _displayDoneButton, displayToolbar = _displayToolbar, displayActionButton = _displayActionButton, displayCounterLabel = _displayCounterLabel, useWhiteBackgroundColor = _useWhiteBackgroundColor, doneButtonImage = _doneButtonImage;
@synthesize leftArrowImage = _leftArrowImage, rightArrowImage = _rightArrowImage, leftArrowSelectedImage = _leftArrowSelectedImage, rightArrowSelectedImage = _rightArrowSelectedImage, actionButtonImage = _actionButtonImage, actionButtonSelectedImage = _actionButtonSelectedImage;
@synthesize displayArrowButton = _displayArrowButton, actionButtonTitles = _actionButtonTitles;
@synthesize arrowButtonsChangePhotosAnimated = _arrowButtonsChangePhotosAnimated;
@synthesize disableVerticalSwipe = _disableVerticalSwipe;
@synthesize forceHideStatusBar = _forceHideStatusBar;
@synthesize is3DTouchPreviewing = _is3DTouchPreviewing;
@synthesize usePopAnimation = _usePopAnimation;
@synthesize activityViewController = _activityViewController;
@synthesize trackTintColor = _trackTintColor, progressTintColor = _progressTintColor;
@synthesize delegate = _delegate;
@synthesize videoPlayer;
@synthesize videoPlayerVC;
@synthesize tempPlay;

#pragma mark - NSObject

- (id)init {
    if ((self = [super init])) {
        // Defaults
        self.hidesBottomBarWhenPushed = YES;
        
        _currentPageIndex = 0;
        _performingLayout = NO; // Reset on view did appear
        _rotating = NO;
        _viewIsActive = NO;
        _visiblePages = [NSMutableSet new];
        _recycledPages = [NSMutableSet new];
        _photos = [NSMutableArray new];
        
        _initalPageIndex = 0;
        _autoHide = YES;
        
        _displayDoneButton = YES;
        _doneButtonImage = nil;
        
        _displayToolbar = YES;
        _displayActionButton = YES;
        _displayArrowButton = YES;
        _displayCounterLabel = NO;
        
        _disableVerticalSwipe = NO;
        _forceHideStatusBar = YES;
        _is3DTouchPreviewing = NO;
        _usePopAnimation = YES;
        
        _useWhiteBackgroundColor = NO;
        _leftArrowImage = _rightArrowImage = _leftArrowSelectedImage = _rightArrowSelectedImage = nil;
        
        _arrowButtonsChangePhotosAnimated = YES;
        
        _backgroundScaleFactor = 1.0;
        _animationDuration = 0.28;
        
        _senderViewForAnimation = nil;
        _scaleImage = nil;
        
        _isdraggingPhoto = NO;
        
        _statusBarHeight = 20.f;
        _doneButtonRightInset = 20.f;
        // relative to status bar and safeAreaInsets
        _doneButtonTopInset = 10.f;
        
        _doneButtonSize = CGSizeMake(55.f, 26.f);
        
        if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)]) {
            self.automaticallyAdjustsScrollViewInsets = NO;
        }
        
        loaderManager = [[VIResourceLoaderManager alloc] init];
        
        _applicationWindow = [[[UIApplication sharedApplication] delegate] window];
        
        self.modalPresentationStyle = UIModalPresentationCustom;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.modalPresentationCapturesStatusBarAppearance = YES;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        
        // Listen for IDMPhoto notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleIDMPhotoLoadingDidEndNotification:)
                                                     name:IDMPhoto_LOADING_DID_END_NOTIFICATION
                                                   object:nil];
    }
    
    return self;
}

- (id)initWithPhotos:(NSArray *)photosArray {
    if ((self = [self init])) {
        _photos = [[NSMutableArray alloc] initWithArray:photosArray];
    }
    return self;
}

- (id)initWithPhotos:(NSArray *)photosArray animatedFromView:(UIView*)view {
    if ((self = [self init])) {
        _photos = [[NSMutableArray alloc] initWithArray:photosArray];
        _senderViewForAnimation = view;
    }
    return self;
}

- (id)initWithPhotos:(NSArray *)photosArray animatedFromView:(UIView*)view withWindow:(UIWindow*)window {
    if ((self = [self init])) {
        _photos = [[NSMutableArray alloc] initWithArray:photosArray];
        _senderViewForAnimation = view;
        _applicationWindow = window;
    }
    return self;
}

- (id)initWithPhotoURLs:(NSArray *)photoURLsArray {
    if ((self = [self init])) {
        NSArray *photosArray = [IDMPhoto photosWithURLs:photoURLsArray];
        _photos = [[NSMutableArray alloc] initWithArray:photosArray];
    }
    return self;
}

- (id)initWithPhotoURLs:(NSArray *)photoURLsArray animatedFromView:(UIView*)view {
    if ((self = [self init])) {
        NSArray *photosArray = [IDMPhoto photosWithURLs:photoURLsArray];
        _photos = [[NSMutableArray alloc] initWithArray:photosArray];
        _senderViewForAnimation = view;
    }
    return self;
}

- (id)initWithPhotoURLs:(NSArray *)photoURLsArray animatedFromView:(UIView*)view withWindow:(UIWindow*)window {
    if ((self = [self init])) {
        NSArray *photosArray = [IDMPhoto photosWithURLs:photoURLsArray];
        _photos = [[NSMutableArray alloc] initWithArray:photosArray];
        _senderViewForAnimation = view;
        _applicationWindow = window;
    }
    return self;
}

- (void)dealloc {
    _currentPageIndex = 0;
    _pagingScrollView = nil;
    _visiblePages = nil;
    _recycledPages = nil;
    _toolbar = nil;
    _doneButton = nil;
    _previousButton = nil;
    _nextButton = nil;
    
    _pagingScrollView.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self releaseAllUnderlyingPhotos];
}

- (void)releaseAllUnderlyingPhotos {
    for (id p in _photos) { if (p != [NSNull null]) [p unloadUnderlyingImage]; } // Release photos
}

- (void)didReceiveMemoryWarning {
    // Release any cached data, images, etc that aren't in use.
    [self releaseAllUnderlyingPhotos];
    [_recycledPages removeAllObjects];
    
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark - Pan Gesture

- (void)panGestureRecognized:(id)sender {
    // Initial Setup
    IDMZoomingScrollView *scrollView = [self pageDisplayedAtIndex:_currentPageIndex];
    
    static float firstX, firstY;
    
    float viewHeight = scrollView.frame.size.height;
    float viewHalfHeight = viewHeight/2;
    
    CGPoint translatedPoint = [(UIPanGestureRecognizer*)sender translationInView:self.view];
    
    // Gesture Began
    if ([(UIPanGestureRecognizer*)sender state] == UIGestureRecognizerStateBegan) {
        [self setControlsHidden:YES animated:YES permanent:YES];
        
        firstX = [scrollView center].x;
        firstY = [scrollView center].y;
        
        _senderViewForAnimation.hidden = NO;
        
        _isdraggingPhoto = YES;
        [self setNeedsStatusBarAppearanceUpdate];
    }
    
    translatedPoint = CGPointMake(firstX, firstY+translatedPoint.y);
    [scrollView setCenter:translatedPoint];
    
    float newY = scrollView.center.y - viewHalfHeight;
    float newAlpha = 1 - fabsf(newY)/viewHeight; //abs(newY)/viewHeight * 1.8;
    
    self.view.opaque = YES;
    
    self.view.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor ? 1 : 0) alpha:newAlpha];
    
    // Gesture Ended
    if ([(UIPanGestureRecognizer*)sender state] == UIGestureRecognizerStateEnded) {
        if(scrollView.center.y > viewHalfHeight+40 || scrollView.center.y < viewHalfHeight-40) // Automatic Dismiss View
        {
            if (_senderViewForAnimation) {
                [self performCloseAnimationWithScrollView:scrollView];
                return;
            }
            
            CGFloat finalX = firstX, finalY;
            
            CGFloat windowsHeight = [_applicationWindow frame].size.height;
            
            if(scrollView.center.y > viewHalfHeight+30) // swipe down
                finalY = windowsHeight*2;
            else // swipe up
                finalY = -viewHalfHeight;
            
            CGFloat animationDuration = 0.35;
            
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:animationDuration];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
            [UIView setAnimationDelegate:self];
            [scrollView setCenter:CGPointMake(finalX, finalY)];
            self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
            [UIView commitAnimations];
            
            [self performSelector:@selector(doneButtonPressed:) withObject:self afterDelay:animationDuration];
        }
        else // Continue Showing View
        {
            _isdraggingPhoto = NO;
            [self setNeedsStatusBarAppearanceUpdate];
            
            self.view.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor ? 1 : 0) alpha:1];
            
            CGFloat velocityY = (.35*[(UIPanGestureRecognizer*)sender velocityInView:self.view].y);
            
            CGFloat finalX = firstX;
            CGFloat finalY = viewHalfHeight;
            
            CGFloat animationDuration = (ABS(velocityY)*.0002)+.2;
            
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:animationDuration];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
            [UIView setAnimationDelegate:self];
            [scrollView setCenter:CGPointMake(finalX, finalY)];
            [UIView commitAnimations];
        }
    }
}

#pragma mark - Animation

- (void)performPresentAnimation {
    self.view.alpha = 0.0f;
    _pagingScrollView.alpha = 0.0f;
    
    UIImage *imageFromView = _scaleImage ? _scaleImage : [self getImageFromView:_senderViewForAnimation];
    
    _senderViewOriginalFrame = [_senderViewForAnimation.superview convertRect:_senderViewForAnimation.frame toView:nil];
    
    CGRect screenBound = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenBound.size.width;
    CGFloat screenHeight = screenBound.size.height;
    
    UIView *fadeView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, screenHeight)];
    fadeView.backgroundColor = [UIColor clearColor];
    [_applicationWindow addSubview:fadeView];
    
    UIImageView *resizableImageView = [[UIImageView alloc] initWithImage:imageFromView];
    resizableImageView.frame = _senderViewOriginalFrame;
    resizableImageView.clipsToBounds = YES;
    resizableImageView.contentMode = UIViewContentModeScaleAspectFill;
    resizableImageView.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor) ? 1 : 0 alpha:1];
    
    if (@available(iOS 11.0, *)) {
        resizableImageView.accessibilityIgnoresInvertColors = YES;
    }
    
    [_applicationWindow addSubview:resizableImageView];
    
    if (!_is3DTouchPreviewing) {
        _senderViewForAnimation.hidden = YES;
    }
    
    void (^completion)(void) = ^() {
        self.view.alpha = 1.0f;
        self->_pagingScrollView.alpha = 1.0f;
        resizableImageView.backgroundColor = [UIColor colorWithWhite:(self->_useWhiteBackgroundColor) ? 1 : 0 alpha:1];
        [fadeView removeFromSuperview];
        [resizableImageView removeFromSuperview];
        
        //Show done button after image is shown and animation is completed.
        if (self->_doneButton && self->_displayDoneButton) {
            [self->_doneButton setAlpha:1.0f];
        }
    };
    
    if (!_is3DTouchPreviewing) {
        [UIView animateWithDuration:_animationDuration animations:^{
            fadeView.backgroundColor = self.useWhiteBackgroundColor ? [UIColor whiteColor] : [UIColor blackColor];
        } completion:nil];
    }
    else {
        [fadeView removeFromSuperview];
        [resizableImageView removeFromSuperview];
    }
    
    CGRect finalImageViewFrame = [self animationFrameForImage:imageFromView presenting:YES scrollView:nil];
    
    if (!_is3DTouchPreviewing) {
        if(_usePopAnimation) {
            [self animateView:resizableImageView
                      toFrame:finalImageViewFrame
                   completion:completion];
        }
        else {
            [UIView animateWithDuration:_animationDuration animations:^{
                resizableImageView.layer.frame = finalImageViewFrame;
            } completion:^(BOOL finished) {
                completion();
            }];
        }
    }
}

- (void)performCloseAnimationWithScrollView:(IDMZoomingScrollView*)scrollView {
    float fadeAlpha = 1 - fabs(scrollView.frame.origin.y)/scrollView.frame.size.height;
    
    UIImage *imageFromView = [scrollView.photo underlyingImage];
    
    UIView *fadeView = [[UIView alloc] initWithFrame:_applicationWindow.bounds];
    fadeView.backgroundColor = self.useWhiteBackgroundColor ? [UIColor whiteColor] : [UIColor blackColor];
    fadeView.alpha = fadeAlpha;
    [_applicationWindow addSubview:fadeView];
    
    CGRect imageViewFrame = [self animationFrameForImage:imageFromView presenting:NO scrollView:scrollView];
    
    UIImageView *resizableImageView = [[UIImageView alloc] initWithImage:imageFromView];
    resizableImageView.frame = imageViewFrame;
    resizableImageView.contentMode = _senderViewForAnimation ? _senderViewForAnimation.contentMode : UIViewContentModeScaleAspectFill;
    resizableImageView.backgroundColor = [UIColor clearColor];
    resizableImageView.clipsToBounds = YES;
    if (@available(iOS 11.0, *)) {
        resizableImageView.accessibilityIgnoresInvertColors = YES;
    }
    [_applicationWindow addSubview:resizableImageView];
    self.view.hidden = YES;
    
    for (IDMPhoto *photoFromArray in self->_photos) {
        if (photoFromArray.underlyingView != nil && photoFromArray.underlyingView != _senderViewForAnimation) {
            photoFromArray.underlyingView.hidden = NO;
        }
    }
    
    void (^completion)(void) = ^() {
        self->_senderViewForAnimation.hidden = NO;
        self->_senderViewForAnimation = nil;
        self->_scaleImage = nil;
        
        [fadeView removeFromSuperview];
        [resizableImageView removeFromSuperview];
        
        [self prepareForClosePhotoBrowser];
        [self dismissPhotoBrowserAnimated:NO];
    };
    
    [UIView animateWithDuration:_animationDuration animations:^{
        fadeView.alpha = 0;
        self.view.backgroundColor = [UIColor clearColor];
    } completion:nil];
    
    CGRect senderViewOriginalFrame = _senderViewForAnimation.superview ? [_senderViewForAnimation.superview convertRect:_senderViewForAnimation.frame toView:nil] : _senderViewOriginalFrame;
    
    [self animateView:resizableImageView
              toFrame:senderViewOriginalFrame
           completion:completion];
}

- (CGRect)animationFrameForImage:(UIImage *)image presenting:(BOOL)presenting scrollView:(UIScrollView *)scrollView
{
    if (!image) {
        return CGRectZero;
    }
    
    CGSize imageSize = image.size;
    
    CGRect bounds = _applicationWindow.bounds;
    // adjust bounds as the photo browser does
    if (@available(iOS 11.0, *)) {
        // use the windows safe area inset
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        UIEdgeInsets insets = UIEdgeInsetsMake(_statusBarHeight, 0, 0, 0);
        if (window != NULL) {
            insets = window.safeAreaInsets;
        }
        bounds = [self adjustForSafeArea:bounds adjustForStatusBar:NO forInsets:insets];
    }
    CGFloat maxWidth = CGRectGetWidth(bounds);
    CGFloat maxHeight = CGRectGetHeight(bounds);
    
    CGRect animationFrame = CGRectZero;
    
    CGFloat aspect = imageSize.width / imageSize.height;
    if (maxWidth / aspect <= maxHeight) {
        animationFrame.size = CGSizeMake(maxWidth, maxWidth / aspect);
    }
    else {
        animationFrame.size = CGSizeMake(maxHeight * aspect, maxHeight);
    }
    
    animationFrame.origin.x = roundf((maxWidth - animationFrame.size.width) / 2.0f);
    animationFrame.origin.y = roundf((maxHeight - animationFrame.size.height) / 2.0f);
    
    if (!presenting) {
        animationFrame.origin.y += scrollView.frame.origin.y;
    }
    return animationFrame;
}

#pragma mark - Genaral

- (void)prepareForClosePhotoBrowser {
    // Gesture
    [_applicationWindow removeGestureRecognizer:_panGesture];
    
    _autoHide = NO;
    
    // Controls
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // Cancel any pending toggles from taps
    
    if ([_delegate respondsToSelector:@selector(photoBrowser:willDismissAtPageIndex:)]) {
        [_delegate photoBrowser:self willDismissAtPageIndex:_currentPageIndex];
    }
}

- (void)dismissPhotoBrowserAnimated:(BOOL)animated {
    IDMPhoto *photo = [self photoAtIndex:_currentPageIndex];
    
    if (photo.isPlaying)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
        
        [self.videoPlayer pause];
        [self.videoPlayerVC.view removeFromSuperview];
        
        self.videoPlayerVC = nil;
        self.videoPlayer = nil;
        self.tempPlay = nil;
        
        photo.isPlaying = NO;
    }
    
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    [self dismissViewControllerAnimated:animated completion:^{
        if ([self->_delegate respondsToSelector:@selector(photoBrowser:didDismissAtPageIndex:)]) {
            [self->_delegate photoBrowser:self didDismissAtPageIndex:self->_currentPageIndex];
        }
        
        if (self->_applicationWindow != nil) {
            [self->_applicationWindow.rootViewController setNeedsStatusBarAppearanceUpdate];
        }
    }];
}

- (UIButton*)customToolbarButtonImage:(UIImage*)image imageSelected:(UIImage*)selectedImage action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setBackgroundImage:image forState:UIControlStateNormal];
    [button setBackgroundImage:selectedImage forState:UIControlStateDisabled];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button setContentMode:UIViewContentModeCenter];
    [button setFrame:CGRectMake(0,0, image.size.width, image.size.height)];
    return button;
}

- (UIImage*)getImageFromView:(UIView *)view {
    if ([view isKindOfClass:[UIImageView class]]) {
        return ((UIImageView *)view).image;
    }
    
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIViewController *)topviewController
{
    UIViewController *topviewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topviewController.presentedViewController) {
        topviewController = topviewController.presentedViewController;
    }
    
    return topviewController;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    // View
    self.view.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor ? 1 : 0) alpha:1];
    
    self.view.clipsToBounds = YES;
    
    // Setup paging scrolling view
    CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
    _pagingScrollView = [[UIScrollView alloc] initWithFrame:pagingScrollViewFrame];
    //_pagingScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _pagingScrollView.pagingEnabled = YES;
    _pagingScrollView.delegate = self;
    _pagingScrollView.showsHorizontalScrollIndicator = NO;
    _pagingScrollView.showsVerticalScrollIndicator = NO;
    _pagingScrollView.backgroundColor = [UIColor clearColor];
    _pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
    
    [self.view addSubview:_pagingScrollView];
    
    // Transition animation
    [self performPresentAnimation];
    
    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    
    // Toolbar
    _toolbar = [[UIToolbar alloc] initWithFrame:[self frameForToolbarAtOrientation:currentOrientation]];
    _toolbar.backgroundColor = [UIColor clearColor];
    _toolbar.clipsToBounds = YES;
    _toolbar.translucent = YES;
    [_toolbar setBackgroundImage:[UIImage new]
              forToolbarPosition:UIToolbarPositionAny
                      barMetrics:UIBarMetricsDefault];
    
    // Close Button
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_doneButton setFrame:[self frameForDoneButtonAtOrientation:currentOrientation]];
    [_doneButton setAlpha:0.0f];
    [_doneButton addTarget:self action:@selector(doneButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    if(!_doneButtonImage) {
        [_doneButton setTitleColor:[UIColor colorWithWhite:0.9 alpha:0.9] forState:UIControlStateNormal|UIControlStateHighlighted];
        [_doneButton setTitle:@"Close" forState:UIControlStateNormal];
        [_doneButton.titleLabel setFont:[UIFont systemFontOfSize:13.0]];
        //[_doneButton.titleLabel setFont:[UIFont fontWithName:@"AvenirNext-Regular" size:13.0f]];
        //[_doneButton setBackgroundColor:[UIColor colorWithRed:253.0/255.0 green:112.0/255.0 blue:40.0/255.0 alpha:0.8]];
        _doneButton.layer.cornerRadius = 3.0f;
        _doneButton.layer.borderColor = [UIColor colorWithWhite:0.9 alpha:0.9].CGColor;
        _doneButton.layer.borderWidth = 1.0f;
    }
    else {
        [_doneButton setBackgroundImage:_doneButtonImage forState:UIControlStateNormal];
        _doneButton.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    UIImage *leftButtonImage = (_leftArrowImage == nil) ?
    [UIImage imageNamed:@"IDMPhotoBrowser.bundle/images/IDMPhotoBrowser_arrowLeft.png"]          : _leftArrowImage;
    
    UIImage *rightButtonImage = (_rightArrowImage == nil) ?
    [UIImage imageNamed:@"IDMPhotoBrowser.bundle/images/IDMPhotoBrowser_arrowRight.png"]         : _rightArrowImage;
    
    UIImage *leftButtonSelectedImage = (_leftArrowSelectedImage == nil) ?
    [UIImage imageNamed:@"IDMPhotoBrowser.bundle/images/IDMPhotoBrowser_arrowLeftSelected.png"]  : _leftArrowSelectedImage;
    
    UIImage *rightButtonSelectedImage = (_rightArrowSelectedImage == nil) ?
    [UIImage imageNamed:@"IDMPhotoBrowser.bundle/images/IDMPhotoBrowser_arrowRightSelected.png"] : _rightArrowSelectedImage;
    
    // Arrows
    _previousButton = [[UIBarButtonItem alloc] initWithCustomView:[self customToolbarButtonImage:leftButtonImage
                                                                                   imageSelected:leftButtonSelectedImage
                                                                                          action:@selector(gotoPreviousPage)]];
    
    _nextButton = [[UIBarButtonItem alloc] initWithCustomView:[self customToolbarButtonImage:rightButtonImage
                                                                               imageSelected:rightButtonSelectedImage
                                                                                      action:@selector(gotoNextPage)]];
    
    // Counter Label
    _counterLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 95, 40)];
    _counterLabel.textAlignment = NSTextAlignmentCenter;
    _counterLabel.backgroundColor = [UIColor clearColor];
    _counterLabel.font = [UIFont fontWithName:@"Helvetica" size:17];
    
    if(_useWhiteBackgroundColor == NO) {
        _counterLabel.textColor = [UIColor whiteColor];
        _counterLabel.shadowColor = [UIColor darkTextColor];
        _counterLabel.shadowOffset = CGSizeMake(0, 1);
    }
    else {
        _counterLabel.textColor = [UIColor blackColor];
    }
    
    // Counter Button
    _counterButton = [[UIBarButtonItem alloc] initWithCustomView:_counterLabel];
    
    
    // Action Button
    _actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                  target:self
                                                                  action:@selector(actionButtonPressed:)];
    _actionButton.tintColor = [UIColor colorWithWhite:1 alpha:1];
    
    // Gesture
    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
    [_panGesture setMinimumNumberOfTouches:1];
    [_panGesture setMaximumNumberOfTouches:1];
    
    // Update
    //[self reloadData];
    
    if (_is3DTouchPreviewing) {
        self.view.alpha = 1.0f;
        _pagingScrollView.alpha = 1.0f;
        
        //Show done button after image is shown and animation is completed.
        if (_doneButton && _displayDoneButton) {
            [_doneButton setAlpha:1.0f];
        }
    }
    
    // Super
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    // Update
    [self reloadData];
    
    // Super
    [super viewWillAppear:animated];
    
    // Status Bar
    //_statusBarOriginallyHidden = [UIApplication sharedApplication].statusBarHidden;
    
    // Update UI
    //[self hideControlsAfterDelay];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _viewIsActive = YES;
    
    [self playVideo];
}

- (BOOL)validateUrl:(NSString *)candidate {
    NSString *urlRegEx =
    @"(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+";
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlRegEx];
    
    return [urlTest evaluateWithObject:candidate];
}

- (void)playVideo
{
    IDMZoomingScrollView *scrollView = [self pageDisplayedAtIndex:_currentPageIndex];
    IDMPhoto *scrollViewPhoto = [scrollView photo];
    
    IDMPhoto *photo = [self photoAtIndex:_currentPageIndex];
    
    if (photo.isVideo && !photo.isPlaying) {
        if (!photo.videoURL && !photo.videoURL.scheme && !photo.videoURL.host) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Video Error" message:@"The video could not be played because it has an invalid url." preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
            [alert addAction:cancelAction];
            
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        
        //Our video player is already available, play our video again.
        if (self.videoPlayer) {
            [self.videoPlayerVC.view setHidden:NO];
            
            [self.videoPlayer seekToTime:kCMTimeZero];
            
            [self.videoPlayer play];
        }
        else {
            self.videoPlayer = nil;
            self.videoPlayerVC = nil;
            
            // Create a temporary player item that can be cached (video data) for use later.
            AVPlayerItem *cachedPlayerItem = [loaderManager playerItemWithURL:photo.videoURL];
            
            self.videoPlayer = [[AVPlayer alloc] initWithPlayerItem:cachedPlayerItem];
            
            self.videoPlayerVC = [AVPlayerViewController new];
            
            self.videoPlayerVC.view.frame = self.view.bounds;
            
            self.videoPlayerVC.showsPlaybackControls = NO;
            
            self.videoPlayerVC.videoGravity = AVLayerVideoGravityResizeAspect;
            
            self.videoPlayerVC.player = self.videoPlayer;
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlaybackComplete:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlaybackError:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
            
            UITapGestureRecognizer *tapScrollViewVideo = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(videoPlayButtonTapped:)];
            [scrollView addGestureRecognizer:tapScrollViewVideo];
            
//            UITapGestureRecognizer *tapPlayButton = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(videoPlayButtonTapped:)];
//            [[scrollViewPhoto playButton] addGestureRecognizer:tapPlayButton];
            
            [scrollView insertSubview:self.videoPlayerVC.view atIndex:0];
            
            if (CMTIME_IS_VALID(photo.currentSeekTime)) {
                [self.videoPlayer seekToTime:photo.currentSeekTime];
            }
            else {
                [self.videoPlayer seekToTime:kCMTimeZero];
            }
            
            [_doneButton setHidden:YES];
            
            [[scrollViewPhoto playButton] setHidden:YES];
            [scrollViewPhoto setPlayButtonHidden:YES];
            
            [[scrollView captionView] setAlpha:0];
            [[scrollView photoImageView] setAlpha:0];
            [[scrollView topBackgroundView] setAlpha:0];
            
            [self.videoPlayer play];
        }
        
        photo.isPlaying = YES;
    }
    else {
        photo.isPlaying = NO;
    }
}

- (void)moviePlaybackComplete:(NSNotification *)notification
{
    IDMPhoto *photo = [self photoAtIndex:_currentPageIndex];
    
    [videoPlayer pause];
    
    photo.isPlaying = NO;
    
    [videoPlayer seekToTime:kCMTimeZero];
    
    [videoPlayer play];
    
    photo.isPlaying = YES;
}

- (void)moviePlaybackError:(NSNotification *)notification
{
    NSDictionary *notificationUserInfo = [notification userInfo];
    NSError *error = [notificationUserInfo objectForKey:AVPlayerItemFailedToPlayToEndTimeErrorKey];
    
    if (error != nil) {
        NSLog(@"Playback Error: %@", error.description);
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Video Playback Error" message:@"Video playback error has occurred, please try again." preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
    IDMZoomingScrollView *scrollView = [self pageDisplayedAtIndex:_currentPageIndex];
    IDMPhoto *scrollViewPhoto = [scrollView photo];
    
    IDMPhoto *photo = [self photoAtIndex:_currentPageIndex];
    
    [videoPlayer pause];
    
    [videoPlayer seekToTime:kCMTimeZero];
    
    [_doneButton setHidden:YES];
    
    [[scrollViewPhoto playButton] setHidden:YES];
    [scrollViewPhoto setPlayButtonHidden:YES];
    
    [[scrollView captionView] setAlpha:0];
    [[scrollView photoImageView] setAlpha:0];
    [[scrollView topBackgroundView] setAlpha:0];
    
    photo.isPlaying = NO;
}

- (void)videoPlayButtonTapped:(UITapGestureRecognizer *)recognizer
{
    // If there is no initialized video player, we should setup and then play witout detecting its current state.
    if (videoPlayer == nil || videoPlayerVC == nil) {
        [self playVideo];
        
        return;
    }
    
    IDMZoomingScrollView *scrollView = [self pageDisplayedAtIndex:_currentPageIndex];
    IDMPhoto *scrollViewPhoto = [scrollView photo];
    
    IDMPhoto *photo = [self photoAtIndex:_currentPageIndex];
    
    if (videoPlayer.rate != 0.0) {
        [videoPlayer pause];
        
        photo.isPlaying = NO;
        
        [_doneButton setHidden:NO];
        
        [[scrollViewPhoto playButton] setHidden:NO];
        [scrollViewPhoto setPlayButtonHidden:NO];
        
        [[scrollView captionView] setAlpha:1];
        [[scrollView topBackgroundView] setAlpha:1];
    }
    else {
        [videoPlayer play];
        
        photo.isPlaying = YES;
        
        [_doneButton setHidden:YES];
        
        [[scrollViewPhoto playButton] setHidden:YES];
        [scrollViewPhoto setPlayButtonHidden:YES];
        
        [[scrollView captionView] setAlpha:0];
        [[scrollView photoImageView] setAlpha:0];
        [[scrollView topBackgroundView] setAlpha:0];
    }
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
    //return _useWhiteBackgroundColor ? UIStatusBarStyleDefault : UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationFade;
}

#pragma mark - Layout

- (void)viewWillLayoutSubviews {
    // Flag
    _performingLayout = YES;
    
    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    
    // Toolbar
    _toolbar.frame = [self frameForToolbarAtOrientation:currentOrientation];
    
    // Done button
    _doneButton.frame = [self frameForDoneButtonAtOrientation:currentOrientation];
    
    // Remember index
    NSUInteger indexPriorToLayout = _currentPageIndex;
    
    // Get paging scroll view frame to determine if anything needs changing
    CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
    
    // Frame needs changing
    _pagingScrollView.frame = pagingScrollViewFrame;
    
    // Recalculate contentSize based on current orientation
    _pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
    
    // Adjust frames and configuration of each visible page
    for (IDMZoomingScrollView *page in _visiblePages) {
        NSUInteger index = PAGE_INDEX(page);
        page.frame = [self frameForPageAtIndex:index];
        page.topBackgroundView.frame = [self frameForTopBackgroundView:page.topBackgroundView atIndex:index];
        page.captionView.frame = [self frameForCaptionView:page.captionView atIndex:index];
        [page setMaxMinZoomScalesForCurrentBounds];
    }
    
    // Adjust contentOffset to preserve page location based on values collected prior to location
    _pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:indexPriorToLayout];
    [self didStartViewingPageAtIndex:_currentPageIndex]; // initial
    
    // Reset
    _currentPageIndex = indexPriorToLayout;
    _performingLayout = NO;
    
    // Super
    [super viewWillLayoutSubviews];
}

- (void)performLayout {
    // Setup
    _performingLayout = YES;
    NSUInteger numberOfPhotos = [self numberOfPhotos];
    
    // Setup pages
    [_visiblePages removeAllObjects];
    [_recycledPages removeAllObjects];
    
    // Toolbar
    if (_displayToolbar) {
        [self.view addSubview:_toolbar];
    } else {
        [_toolbar removeFromSuperview];
    }
    
    // Close button
    if(_displayDoneButton && !self.navigationController.navigationBar)
        [self.view addSubview:_doneButton];
    
    // Toolbar items & navigation
    UIBarButtonItem *fixedLeftSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                                    target:self action:nil];
    fixedLeftSpace.width = 32; // To balance action button
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                               target:self action:nil];
    NSMutableArray *items = [NSMutableArray new];
    
    if (_displayActionButton)
        [items addObject:fixedLeftSpace];
    
    [items addObject:flexSpace];
    
    if (numberOfPhotos > 1 && _displayArrowButton)
        [items addObject:_previousButton];
    
    if(_displayCounterLabel) {
        [items addObject:flexSpace];
        [items addObject:_counterButton];
    }
    
    [items addObject:flexSpace];
    if (numberOfPhotos > 1 && _displayArrowButton)
        [items addObject:_nextButton];
    [items addObject:flexSpace];
    
    if(_displayActionButton)
        [items addObject:_actionButton];
    
    [_toolbar setItems:items];
    [self updateToolbar];
    
    // Content offset
    _pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:_currentPageIndex];
    [self tilePages];
    _performingLayout = NO;
    
    if(! _disableVerticalSwipe)
        [self.view addGestureRecognizer:_panGesture];
}

#pragma mark - Data

- (void)reloadData {
    // Get data
    [self releaseAllUnderlyingPhotos];
    
    // Update
    [self performLayout];
    
    // Layout
    [self.view setNeedsLayout];
}

- (NSUInteger)numberOfPhotos {
    return _photos.count;
}

- (id<IDMPhoto>)photoAtIndex:(NSUInteger)index {
    return _photos[index];
}

- (IDMCaptionView *)captionViewForPhotoAtIndex:(NSUInteger)index {
    IDMCaptionView *captionView = nil;
    if ([_delegate respondsToSelector:@selector(photoBrowser:captionViewForPhotoAtIndex:)]) {
        captionView = [_delegate photoBrowser:self captionViewForPhotoAtIndex:index];
    } else {
        id <IDMPhoto> photo = [self photoAtIndex:index];
        if ([photo respondsToSelector:@selector(caption)]) {
            if ([photo caption]) captionView = [[IDMCaptionView alloc] initWithPhoto:photo];
        }
    }
    
    captionView.alpha = [self areControlsHidden] ? 0 : 1; // Initial alpha
    
    return captionView;
}

- (UIView *)topBackgroundViewForPhotoAtIndex:(NSUInteger)index {
    UIView *topBackgroundView = nil;
    if ([_delegate respondsToSelector:@selector(photoBrowser:topBackgroundViewForPhotoAtIndex:)]) {
        topBackgroundView = [_delegate photoBrowser:self topBackgroundViewForPhotoAtIndex:index];
    }
    else {
        topBackgroundView = [[UIView alloc] init];
    }
    topBackgroundView.alpha = [self areControlsHidden] ? 0 : 1; // Initial alpha
    
    return topBackgroundView;
}

- (UIImage *)imageForPhoto:(id<IDMPhoto>)photo {
    if (photo) {
        // Get image or obtain in background
        if ([photo underlyingImage]) {
            return [photo underlyingImage];
        } else {
            [photo loadUnderlyingImageAndNotify];
        }
    }
    
    return nil;
}

- (void)loadAdjacentPhotosIfNecessary:(id<IDMPhoto>)photo {
    IDMZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page) {
        // If page is current page then initiate loading of previous and next pages
        NSUInteger pageIndex = PAGE_INDEX(page);
        if (_currentPageIndex == pageIndex) {
            if (pageIndex > 0) {
                // Preload index - 1
                id <IDMPhoto> photo = [self photoAtIndex:pageIndex-1];
                if (![photo underlyingImage]) {
                    [photo loadUnderlyingImageAndNotify];
                    IDMLog(@"Pre-loading image at index %i", pageIndex-1);
                }
            }
            if (pageIndex < [self numberOfPhotos] - 1) {
                // Preload index + 1
                id <IDMPhoto> photo = [self photoAtIndex:pageIndex+1];
                if (![photo underlyingImage]) {
                    [photo loadUnderlyingImageAndNotify];
                    IDMLog(@"Pre-loading image at index %i", pageIndex+1);
                }
            }
        }
    }
}

#pragma mark - IDMPhoto Loading Notification

- (void)handleIDMPhotoLoadingDidEndNotification:(NSNotification *)notification {
    IDMPhoto *photo = [notification object];
    IDMZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page) {
        if ([photo underlyingImage]) {
            // Successful load
            [page displayImage];
            [self loadAdjacentPhotosIfNecessary:photo];
        } else {
            // Failed to load
            [page displayImageFailure];
        }
    }
}

#pragma mark - Paging

- (void)tilePages {
    // Since we implemented 3D Touch for the Gallery, we should reset all pages and the scrollview before each call on this function.
    [_visiblePages removeAllObjects];
    [_recycledPages removeAllObjects];
    
    for (UIView *view in _pagingScrollView.subviews) {
        [view removeFromSuperview];
    }
    
    // Calculate which pages should be visible
    // Ignore padding as paging bounces encroach on that
    // and lead to false page loads
    CGRect visibleBounds = _pagingScrollView.bounds;
    NSInteger iFirstIndex = (NSInteger) floorf((CGRectGetMinX(visibleBounds)+PADDING*2) / CGRectGetWidth(visibleBounds));
    NSInteger iLastIndex  = (NSInteger) floorf((CGRectGetMaxX(visibleBounds)-PADDING*2-1) / CGRectGetWidth(visibleBounds));
    if (iFirstIndex < 0) iFirstIndex = 0;
    if (iFirstIndex > [self numberOfPhotos] - 1) iFirstIndex = [self numberOfPhotos] - 1;
    if (iLastIndex < 0) iLastIndex = 0;
    if (iLastIndex > [self numberOfPhotos] - 1) iLastIndex = [self numberOfPhotos] - 1;
    
    // Recycle no longer needed pages
    NSInteger pageIndex;
    for (IDMZoomingScrollView *page in _visiblePages) {
        pageIndex = PAGE_INDEX(page);
        if (pageIndex < (NSUInteger)iFirstIndex || pageIndex > (NSUInteger)iLastIndex) {
            [_recycledPages addObject:page];
            [page prepareForReuse];
            [page removeFromSuperview];
            IDMLog(@"Removed page at index %i", PAGE_INDEX(page));
        }
    }
    [_visiblePages minusSet:_recycledPages];
    while (_recycledPages.count > 2) // Only keep 2 recycled pages
        [_recycledPages removeObject:[_recycledPages anyObject]];
    
    // Add missing pages
    for (NSUInteger index = (NSUInteger)iFirstIndex; index <= (NSUInteger)iLastIndex; index++) {
        if (![self isDisplayingPageForIndex:index]) {
            // Add new page
            IDMZoomingScrollView *page;
            page = [[IDMZoomingScrollView alloc] initWithPhotoBrowser:self];
            page.backgroundColor = [UIColor clearColor];
            page.opaque = YES;
            
            [self configurePage:page forIndex:index];
            [_visiblePages addObject:page];
            [_pagingScrollView addSubview:page];
            IDMLog(@"Added page at index %i", index);
            
            // Add caption
            IDMCaptionView *captionView = [self captionViewForPhotoAtIndex:index];
            captionView.frame = [self frameForCaptionView:captionView atIndex:index];
            [_pagingScrollView addSubview:captionView];
            page.captionView = captionView;
            
            // Add top background view
            UIView *topBackgroundView = [self topBackgroundViewForPhotoAtIndex:index];
            topBackgroundView.frame = [self frameForTopBackgroundView:topBackgroundView atIndex:index];
            [_pagingScrollView addSubview:topBackgroundView];
            page.topBackgroundView = topBackgroundView;
            
            // Update when video
            IDMPhoto *pagePhoto = [page photo];
            
            if (pagePhoto.isVideo) {
                [self.videoPlayer pause];
                
                self.videoPlayer = nil;
                self.videoPlayerVC = nil;
                
                [_doneButton setHidden:NO];
                
                pagePhoto.isPlaying = NO;
                
                [[pagePhoto playButton] setHidden:NO];
                [pagePhoto setPlayButtonHidden:NO];
                
                UITapGestureRecognizer *tapScrollViewVideo = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(videoPlayButtonTapped:)];
                [page addGestureRecognizer:tapScrollViewVideo];
            }
        }
    }
}

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index {
    for (IDMZoomingScrollView *page in _visiblePages)
        if (PAGE_INDEX(page) == index) return YES;
    return NO;
}

- (IDMZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index {
    IDMZoomingScrollView *thePage = nil;
    for (IDMZoomingScrollView *page in _visiblePages) {
        if (PAGE_INDEX(page) == index) {
            thePage = page; break;
        }
    }
    return thePage;
}

- (IDMZoomingScrollView *)pageDisplayingPhoto:(id<IDMPhoto>)photo {
    IDMZoomingScrollView *thePage = nil;
    for (IDMZoomingScrollView *page in _visiblePages) {
        if (page.photo == photo) {
            thePage = page; break;
        }
    }
    return thePage;
}

- (void)configurePage:(IDMZoomingScrollView *)page forIndex:(NSUInteger)index {
    page.frame = [self frameForPageAtIndex:index];
    page.tag = PAGE_INDEX_TAG_OFFSET + index;
    page.photo = [self photoAtIndex:index];
    
    __block __weak IDMPhoto *photo = (IDMPhoto*)page.photo;
    __weak IDMZoomingScrollView* weakPage = page;
    photo.progressUpdateBlock = ^(CGFloat progress){
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakPage setProgress:progress forPhoto:photo];
        });
    };
}

- (IDMZoomingScrollView *)dequeueRecycledPage {
    IDMZoomingScrollView *page = [_recycledPages anyObject];
    if (page) {
        [_recycledPages removeObject:page];
    }
    return page;
}

// Handle page changes
- (void)didStartViewingPageAtIndex:(NSUInteger)index {
    // Load adjacent images if needed and the photo is already
    // loaded. Also called after photo has been loaded in background
    id <IDMPhoto> currentPhoto = [self photoAtIndex:index];
    if ([currentPhoto underlyingImage]) {
        // photo loaded so load ajacent now
        [self loadAdjacentPhotosIfNecessary:currentPhoto];
    }
    if ([_delegate respondsToSelector:@selector(photoBrowser:didShowPhotoAtIndex:)]) {
        [_delegate photoBrowser:self didShowPhotoAtIndex:index];
    }
    
    //[self setControlsHidden:NO animated:YES permanent:YES];
}

#pragma mark - Frame Calculations

- (CGRect)frameForPagingScrollView {
    CGRect frame = self.view.bounds;
    frame.origin.x -= PADDING;
    frame.size.width += (2 * PADDING);
    frame = [self adjustForSafeArea:frame adjustForStatusBar:false];
    return frame;
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index {
    // We have to use our paging scroll view's bounds, not frame, to calculate the page placement. When the device is in
    // landscape orientation, the frame will still be in portrait because the pagingScrollView is the root view controller's
    // view, so its frame is in window coordinate space, which is never rotated. Its bounds, however, will be in landscape
    // because it has a rotation transform applied.
    CGRect bounds = _pagingScrollView.bounds;
    CGRect pageFrame = bounds;
    pageFrame.size.width -= (2 * PADDING);
    pageFrame.origin.x = (bounds.size.width * index) + PADDING;
    return pageFrame;
}

- (CGSize)contentSizeForPagingScrollView {
    // We have to use the paging scroll view's bounds to calculate the contentSize, for the same reason outlined above.
    CGRect bounds = _pagingScrollView.bounds;
    return CGSizeMake(bounds.size.width * [self numberOfPhotos], bounds.size.height);
}

- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index {
    CGFloat pageWidth = _pagingScrollView.bounds.size.width;
    CGFloat newOffset = index * pageWidth;
    return CGPointMake(newOffset, 0);
}

- (BOOL)isLandscape:(UIInterfaceOrientation)orientation
{
    return UIInterfaceOrientationIsLandscape(orientation);
}

- (CGRect)frameForToolbarAtOrientation:(UIInterfaceOrientation)orientation {
    CGFloat height = 44;
    
    if ([self isLandscape:orientation])
        height = 32;
    
    CGRect rtn = CGRectMake(0, self.view.bounds.size.height - height, self.view.bounds.size.width, height);
    rtn = [self adjustForSafeArea:rtn adjustForStatusBar:true];
    
    return rtn;
}

- (CGRect)frameForDoneButtonAtOrientation:(UIInterfaceOrientation)orientation {
    CGFloat screenWidth = self.view.bounds.size.width;
    
    CGRect rtn = CGRectMake(screenWidth - self.doneButtonRightInset - self.doneButtonSize.width, self.doneButtonTopInset, self.doneButtonSize.width, self.doneButtonSize.height);
    
    rtn = [self adjustForSafeArea:rtn adjustForStatusBar:true];
    
    return rtn;
}

- (CGRect)frameForTopBackgroundView:(UIView *)topView atIndex:(NSUInteger)index {
    CGRect pageFrame = [self frameForPageAtIndex:index];
    
    CGRect topViewFrame = CGRectMake(pageFrame.origin.x, 0, pageFrame.size.width, 120);
    
    return topViewFrame;
}

- (CGRect)frameForCaptionView:(IDMCaptionView *)captionView atIndex:(NSUInteger)index {
    CGRect pageFrame = [self frameForPageAtIndex:index];
    
    CGSize captionSize = [captionView sizeThatFits:CGSizeMake(pageFrame.size.width, 0)];
    CGRect captionFrame = CGRectMake(pageFrame.origin.x, pageFrame.size.height - captionSize.height - (_toolbar.superview?_toolbar.frame.size.height:0), pageFrame.size.width, captionSize.height);
    
    return captionFrame;
}

- (CGRect)adjustForSafeArea:(CGRect)rect adjustForStatusBar:(BOOL)adjust {
    if (@available(iOS 11.0, *)) {
        return [self adjustForSafeArea:rect adjustForStatusBar:adjust forInsets:self.view.safeAreaInsets];
    }
    UIEdgeInsets insets = UIEdgeInsetsMake(_statusBarHeight, 0, 0, 0);
    return [self adjustForSafeArea:rect adjustForStatusBar:adjust forInsets:insets];
}

- (CGRect)adjustForSafeArea:(CGRect)rect adjustForStatusBar:(BOOL)adjust forInsets:(UIEdgeInsets) insets {
    return [IDMUtils adjustRect:rect forSafeAreaInsets:insets forBounds:self.view.bounds adjustForStatusBar:adjust statusBarHeight:_statusBarHeight];
}

#pragma mark - UIScrollView Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView  {
    // Checks
    if (!_viewIsActive || _performingLayout || _rotating) return;
    
    // Tile pages
    [self tilePages];
    
    // Calculate current page
    CGRect visibleBounds = _pagingScrollView.bounds;
    NSInteger index = (NSInteger) (floorf(CGRectGetMidX(visibleBounds) / CGRectGetWidth(visibleBounds)));
    if (index < 0) index = 0;
    if (index > [self numberOfPhotos] - 1) index = [self numberOfPhotos] - 1;
    NSUInteger previousCurrentPage = _currentPageIndex;
    _currentPageIndex = index;
    if (_currentPageIndex != previousCurrentPage) {
        [self didStartViewingPageAtIndex:index];
        
        if(_arrowButtonsChangePhotosAnimated) [self updateToolbar];
        
        IDMPhoto *photo = [self photoAtIndex:index];
        
        if (photo != nil && photo.underlyingView != nil) {
            _senderViewForAnimation = photo.underlyingView;
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    // Hide controls when dragging begins
    [self setControlsHidden:YES animated:YES permanent:NO];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self setControlsHidden:NO animated:YES permanent:YES];
    
    // Update toolbar when page changes
    if(! _arrowButtonsChangePhotosAnimated) [self updateToolbar];
}

#pragma mark - Toolbar

- (void)updateToolbar {
    // Counter
    _counterLabel.text = nil;
    
    // Buttons
    _previousButton.enabled = (_currentPageIndex > 0);
    _nextButton.enabled = (_currentPageIndex < [self numberOfPhotos]-1);
}

- (void)jumpToPageAtIndex:(NSUInteger)index {
    // Change page
    if (index < [self numberOfPhotos]) {
        CGRect pageFrame = [self frameForPageAtIndex:index];
        
        if(_arrowButtonsChangePhotosAnimated)
        {
            [_pagingScrollView setContentOffset:CGPointMake(pageFrame.origin.x - PADDING, 0) animated:YES];
        }
        else
        {
            _pagingScrollView.contentOffset = CGPointMake(pageFrame.origin.x - PADDING, 0);
            [self updateToolbar];
        }
    }
    
    // Update timer to give more time
    [self hideControlsAfterDelay];
}

- (void)gotoPreviousPage { [self jumpToPageAtIndex:_currentPageIndex-1]; }
- (void)gotoNextPage     { [self jumpToPageAtIndex:_currentPageIndex+1]; }

#pragma mark - Control Hiding / Showing

// If permanent then we don't set timers to hide again
- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated permanent:(BOOL)permanent {
    IDMPhoto *p = [self photoAtIndex:_currentPageIndex];
    
    if (p.isVideo) {
        return;
    }
    
    [self cancelControlHiding];
    
    // Top background views
    NSMutableSet *topBackgroundViews = [[NSMutableSet alloc] initWithCapacity:_visiblePages.count];
    
    // Captions
    NSMutableSet *captionViews = [[NSMutableSet alloc] initWithCapacity:_visiblePages.count];
    for (IDMZoomingScrollView *page in _visiblePages) {
        if (page.captionView) [captionViews addObject:page.captionView];
    }
    
    // Hide/show bars
    [UIView animateWithDuration:(animated ? 0.1 : 0) animations:^(void) {
        CGFloat alpha = hidden ? 0 : 1;
        [self.navigationController.navigationBar setAlpha:alpha];
        [self->_toolbar setAlpha:alpha];
        [self->_doneButton setAlpha:alpha];
        for (UIView *v in captionViews) v.alpha = alpha;
        for (UIView *v in topBackgroundViews) v.alpha = alpha;
    } completion:^(BOOL finished) {}];
    
    // Control hiding timer
    // Will cancel existing timer but only begin hiding if they are visible
    if (!permanent) [self hideControlsAfterDelay];
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)cancelControlHiding {
    // If a timer exists then cancel and release
    if (_controlVisibilityTimer) {
        [_controlVisibilityTimer invalidate];
        _controlVisibilityTimer = nil;
    }
}

// Enable/disable control visiblity timer
- (void)hideControlsAfterDelay {
    if (![self areControlsHidden]) {
        [self cancelControlHiding];
        _controlVisibilityTimer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(hideControls) userInfo:nil repeats:NO];
    }
}

- (BOOL)areControlsHidden { return (_toolbar.alpha == 0); }
- (void)hideControls      { if(_autoHide) [self setControlsHidden:YES animated:YES permanent:NO]; }
- (void)toggleControls    { [self setControlsHidden:![self areControlsHidden] animated:YES permanent:YES]; }

#pragma mark - Properties

- (void)setInitialPageIndex:(NSUInteger)index {
    // Validate
    if (index >= [self numberOfPhotos]) index = [self numberOfPhotos]-1;
    _initalPageIndex = index;
    _currentPageIndex = index;
    if ([self isViewLoaded]) {
        [self jumpToPageAtIndex:index];
        if (!_viewIsActive) [self tilePages]; // Force tiling if view is not visible
    }
}

#pragma mark - Buttons

- (void)doneButtonPressed:(id)sender {
    if (_senderViewForAnimation && _currentPageIndex == _initalPageIndex) {
        IDMZoomingScrollView *scrollView = [self pageDisplayedAtIndex:_currentPageIndex];
        [self performCloseAnimationWithScrollView:scrollView];
    }
    else {
        _senderViewForAnimation.hidden = NO;
        [self prepareForClosePhotoBrowser];
        [self dismissPhotoBrowserAnimated:YES];
    }
}

- (void)actionButtonPressed:(id)sender {
    IDMPhoto *photo = [self photoAtIndex:_currentPageIndex];
    
    if ([self numberOfPhotos] > 0 && [photo underlyingImage]) {
        if(!_actionButtonTitles)
        {
            // Activity view
            NSMutableArray *activityItems = [NSMutableArray arrayWithObject:[photo underlyingImage]];
            if (photo.caption) [activityItems addObject:photo.caption];
            
            self.activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
            
            self.activityViewController.excludedActivityTypes = [[NSArray alloc] initWithObjects:
                                                                 UIActivityTypeCopyToPasteboard,
                                                                 UIActivityTypePostToWeibo,
                                                                 UIActivityTypePostToFacebook,
                                                                 UIActivityTypePostToTwitter,
                                                                 UIActivityTypePostToFlickr,
                                                                 UIActivityTypePostToVimeo,
                                                                 UIActivityTypeAirDrop,
                                                                 UIActivityTypeSaveToCameraRoll,
                                                                 UIActivityTypeMail,
                                                                 UIActivityTypeMessage,
                                                                 UIActivityTypeAssignToContact,
                                                                 UIActivityTypePrint,
                                                                 nil];
            
            __typeof__(self) __weak selfBlock = self;
            [self.activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
                [selfBlock hideControlsAfterDelay];
                selfBlock.activityViewController = nil;
            }];
            
            [self presentViewController:self.activityViewController animated:YES completion:nil];
        }
        else
        {
            // Action sheet
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            for(NSString *action in _actionButtonTitles) {
                UIAlertAction *newAction = [UIAlertAction actionWithTitle:action style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self hideControlsAfterDelay]; // Continue as normal...
                }];
                
                [alert addAction:newAction];
            }
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:IDMPhotoBrowserLocalizedStrings(@"Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [self hideControlsAfterDelay]; // Continue as normal...
            }];
            
            [alert addAction:cancelAction];
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [alert setModalPresentationStyle:UIModalPresentationPopover];
                alert.popoverPresentationController.barButtonItem = sender;
            }
            
            [self presentViewController:alert animated:YES completion:nil];
        }
        
        // Keep controls hidden
        [self setControlsHidden:NO animated:YES permanent:YES];
    }
    
    photo = nil;
}

#pragma mark - pop Animation

- (void)animateView:(UIView *)view toFrame:(CGRect)frame completion:(void (^)(void))completion
{
    POPSpringAnimation *animation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
    [animation setSpringBounciness:6];
    [animation setDynamicsMass:1];
    [animation setToValue:[NSValue valueWithCGRect:frame]];
    [view pop_addAnimation:animation forKey:nil];
    
    if (completion)
    {
        [animation setCompletionBlock:^(POPAnimation *animation, BOOL finished) {
            completion();
        }];
    }
}

@end

