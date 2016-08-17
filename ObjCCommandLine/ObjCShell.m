// ObjCShell.m
//

#import "ObjCShell.h"
#import "AMShellWrapper.h"

static NSString *SHELL;
static BOOL     CMD;

@interface ObjCShell () <AMShellWrapperDelegate> {
    dispatch_semaphore_t sem;
}

@property (nonatomic, strong) AMShellWrapper   *task;
@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation ObjCShell

- (id)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("shell.output", NULL);
    }
    return self;
}

+ (NSString *)SHELL {
    if (!SHELL) {
        SHELL = [[[NSProcessInfo processInfo] environment] objectForKey:@"SHELL"] ? : @"/bin/bash";
    }
    return SHELL;
}

+ (void)setSHELL:(NSString *)shell {
    SHELL = shell;
}

+ (BOOL)isSudoEnvironment {
    return [[[NSProcessInfo processInfo] environment] objectForKey:@"SUDO_USER"] != nil;
}

+ (void)setIsCMDEnvironment:(BOOL)cmd {
    CMD = cmd;
}

+ (BOOL)isCMDEnvironment {
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    if ([env objectForKey:@"TERM"] != nil || [env objectForKey:@"SSH_CLIENT"] != nil) {
        return YES;
    }
    return CMD;
}

+ (NSString *)scriptForName:(NSString *)name ofType:(NSString *)type {
    return [[NSBundle mainBundle] pathForResource:name ofType:type];
}

+ (NSString *)commandWithAdministrator:(NSString *)command {
    if ([self isCMDEnvironment]) {
        return [NSString stringWithFormat:@"sudo -S %@", command];
    }
    return [NSString stringWithFormat:@"osascript -e \"do shell script \\\"%@\\\" with administrator privileges\"", command];
}

- (int)executeCommand:(NSString *)command {
    return [self executeCommand:command inWorkingDirectory:nil];
}

- (int)executeCommand:(NSString *)command inWorkingDirectory:(NSString *)path {
    return [self executeCommand:command inWorkingDirectory:path env:nil];
}

- (int)executeCommand:(NSString *)command inWorkingDirectory:(NSString *)path env:(NSDictionary *)env {
    sem         = dispatch_semaphore_create(0);
    _outputData = [NSMutableData data];
    _errorData  = [NSMutableData data];
    NSArray *args = nil;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"NSDocumentRevisionsDebugMode"] || (!env && ![[self class] isCMDEnvironment])) {
        args = @[@"-l", @"-i", @"-c", command];
    } else {
        args = @[@"-c", command];
    }
    self.task = [[AMShellWrapper alloc] initWithLaunchPath:[[self class] SHELL]
                                          workingDirectory:path
                                               environment:env
                                                 arguments:args
                                                   context:NULL];

    self.task.delegate = self;



    // 必须在主线程，
    [self.task performSelectorOnMainThread:@selector(startProcess) withObject:nil waitUntilDone:YES];
    //    while (!self.task.finish) {
    //        [[NSRunLoop currentRunLoop] runMode:NSRunLoopCommonModes beforeDate:[NSDate distantFuture]];
    //    }
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    self.outputString = [[[NSString alloc] initWithData:self.outputData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.errorString  = [[[NSString alloc] initWithData:self.errorData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    return self.task.terminationStatus;
}

- (void)cancel {
    [self.task stopProcess];
}

#pragma mark - Private
- (void)processStarted:(AMShellWrapper *)wrapper {

}

- (void)processFinished:(AMShellWrapper *)wrapper withTerminationStatus:(int)resultCode {
    dispatch_semaphore_signal(sem);
}

- (void)process:(AMShellWrapper *)wrapper appendOutput:(NSData *)data {
    dispatch_sync(_queue, ^{
        if ([self.delegate respondsToSelector:@selector(logOutputData:)]) {
            [self.delegate logOutputData:data];
        }
        if ([self.delegate respondsToSelector:@selector(logOutputString:)]) {
            NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            [self.delegate logOutputString:output];
        }
        [(NSMutableData *) self.outputData appendData:data];
    });
}

- (void)process:(AMShellWrapper *)wrapper appendError:(NSData *)data {
    dispatch_sync(_queue, ^{
        if ([self.delegate respondsToSelector:@selector(logErrorData:)]) {
            [self.delegate logErrorData:data];
        }
        if ([self.delegate respondsToSelector:@selector(logErrorString:)]) {
            NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            [self.delegate logErrorString:output];
        }
        [(NSMutableData *) self.errorData appendData:data];
    });
}

@end
