//
//  Cycript.mm
//  MUH-APP-NAME
//
//  Created by MUH-USER on 2020/2/22.
//  Copyright © 2020 MUH-ORGANIZATION-NAME. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <ifaddrs.h>

#ifdef __cplusplus
extern "C" {
#endif
    
    void CYListenServer(short port);
    
#ifdef __cplusplus
}
#endif

#define CYCRIPT_PORT 8888

@interface CycriptPlugin : NSObject

@end

@implementation CycriptPlugin

+ (void)load {
    NSLog(@"Cycript: Cycript has install");
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidFinishLaunching:)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];
}

+ (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self runCycript];
}

+ (void)runCycript {
    NSFileManager *fmgr = [NSFileManager defaultManager];
    short port = CYCRIPT_PORT;
    NSString *LocalPortFile = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"cycrypt.port"];
    if ([fmgr fileExistsAtPath:LocalPortFile]) {
        NSString *content = [NSString stringWithContentsOfFile:LocalPortFile encoding:NSUTF8StringEncoding error:nil];
        if (content.length) {
            NSInteger newPort = [content integerValue];
            if (newPort > 0) {
                port = newPort;
                NSLog(@"Cycript: Use Documents/cycript.port: %d", port);
            }
        }
    } else {
        LocalPortFile = [NSBundle.mainBundle pathForResource:@"cycript" ofType:@"port"];
        if ([fmgr fileExistsAtPath:LocalPortFile]) {
            NSString *content = [NSString stringWithContentsOfFile:LocalPortFile encoding:NSUTF8StringEncoding error:nil];
            if (content.length) {
                NSInteger newPort = [content integerValue];
                if (newPort > 0) {
                    port = newPort;
                    NSLog(@"Cycript: Use Bundle.app/cycript.port: %d", port);
                }
            }
        }
    }
    CYListenServer(port);
    NSLog(@"Cycript: Start at %@:%d", [self localWiFiIPAddress].firstObject?:@"127.0.0.1", port);
}

+ (NSArray *)localWiFiIPAddress {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    NSString *localIP = nil;
    struct ifaddrs *addrs;
    if (getifaddrs(&addrs) == 0) {
        const struct ifaddrs *cursor = addrs;
        while (cursor != NULL) {
            if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0) {
                NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
                if ([name isEqualToString:@"en0"]) // Wi-Fi adapter
                {
                    localIP = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)];
                    if (![array containsObject:localIP]) {
                        [array addObject:localIP];
                    }
                }
            }
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    return [array copy];
}

@end
