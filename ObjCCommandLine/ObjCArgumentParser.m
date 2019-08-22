//
//  ObjCArgumentParser.m
//  ObjCCommandLine
//
//  Created by Whirlwind on 2019/8/22.
//  Copyright © 2019 dijkst. All rights reserved.
//

#import "ObjCArgumentParser.h"

NSArray<NSString *> *argumentParse(NSString *string) {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    NSString *flag = nil;
    for (NSUInteger i = 0; i < [string length]; i++) {
        NSString *c = [string substringWithRange:NSMakeRange(i, 1)];
        if ([flag isEqualToString:@"\\"]) {
            [current appendString:c];
            flag = nil;
        } else if ([flag isEqualToString:c]) {
            if ([current length] != 0) {
                [result addObject:current];
                current = [NSMutableString string];
            }
            flag = nil;
        } else if (flag == nil) {
            if ([c isEqualToString:@" "]) {
                if ([current length] != 0) {
                    [result addObject:current];
                    current = [NSMutableString string];
                }
            } else if ([c isEqualToString:@"\\"] || ([c isEqualToString:@"'"]) || [c isEqualToString:@"\""]) {
                flag = c;
            } else {
                [current appendString:c];
            }
        } else {
            [current appendString:c];
        }
    }
    if ([current length] > 0) {
        [result addObject:current];
    }
    return result;
}
