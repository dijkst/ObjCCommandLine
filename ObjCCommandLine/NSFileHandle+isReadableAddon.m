//
//  NSFileHandle+isReadableAddon.m
//  ObjCCommandLine
//
//  Created by 詹迟晶 on 2020/2/4.
//  Copyright © 2020 dijkst. All rights reserved.
//

#import "NSFileHandle+isReadableAddon.h"
#include <sys/_select.h>

@implementation NSFileHandle (isReadableAddon)

- (BOOL)readable {
    int fd = [self fileDescriptor];
    fd_set fdset;
    struct timeval tmout = { 0, 0 }; // return immediately
    FD_ZERO(&fdset);
    FD_SET(fd, &fdset);
    if (select(fd + 1, &fdset, NULL, NULL, &tmout) <= 0)
        return NO;
    return FD_ISSET(fd, &fdset);
}

@end
