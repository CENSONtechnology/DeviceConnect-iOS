//
//  DConnectApiSpecBuilder.h
//  DConnectSDK
//
//  Copyright (c) 2016 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>
#import "DConnectApiSpec.h"
#import "DConnectSpecConstants.h"

@interface DConnectApiSpecBuilder : NSObject

@property(nonatomic, strong) NSString *name;

@property(nonatomic) DConnectSpecType type;

@property(nonatomic) DConnectSpecMethod method;

@property(nonatomic, strong) NSString *path;

@property(nonatomic, strong) NSArray *requestParamSpecList;

- (id)init;

- (DConnectApiSpec *)build;

@end
