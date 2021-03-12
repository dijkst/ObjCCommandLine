// ObjCShell.h
//

#import <Foundation/Foundation.h>
#import <sys/termios.h>

@protocol ObjCShellDelegate  <NSObject>

@optional
- (void)logOutputData:(NSData *)data;
- (void)logOutputString:(NSString *)string;

- (void)logErrorData:(NSData *)data;
- (void)logErrorString:(NSString *)string;

@end

@interface ObjCShell : NSObject

@property (nonatomic, assign) BOOL useTTY;
@property (nonatomic, assign) BOOL useLoginEnironment;

@property (nonatomic, readonly) NSString *outputString;
@property (nonatomic, readonly) NSString *errorString;
@property (nonatomic, readonly) NSData *outputData;
@property (nonatomic, readonly) NSData *errorData;

@property (nonatomic, readonly) int terminationStatus;

@property (nonatomic, weak) id<ObjCShellDelegate> delegate;
@property (nonatomic, copy) void (^logOutputStringBlock)(NSString *);
@property (nonatomic, copy) void (^logErrorStringBlock)(NSString *);
@property (nonatomic, copy) void (^logOutputDataBlock)(NSData *);
@property (nonatomic, copy) void (^logErrorDataBlock)(NSData *);

- (instancetype)init;
- (instancetype)initWithTTY:(BOOL)tty;

+ (NSString *)scriptForName:(NSString *)name ofType:(NSString *)type;
+ (NSString *)commandWithAdministrator:(NSString *)command;
+ (NSString *)commandWithAdministrator:(NSString *)command sudo:(BOOL)sudo prompt:(NSString *)prompt;

@property (nonatomic, strong, class) NSString *shell;
@property (nonatomic, strong, class) NSDictionary<NSString *, NSString *> *environment;
@property (nonatomic, assign, class) BOOL isCMDEnvironment;

+ (BOOL)isSudoEnvironment;

- (int)executeCommand:(NSString *)command;
- (int)executeCommand:(NSString *)command inWorkingDirectory:(NSString *)path;
- (int)executeCommand:(NSString *)command inWorkingDirectory:(NSString *)path env:(NSDictionary *)env;

- (void)cancel;
- (void)appendInput:(NSData *)input;

@end

FOUNDATION_EXPORT void rawSTDIN(void(^block)(void));

FOUNDATION_EXPORT void storeSTDIN(void);

FOUNDATION_EXPORT void resetSTDIN(void);
