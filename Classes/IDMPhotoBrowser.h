//
//  IDMPhotoBrowser.h
//  IDMPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MessageUI/MessageUI.h>
#import <UIKit/UIKit.h>

#import <VIMediaCache.h>

#import "IDMCaptionView.h"
#import "IDMPhoto.h"
#import "IDMPhotoProtocol.h"
#import "IDMTapDetectingImageView.h"

// Delgate
@class IDMPhotoBrowser;
@protocol IDMPhotoBrowserDelegate <NSObject>
@optional
- (void)photoBrowser:(IDMPhotoBrowser *)photoBrowser didShowPhotoAtIndex:(NSUInteger)index;
- (void)photoBrowser:(IDMPhotoBrowser *)photoBrowser didDismissAtPageIndex:(NSUInteger)index;
- (void)photoBrowser:(IDMPhotoBrowser *)photoBrowser willDismissAtPageIndex:(NSUInteger)index;
- (void)photoBrowser:(IDMPhotoBrowser *)photoBrowser didDismissActionSheetWithButtonIndex:(NSUInteger)buttonIndex photoIndex:(NSUInteger)photoIndex;
- (IDMCaptionView *)photoBrowser:(IDMPhotoBrowser *)photoBrowser captionViewForPhotoAtIndex:(NSUInteger)index;
- (void)photoBrowser:(IDMPhotoBrowser *)photoBrowser imageFailed:(NSUInteger)index imageView:(IDMTapDetectingImageView *)imageView;
- (UIView *)photoBrowser:(IDMPhotoBrowser *)photoBrowser topBackgroundViewForPhotoAtIndex:(NSUInteger)index;
@end

// IDMPhotoBrowser
@interface IDMPhotoBrowser : UIViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate, UIActionSheetDelegate>

// Properties
@property (nonatomic, weak) id <IDMPhotoBrowserDelegate> delegate;

// Toolbar customization
@property (nonatomic) BOOL displayToolbar;
@property (nonatomic) BOOL displayCounterLabel;
@property (nonatomic) BOOL displayArrowButton;
@property (nonatomic) BOOL displayActionButton;
@property (nonatomic, strong) NSArray *actionButtonTitles;
@property (nonatomic, weak) UIImage *leftArrowImage, *leftArrowSelectedImage;
@property (nonatomic, weak) UIImage *rightArrowImage, *rightArrowSelectedImage;
@property (nonatomic, weak) UIImage *actionButtonImage, *actionButtonSelectedImage;

// View customization
@property (nonatomic) BOOL displayDoneButton;
@property (nonatomic) BOOL useWhiteBackgroundColor;
@property (nonatomic) UIImage *doneButtonImage;
@property (nonatomic, assign) CGFloat doneButtonRightInset, doneButtonTopInset;
@property (nonatomic, assign) CGSize doneButtonSize;
@property (nonatomic, weak) UIColor *trackTintColor, *progressTintColor;

@property (nonatomic) UIImage *scaleImage;

@property (nonatomic) UITableView *currentTableView;
@property (nonatomic) UICollectionView *currentCollectionView;

@property (nonatomic) BOOL arrowButtonsChangePhotosAnimated;

@property (nonatomic) BOOL disableVerticalSwipe;
@property (nonatomic) BOOL forceHideStatusBar;
@property (nonatomic) BOOL is3DTouchPreviewing;
@property (nonatomic) BOOL usePopAnimation;

// defines zooming of the background (default 1.0)
@property (nonatomic) float backgroundScaleFactor;

// animation time (default .28)
@property (nonatomic) float animationDuration;

@property (nonatomic) UIImageView *tempPlay;

@property (nonatomic) AVPlayer *videoPlayer;
@property (nonatomic) AVPlayerViewController *videoPlayerVC;

@property (nonatomic) VIResourceLoaderManager *loaderManager;


// Init
- (id)initWithPhotos:(NSArray *)photosArray;

// Init (animated)
- (id)initWithPhotos:(NSArray *)photosArray animatedFromView:(UIView*)view;
- (id)initWithPhotos:(NSArray *)photosArray animatedFromView:(UIView*)view withWindow:(UIWindow*)window;

// Init with NSURL objects
- (id)initWithPhotoURLs:(NSArray *)photoURLsArray;

// Init with NSURL objects (animated)
- (id)initWithPhotoURLs:(NSArray *)photoURLsArray animatedFromView:(UIView*)view;
- (id)initWithPhotoURLs:(NSArray *)photoURLsArray animatedFromView:(UIView*)view withWindow:(UIWindow*)window;

// Reloads the photo browser and refetches data
- (void)reloadData;

// Set page that photo browser starts on
- (void)setInitialPageIndex:(NSUInteger)index;

// Get IDMPhoto at index
- (id<IDMPhoto>)photoAtIndex:(NSUInteger)index;

- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated permanent:(BOOL)permanent;

- (BOOL)validateUrl:(NSString *)candidate;

- (void)playVideo;
- (void)moviePlaybackComplete:(NSNotification *)notification;

@end
