//
//  ObjCAppleScript.m
//  ObjCCommandLine
//
//  Created by Whirlwind on 15/12/10.
//  Copyright © 2015年 alibaba-inc. All rights reserved.
//

#import "ObjCAppleScript.h"
#import "NSAppleEventDescriptor+ToObject.h"

@implementation ObjCAppleScript

+ (id)executeWithURL:(NSURL *)url error:(NSDictionary * *)errorDict {
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithContentsOfURL:url error:errorDict];
    if (appleScript && !*errorDict) {
        return [self executeAppleScript:appleScript error:errorDict];
    }
    return nil;
}

+ (id)executeWithSource:(NSString *)source error:(NSDictionary * *)errorDict {
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:source];
    return [self executeAppleScript:appleScript error:errorDict];
}

+ (id)executeAppleScript:(NSAppleScript *)appleScript error:(NSDictionary *__autoreleasing *)errorDict {
    NSAppleEventDescriptor *returnDescriptor = [appleScript executeAndReturnError:errorDict];
    if (returnDescriptor != NULL) {
        // successful execution
        if (kAENullEvent != [returnDescriptor descriptorType]) {
            // script returned an AppleScript result
            if (cAEList == [returnDescriptor descriptorType]) {
                // result is a list of other descriptors
            } else {
                // coerce the result to the appropriate ObjC type
            }
        }
        return [returnDescriptor toObject];
    } else {
        return nil;
    }
}

@end
