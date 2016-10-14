//
//  TopViewModel.h
//  dConnectBrowserForIOS9
//
//  Created by Tetsuya Hirano on 2016/06/17.
//  Copyright © 2016年 GClue,Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GHURLManager.h"

typedef NS_ENUM (NSInteger, SectionType) {
    Bookmark,
    Device
};

@protocol TopViewModelDelegate <NSObject>
- (void)requestDatasourceReload;
@end

@interface TopViewModel : NSObject
@property (strong, nonatomic) NSMutableArray* datasource;
@property (nonatomic, strong) GHURLManager *manager;
@property (nonatomic) NSString* url;
@property (nonatomic, readonly) BOOL isBookmarksEmpty;
@property (nonatomic, readonly) BOOL isDeviceEmpty;
@property (nonatomic, weak) IBOutlet id<TopViewModelDelegate>  delegate;
@property (nonatomic, readonly) __block BOOL isDeviceLoading;

- (void)initialSetup;
- (void)saveSettings;
- (NSString*)checkUrlString:(NSString*)url;
- (NSString*)makeURLFromNotification:(NSNotification*)notif;
- (void)updateDatasource;
- (BOOL)isNeedOpenInitialGuide;
- (void)updateDeviceList;
@end