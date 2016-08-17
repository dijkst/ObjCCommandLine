//
//  ObjCAppleScript.h
//  ObjCCommandLine
//
//  Created by Whirlwind on 15/12/10.
//  Copyright © 2015年 alibaba-inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ObjCAppleScript : NSObject

+ (id)executeWithURL:(NSURL *)url
               error:(NSDictionary * *)errorDict;

+ (id)executeWithSource:(NSString *)source
                  error:(NSDictionary * *)errorDict;

@end
