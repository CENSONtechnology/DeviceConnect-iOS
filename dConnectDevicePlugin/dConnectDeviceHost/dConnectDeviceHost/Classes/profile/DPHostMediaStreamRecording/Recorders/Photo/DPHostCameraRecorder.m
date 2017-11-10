//
//  DPHostCameraRecorder.m
//  dConnectDeviceHost
//
//  Copyright (c) 2017 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import <Photos/Photos.h>

#import "DPHostCameraRecorder.h"
#import "DPHostRecorder.h"
#import "DPHostUtils.h"
#import "DPHostRecorderUtils.h"
@interface DPHostCameraRecorder()
@property (nonatomic) DPHostSimpleHttpServer *httpServer;
/// Preview APIでプレビュー画像URIの配送を行うかどうか。
@property (nonatomic) BOOL sendPreview;
/// 前回プレビューを送った時間。
@property (nonatomic) CMTime lastPreviewTimestamp;
/// Preview APIでプレビュー画像URIの配送を行うインターバル（秒）。
@property (nonatomic) CMTime secPerFrame;

@end
@implementation DPHostCameraRecorder


- (void)initialize
{
    [super initialize];
    self.mimeType = [DConnectFileManager searchMimeTypeForExtension:@"jpg"];
    self.state = DPHostRecorderStateInactive;
    self.sendPreview = NO;
    self.secPerFrame = CMTimeMake(2, 1000);
    [self setPhotoDataSourceType];
    [self setVideoSourceTypeWithDelegate:self];
    NSMutableString *name = @"photo_".mutableCopy;
    
    switch (self.videoCaptureDevice.position) {
        case AVCaptureDevicePositionBack:
            [name appendString:@"back_"];
            [name appendString:[NSString stringWithFormat:@"%lu", (((unsigned long) AVCaptureDevicePositionBack) - 1)]];
            break;
        case AVCaptureDevicePositionFront:
            [name appendString:@"front_"];
            [name appendString:[NSString stringWithFormat:@"%lu", (((unsigned long) AVCaptureDevicePositionFront) - 1)]];
            break;
        case AVCaptureDevicePositionUnspecified:
        default:
            [name appendString:[NSString stringWithFormat:@"%d", (((int) AVCaptureDevicePositionUnspecified) - 1)]];
            break;
    }
    self.name = [NSString stringWithString:name];
    NSArray *cameraSizes = [DPHostRecorderUtils getRecorderSizesForSession:self.session];
    self.supportedPictureSizes = cameraSizes.mutableCopy;
    self.supportedPreviewSizes = cameraSizes.mutableCopy;
    self.pictureSize = [DPHostRecorderUtils getDimensionForPreset:AVCaptureSessionPreset640x480];
    self.previewSize = [DPHostRecorderUtils getDimensionForPreset:AVCaptureSessionPreset640x480];
    self.supportedMimeTypes = @[self.mimeType];
}

- (void)clean
{
    [self stopWebServer];
}


- (BOOL)isSupportedPictureSizeWithWidth:(int)width height:(int)height
{
    CGSize size = [DPHostRecorderUtils getDimensionForPreset:[NSString stringWithFormat:@"%dx%d", width, height]];
    return (size.width != -1 && size.height != -1);
}
- (BOOL)isSupportedPreviewSizeWithWidth:(int)width height:(int)height
{
    CGSize size = [DPHostRecorderUtils getDimensionForPreset:[NSString stringWithFormat:@"%dx%d", width, height]];
    return (size.width != -1 && size.height != -1);
}



- (void)takePhotoWithSuccessCompletion:(void (^)(NSURL *assetURL))successCompletion
                        failCompletion:(void (^)(NSString *errorMessage))failCompletion
{
    __weak DPHostCameraRecorder *weakSelf = self;
    if (self.photoConnection.supportsVideoOrientation) {
        self.photoConnection.videoOrientation = [DPHostRecorderUtils videoOrientationFromDeviceOrientation:[UIDevice currentDevice].orientation];
    }
    __block NSError *error = nil;
    [self performWriting:
     ^{
         if (![weakSelf.session isRunning]) {
             [weakSelf.session startRunning];
         }
         
         // ライトが点いていたら消灯する。
         [DPHostRecorderUtils setLightOnOff:NO];
         // 写真を撮影する。
         [weakSelf takePhotoInternalWithError:&error];
         if (error) {
             if ([weakSelf.session isRunning]) {
                 [weakSelf.session stopRunning];
             }
             if (failCompletion) {
                 failCompletion(error.localizedDescription);
             }
             return;
         }
         [weakSelf saveFileWithCompletionHandler:^(NSURL *assetURL, NSError *error) {
             
             if ([weakSelf.session isRunning]) {
                 [weakSelf.session stopRunning];
             }
             if (error) {
                 failCompletion(error.localizedDescription);
             } else {
                 successCompletion(assetURL);
             }
         }];
     }];
}
- (BOOL)isBack
{
    return (self.videoCaptureDevice.position == AVCaptureDevicePositionBack);
}
- (void)turnOnFlashLight
{
    [DPHostRecorderUtils setLightOnOff:YES];
}
- (void)turnOffFlashLight
{
    [DPHostRecorderUtils setLightOnOff:NO];
}
- (BOOL)getFlashLightState
{
    return [self useLight];
}
- (BOOL)useFlashLight
{
    return [self useLight];
}
- (void)startWebServerWithSuccessCompletion:(void (^)(NSString *uri))successCompletion
                             failCompletion:(void (^)(NSString *errorMessage))failCompletion
{
    if (self.httpServer) {
        [self.httpServer stop];
        self.httpServer = nil;
    }
    
    self.httpServer = [DPHostSimpleHttpServer new];
    self.httpServer.listenPort = 10000;
    BOOL result = [self.httpServer start];
    if (!result) {
        failCompletion(@"MJPEG Server cannot running.");
        return;
    }
    NSError *error = nil;
    [self startRecordingWithError:&error];
    if (error) {
        failCompletion(error.localizedDescription);
        return;
    }
    // プレビュー画像URIの配送処理が開始されていないのなら、開始する。
    self.sendPreview = YES;
    self.lastPreviewTimestamp = kCMTimeInvalid;
    NSString *url = [self.httpServer getUrl];
    if (!url) {
        [self.httpServer stop];
        self.httpServer = nil;
        failCompletion(@"MJPEG Server cannot running.");
        return;
    }
    successCompletion(url);
}

- (void)stopWebServer
{
    if (self.httpServer) {
        [self.httpServer stop];
        self.httpServer = nil;
    }
    [self finishRecordingSample];
    // イベント受領先が存在しないなら、プレビュー画像URIの配送処理を停止する。
    self.sendPreview = NO;
    // 次回プレビュー開始時に影響を与えない為に、初期値（無効値）を設定する。
    self.lastPreviewTimestamp = kCMTimeInvalid;
    
}

#pragma mark - Private Method
#pragma mark - TakePhoto Internal
// 写真撮影
- (void)takePhotoInternalWithError:(NSError**)error
{
    [self.videoCaptureDevice lockForConfiguration:error];
    
    if (!*error) {
        if (self.videoCaptureDevice.focusMode != AVCaptureFocusModeContinuousAutoFocus &&
            [self.videoCaptureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            self.videoCaptureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        } else if (self.videoCaptureDevice.focusMode != AVCaptureFocusModeAutoFocus &&
                   [self.videoCaptureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            self.videoCaptureDevice.focusMode = AVCaptureFocusModeAutoFocus;
        } else if (self.videoCaptureDevice.focusMode != AVCaptureFocusModeLocked &&
                   [self.videoCaptureDevice isFocusModeSupported:AVCaptureFocusModeLocked]) {
            self.videoCaptureDevice.focusMode = AVCaptureFocusModeLocked;
        }
        if (self.videoCaptureDevice.exposureMode != AVCaptureExposureModeContinuousAutoExposure &&
            [self.videoCaptureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            self.videoCaptureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        } else if (self.videoCaptureDevice.exposureMode != AVCaptureExposureModeAutoExpose &&
                   [self.videoCaptureDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
            self.videoCaptureDevice.exposureMode = AVCaptureExposureModeAutoExpose;
        } else if (self.videoCaptureDevice.exposureMode != AVCaptureExposureModeLocked &&
                   [self.videoCaptureDevice isExposureModeSupported:AVCaptureExposureModeLocked]) {
            self.videoCaptureDevice.exposureMode = AVCaptureExposureModeLocked;
        }
        if (self.videoCaptureDevice.whiteBalanceMode != AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance &&
            [self.videoCaptureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            self.videoCaptureDevice.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
        } else if (self.videoCaptureDevice.whiteBalanceMode != AVCaptureWhiteBalanceModeAutoWhiteBalance &&
                   [self.videoCaptureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
            self.videoCaptureDevice.whiteBalanceMode = AVCaptureWhiteBalanceModeAutoWhiteBalance;
        } else if (self.videoCaptureDevice.whiteBalanceMode != AVCaptureWhiteBalanceModeLocked &&
                   [self.videoCaptureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked]) {
            self.videoCaptureDevice.whiteBalanceMode = AVCaptureWhiteBalanceModeLocked;
        }
        if (self.videoCaptureDevice.automaticallyEnablesLowLightBoostWhenAvailable != NO &&
            self.videoCaptureDevice.lowLightBoostSupported) {
            self.videoCaptureDevice.automaticallyEnablesLowLightBoostWhenAvailable = YES;
        }
        [self.videoCaptureDevice unlockForConfiguration];
        
        [NSThread sleepForTimeInterval:0.5];
    }
}

// 写真の保存
- (void)saveFileWithCompletionHandler:(void (^)(NSURL *assetURL, NSError *error))completionHandler
{
    AVCaptureStillImageOutput *stillImageOutput = (AVCaptureStillImageOutput *)self.photoConnection.output;
    __weak DPHostCameraRecorder *weakSelf = self;
    [stillImageOutput captureStillImageAsynchronouslyFromConnection:self.photoConnection
                                                  completionHandler:
     ^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
         __block NSError *err = nil;
         if (!imageDataSampleBuffer || error) {
             err = [DPHostUtils throwsErrorCode:DConnectMessageErrorCodeUnknown message:@"Failed to take a photo."];
             completionHandler(nil, err);
             return;
         }
         NSData *jpegData;
         @try {
             jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
         }
         @catch (NSException *exception) {
             NSString *message;
             if ([[exception name] isEqualToString:NSInvalidArgumentException]) {
                 message = @"Non-JPEG data was given.";
             } else {
                 message = [NSString stringWithFormat:@"%@ encountered.", [exception name]];
             }
             err = [DPHostUtils throwsErrorCode:DConnectMessageErrorCodeUnknown message:message];
             completionHandler(nil, err);
             return;
         }
         
         // EXIF情報を水平に統一する。ブラウザによってはEXIF情報により画像の向きが変わるため。
         CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)jpegData, NULL);
         NSDictionary *metadata = (__bridge NSDictionary*) CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
         NSMutableDictionary *meta = [NSMutableDictionary dictionaryWithDictionary:metadata];
         NSMutableDictionary *tiff = meta[(NSString*) kCGImagePropertyTIFFDictionary];
         tiff[(NSString*) kCGImagePropertyTIFFOrientation] = @(kCGImagePropertyOrientationUp);
         meta[(NSString*) kCGImagePropertyTIFFDictionary] = tiff;
         meta[(NSString*) kCGImagePropertyOrientation] = @(kCGImagePropertyOrientationUp);
         UIImage *jpeg = [[UIImage alloc] initWithData:jpegData];
         UIImage *fixJpeg = [DPHostRecorderUtils fixOrientationWithImage:jpeg position:self.videoCaptureDevice.position];
         
         [[weakSelf library] writeImageToSavedPhotosAlbum:fixJpeg.CGImage metadata:meta completionBlock:
          ^(NSURL *assetURL, NSError *error) {
              if (!assetURL || error) {
                  err = [DPHostUtils throwsErrorCode:DConnectMessageErrorCodeUnknown message:@"Failed to save a photo to camera roll."];
                  completionHandler(nil, err);
                  return;
              }
              completionHandler(assetURL, err);
          }];
     }];
}


- (BOOL)useLight
{
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    BOOL useFlashLight = NO;
    [captureDevice lockForConfiguration:NULL];
    useFlashLight = (captureDevice.torchMode == AVCaptureTorchModeOn);
    [captureDevice unlockForConfiguration];
    return useFlashLight;
}
#pragma mark - AVCapture{Audio,Video}DataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    if (self.sendPreview) {
        CMSampleBufferRef buffer = sampleBuffer;
        CMTime originalSampleBufferTimestamp = CMSampleBufferGetPresentationTimeStamp(buffer);
        if (!CMTIME_IS_NUMERIC(originalSampleBufferTimestamp)) {
            return;
        }
        BOOL requireRelease = NO;
        CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(buffer);
        [self initVideoConnection:connection formatDescription:formatDescription];
        if (CMTIME_IS_INVALID(self.lastPreviewTimestamp)) {
            // まだプレビューの配送を行っていないのであれば、プレビューを配信する。
            [self sendPreviewDataWithSampleBuffer:sampleBuffer];
        } else if (CMTIME_IS_NUMERIC(self.lastPreviewTimestamp)) {
            CMTime elapsedTime =
            CMTimeSubtract(self.lastPreviewTimestamp, originalSampleBufferTimestamp);
            if (CMTIME_COMPARE_INLINE(elapsedTime, >=, self.secPerFrame)) {
                // 規定時間が経過したのであれば、プレビューを配信する。
                [self sendPreviewDataWithSampleBuffer:sampleBuffer];
            }
        } else {
            self.lastPreviewTimestamp = originalSampleBufferTimestamp;
        }
        if (requireRelease) {
            CFRelease(buffer);
        }
    }
}

- (void) sendPreviewDataWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    @autoreleasepool {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (!imageBuffer) {
            return;
        }
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
        if (!ciImage) {
            return;
        }
        
        UIImage *image = [UIImage imageWithCIImage:ciImage];
        CGSize size = image.size;
        double scale = 320000.0 / (size.width * size.height);
        size = CGSizeMake((int)(size.width * scale), (int)(size.height * scale));
        UIGraphicsBeginImageContext(size);
        [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        NSData *jpegData = UIImageJPEGRepresentation(image, 1.0);
        
        [self.httpServer offerData:jpegData];
    }
    
}
@end
