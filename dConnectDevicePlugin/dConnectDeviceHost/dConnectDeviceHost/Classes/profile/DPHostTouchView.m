//
//  DPHostTouchView.m
//  dConnectDeviceHost
//
//  Copyright (c) 2015 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DPHostTouchView.h"
#import <DConnectSDK/DConnectSDK.h>
#import "DPHostDevicePlugin.h"
#import "DPHostService.h"
#import "DPHostTouchProfile.h"
#import "DPHostUtils.h"

@interface DPHostTouchView()

@property DConnectEventManager *eventMgr;

@end

@implementation DPHostTouchView

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Get event manager.
        self.eventMgr = [DConnectEventManager sharedManagerForClass:[DPHostDevicePlugin class]];
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Get event (ontouch).
    NSArray *evtsTouch = [_eventMgr eventListForServiceId:DPHostDevicePluginServiceId
                                                  profile:DConnectTouchProfileName
                                                attribute:DConnectTouchProfileAttrOnTouch];
    if (evtsTouch != nil) {
        // Send event.
        [self sendEventData:touches evts:evtsTouch];
    }
    
    // Get event (ontouchstart).
    NSArray *evtsTouchStart = [_eventMgr eventListForServiceId:DPHostDevicePluginServiceId
                                                       profile:DConnectTouchProfileName
                                                     attribute:DConnectTouchProfileAttrOnTouchStart];
    if (evtsTouchStart != nil) {
        // Send event.
        [self sendEventData:touches evts:evtsTouchStart];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *aTouch in touches) {
        if (aTouch.tapCount >= 2) {
            // Get event (ondoubletap).
            NSArray *evtsDoubleTap = [_eventMgr eventListForServiceId:DPHostDevicePluginServiceId
                                                              profile:DConnectTouchProfileName
                                                            attribute:DConnectTouchProfileAttrOnDoubleTap];
            if (evtsDoubleTap != nil) {
                // Send event.
                [self sendEventData:touches evts:evtsDoubleTap];
            }
        } else {
            // Get event (ontouchend).
            NSArray *evtsTouchEnd = [_eventMgr eventListForServiceId:DPHostDevicePluginServiceId
                                                             profile:DConnectTouchProfileName
                                                           attribute:DConnectTouchProfileAttrOnTouchEnd];
            if (evtsTouchEnd != nil) {
                // Send event.
                [self sendEventData:touches evts:evtsTouchEnd];
            }
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Get event (ontouchmove).
    NSArray *evtsMove = [_eventMgr eventListForServiceId:DPHostDevicePluginServiceId
                                                 profile:DConnectTouchProfileName
                                               attribute:DConnectTouchProfileAttrOnTouchMove];
    if (evtsMove != nil) {
        // Send event.
        [self sendEventData:touches evts:evtsMove];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Get event (ontouchcancel).
    NSArray *evtsCancel = [_eventMgr eventListForServiceId:DPHostDevicePluginServiceId
                                                   profile:DConnectTouchProfileName
                                                 attribute:DConnectTouchProfileAttrOnTouchCancel];
    if (evtsCancel != nil) {
        // Send event.
        [self sendEventData:touches evts:evtsCancel];
    }
}

- (void) sendEventData:(NSSet *)allTouches
                  evts:(NSArray *)evts
{
    // Send event data.
    for (DConnectEvent *evt in evts) {
        DConnectMessage *eventMsg = [DConnectEventManager createEventMessageWithEvent:evt];
        
        DConnectMessage *touch = [DConnectMessage message];
        DConnectArray *touches = [DConnectArray array];
        int nCount = 0;
        for (UITouch *aTouch in allTouches) {
            CGPoint pos = [aTouch locationInView:self];
            
            DConnectMessage *touchdata = [DConnectMessage message];
            [DConnectTouchProfile setId: nCount target:touchdata];
            [DConnectTouchProfile setX:pos.x target:touchdata];
            [DConnectTouchProfile setY:pos.y target:touchdata];
            [touches addMessage:touchdata];
            nCount++;
        }
        [DConnectTouchProfile setTouches:touches target:touch];
        [DConnectTouchProfile setTouch:touch target:eventMsg];
        
        if (_delegate) {
            [_delegate sendTouchEvent:(DConnectMessage *)eventMsg];
            [_delegate setTouchCache:(NSString *)evt.attribute touchData:(DConnectMessage *)touch];
        }
    }
}

@end