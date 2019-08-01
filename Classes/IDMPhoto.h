//
//  IDMPhoto.h
//  IDMPhotoBrowser
//
//  Created by Michael Waterfall on 17/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

#import <SDWebImage/SDWebImageManager.h>

#import "IDMPhotoProtocol.h"

// This class models a photo/image and it's caption
// If you want to handle photos, caching, decompression
// yourself then you can simply ensure your custom data model
// conforms to IDMPhotoProtocol
@interface IDMPhoto : NSObject <IDMPhoto>

// Progress download block, used to update the circularView
typedef void (^IDMProgressUpdateBlock)(CGFloat progress);

// Properties
@property (nonatomic, strong) NSString *caption;

@property (nonatomic) BOOL isVideo;
@property (nonatomic) BOOL isVideoImageReady;
@property (nonatomic) BOOL isPlaying;

@property (nonatomic, strong) NSURL *photoURL;
@property (nonatomic, strong) NSURL *videoURL;

@property (nonatomic, strong) IDMProgressUpdateBlock progressUpdateBlock;

@property (nonatomic, strong) UIImage *placeholderImage;

@property (nonatomic, strong) UIImage *underlyingImage;

@property (nonatomic, strong) UIView *underlyingView;

@property (nonatomic, strong) UIImageView *playButton;

@property CMTime currentSeekTime;

// Class
+ (IDMPhoto *)photoWithImage:(UIImage *)image;
+ (IDMPhoto *)photoWithFilePath:(NSString *)path;
+ (IDMPhoto *)photoWithURL:(NSURL *)url;
+ (IDMPhoto *)photoWithVideoURL:(NSURL *)url;

+ (NSArray *)photosWithImages:(NSArray *)imagesArray;
+ (NSArray *)photosWithFilePaths:(NSArray *)pathsArray;
+ (NSArray *)photosWithURLs:(NSArray *)urlsArray;

// Init
- (id)initWithImage:(UIImage *)image;
- (id)initWithFilePath:(NSString *)path;
- (id)initWithURL:(NSURL *)url;
- (id)initWithVideoURL:(NSURL *)url;

@end

