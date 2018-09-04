// ObjCShell.h
//

#import <Foundation/Foundation.h>

@protocol ObjCShellDelegate  <NSObject>

@optional
- (void)logOutputData:(NSData *)data;
- (void)logOutputString:(NSString *)string;

- (void)logErrorData:(NSData *)data;
- (void)logErrorString:(NSString *)string;

@end

@interface ObjCShell : NSObject

@property (nonatomic, strong) NSString *outputString;
@property (nonatomic, strong) NSString *errorString;
@property (nonatomic, readonly) NSData *outputData;
@property (nonatomic, readonly) NSData *errorData;

@property (nonatomic, readonly) int terminationStatus;

@property (nonatomic, weak) id<ObjCShellDelegate> delegate;

+ (NSString *)scriptForName:(NSString *)name ofType:(NSString *)type;
+ (NSString *)commandWithAdministrator:(NSString *)command;

+ (void)setSHELL:(NSString *)shell;
+ (NSString *)SHELL;

+ (BOOL)isSudoEnvironment;
+ (BOOL)isCMDEnvironment;
+ (void)setIsCMDEnvironment:(BOOL)cmd;

- (int)executeCommand:(NSString *)command;
- (int)executeCommand:(NSString *)command inWorkingDirectory:(NSString *)path;
- (int)executeCommand:(NSString *)command inWorkingDirectory:(NSString *)path env:(NSDictionary *)env;

- (void)cancel;

@end
