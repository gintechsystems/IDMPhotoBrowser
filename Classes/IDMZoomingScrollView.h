//
//  IDMZoomingScrollView.h
//  IDMPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "IDMPhotoProtocol.h"
#import "IDMTapDetectingImageView.h"
#import "IDMTapDetectingView.h"

@class IDMPhotoBrowser, IDMPhoto, IDMCaptionView;

@interface IDMZoomingScrollView : UIScrollView <UIScrollViewDelegate, IDMTapDetectingImageViewDelegate, IDMTapDetectingViewDelegate> {
	
	IDMPhotoBrowser *__weak _photoBrowser;
    IDMPhoto *_photo;
	
    // This view references the related caption view for simplified handling in photo browser
    IDMCaptionView *_captionView;
    
	IDMTapDetectingView *_tapView; // for background taps
    
    UIView *_topBackgroundView;
}

@property (nonatomic, strong) IDMTapDetectingImageView *photoImageView;
@property (nonatomic, strong) IDMCaptionView *captionView;
@property (nonatomic, strong) id<IDMPhoto> photo;

@property (nonatomic) CGFloat maximumDoubleTapZoomScale;

@property (nonatomic, strong) UIView *topBackgroundView;

- (id)initWithPhotoBrowser:(IDMPhotoBrowser *)browser;
- (void)displayImage;
- (void)displayImageFailure;
- (void)setProgress:(CGFloat)progress forPhoto:(IDMPhoto*)photo;
- (void)setMaxMinZoomScalesForCurrentBounds;
- (void)prepareForReuse;

- (void)addGradientTopLayer:(CGSize)viewSize;

@end
