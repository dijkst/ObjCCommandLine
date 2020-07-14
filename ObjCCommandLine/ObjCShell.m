// ObjCShell.m
//

#import "ObjCShell.h"
#import "TTYTerminal.h"
#import "ForkTerminal.h"
#import "ObjCArgumentParser.h"
#include "sys/pipe.h"

static struct termios STDINSettings;

void rawSTDIN(void(^block)(void)) {
    struct termios oldSettings;
    tcgetattr(STDIN_FILENO, &oldSettings);
    struct termios settings;
    tcgetattr(STDIN_FILENO, &settings);
    cfmakeraw(&settings);
    tcsetattr(STDIN_FILENO, TCSANOW, &settings);
    block();
    tcsetattr(STDIN_FILENO, TCSANOW, &oldSettings);
}

void storeSTDIN() {
    tcgetattr(STDIN_FILENO, &STDINSettings);
}

void resetSTDIN() {
    tcsetattr(STDIN_FILENO, TCSANOW, &STDINSettings);
}

static NSString     *SHELL;
static NSDictionary *ENV;
static BOOL         CMD;

@interface ObjCShell () <TerminalDelegate> {
    dispatch_semaphore_t sem;
}

@property (nonatomic, strong) TerminalBase *task;
@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation ObjCShell {
    // log 返回的 Data 在缓冲区中内，可能由于空间不够，导致不足以存放完整的字符编码。
    // 这部分字节应该合并到下次缓冲区首部。
    NSData *dryOutputData;
    NSData *dryErrorData;

    NSRunLoop *runLoop;
}

- (id)init {
    return [self initWithTTY:false];
}

- (instancetype)initWithTTY:(BOOL)tty {
    if (self = [super init]) {
        _queue = dispatch_queue_create("shell.output", NULL);
        _useLoginEnironment = YES;
        _useTTY = tty;
    }
    return self;
}

+ (NSDictionary *)environment {
    return ENV;
}

+ (void)setEnvironment:(NSDictionary *)environment {
    ENV = environment;
}

+ (NSString *)shell {
    if (!SHELL) {
        SHELL = @"/bin/bash";
    }
    return SHELL;
}

+ (void)setShell:(NSString *)shell {
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
    if ([env objectForKey:@"SSH_CLIENT"] != nil) {
        return YES;
    }
    return CMD;
}

+ (NSString *)scriptForName:(NSString *)name ofType:(NSString *)type {
    return [[NSBundle mainBundle] pathForResource:name ofType:type];
}

+ (NSString *)commandWithAdministrator:(NSString *)command {
    return [self commandWithAdministrator:command sudo:[self isCMDEnvironment] prompt:nil];
}

+ (NSString *)commandWithAdministrator:(NSString *)command sudo:(BOOL)sudo prompt:(NSString *)prompt {
    if (sudo) {
        if (prompt) {
            return [NSString stringWithFormat:@"sudo -S -p \"%@\" -- sh -c \"%@\"", prompt, command];
        }
        return [NSString stringWithFormat:@"sudo -S -- sh -c \"%@\"", command];
    }
    if (prompt) {
        return [NSString stringWithFormat:@"osascript -e \"do shell script \\\"%@\\\" with prompt \\\"%@\\\" with administrator privileges\"", command, prompt];
    }
    return [NSString stringWithFormat:@"osascript -e \"do shell script \\\"%@\\\" with administrator privileges\"", command];
}

- (int)terminationStatus {
    return self.task.terminationStatus;
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
    if (!env) env = ENV;
    NSArray *args = nil;
    Class wrapper = _useTTY ? [TTYTerminal class] : [ForkTerminal class];
    NSString *launch = [[self class] shell];
    args = argumentParse(command);
    launch = [args firstObject];
    self.task = [[wrapper alloc] initWithLaunchPath:launch
                                   workingDirectory:path
                                        environment:env
                                          arguments:args
                                            context:NULL];

    self.task.delegate = self;

    if (ObjCShell.isCMDEnvironment) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSFileHandle *inputHandle = [NSFileHandle fileHandleWithStandardInput];
            [inputHandle waitForDataInBackgroundAndNotify];
        });
    }

    runLoop = [NSRunLoop currentRunLoop];
//    if (_useTTY) {
//        rawSTDIN(^{
            [self.task startProcess];
            while (!self.task.finish) {
                [self->runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            }
//        });
//    } else {
//        // 必须在主线程
//        [self.task performSelectorOnMainThread:@selector(startProcess) withObject:nil waitUntilDone:YES];
//        while (!self.task.finish) {
//            [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
//        }
//    }
    self.outputString = [[[NSString alloc] initWithData:self.outputData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.errorString  = [[[NSString alloc] initWithData:self.errorData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    return self.task.terminationStatus;
}

- (void)cancel {
    [self.task stopProcess];
}

#pragma mark - Private
- (void)processStarted:(TerminalBase *)wrapper {

}

- (void)processFinished:(TerminalBase *)wrapper withTerminationStatus:(int)resultCode {
    dispatch_semaphore_signal(sem);
    if (runLoop) {
        CFRunLoopStop(runLoop.getCFRunLoop);
    }
}

- (void)process:(TerminalBase *)wrapper appendOutput:(NSData *)data {
    dispatch_sync(_queue, ^{
        if ([self.delegate respondsToSelector:@selector(logOutputData:)]) {
            [self.delegate logOutputData:data];
        }
        if (self.logOutputDataBlock) {
            self.logOutputDataBlock(data);
        }
        if ([self.delegate respondsToSelector:@selector(logOutputString:)] || self.logOutputStringBlock) {
            NSString *output = [self decodeData:data dryPool:&self->dryOutputData];
            if (output) {
                if ([self.delegate respondsToSelector:@selector(logOutputString:)]) {
                    [self.delegate logOutputString:output];
                }
                if (self.logOutputStringBlock) {
                    self.logOutputStringBlock(output);
                }
            }
        }
        [(NSMutableData *)self.outputData appendData:data];
    });
}

- (void)process:(TerminalBase *)wrapper appendError:(NSData *)data {
    dispatch_sync(_queue, ^{
        if ([self.delegate respondsToSelector:@selector(logErrorData:)]) {
            [self.delegate logErrorData:data];
        }
        if (self.logErrorDataBlock) {
            self.logErrorDataBlock(data);
        }
        if ([self.delegate respondsToSelector:@selector(logErrorString:)] || self.logErrorStringBlock) {
            NSString *output = [self decodeData:data dryPool:&self->dryErrorData];
            if (output) {
                if ([self.delegate respondsToSelector:@selector(logErrorString:)]) {
                    [self.delegate logErrorString:output];
                }
                if (self.logErrorStringBlock) {
                    self.logErrorStringBlock(output);
                }
            }
        }
        [(NSMutableData *) self.errorData appendData:data];
    });
}

- (NSString *)decodeData:(NSData *)data dryPool:(NSData * __strong *)dryPool {
    NSMutableData *fullData = [NSMutableData dataWithData:*dryPool];
    [fullData appendData:data];
    *dryPool = nil;
    if (data.length == BIG_PIPE_SIZE) {
        // 达到缓冲区最大值，最后一个字符可能存在丢失的字节
        static int length = 4;
        Byte *bytedata = (Byte*)malloc(length);
        [data getBytes:bytedata range:NSMakeRange(data.length - length, length)];
        int expectBit = 1;
        int actualBit = 1;
        for (; actualBit <= length; actualBit++) {
            // Binary    Hex                 Comments
            // 0xxxxxxx  0x00..0x7F   Only byte of a 1-byte character encoding
            // 10xxxxxx  0x80..0xBF   Continuation bytes (1-3 continuation bytes)
            // 110xxxxx  0xC0..0xDF   First byte of a 2-byte character encoding
            // 1110xxxx  0xE0..0xEF   First byte of a 3-byte character encoding
            // 11110xxx  0xF0..0xF7   First byte of a 4-byte character encoding
            Byte byte = bytedata[length - actualBit];
            if ((byte >> 6) == 2) {
                // Continuation bytes
            } else {
                while (expectBit <= length && ((byte << (expectBit - 1)) & 0x80) != 0) {
                    expectBit++;
                }
                if (expectBit > 1) {
                    expectBit--;
                }
                break;
            }
        }
        free(bytedata);
        if (expectBit > actualBit) {
            *dryPool = [data subdataWithRange:NSMakeRange(data.length - actualBit, actualBit)];
            [fullData resetBytesInRange:NSMakeRange(fullData.length - actualBit, actualBit)];
        }
    }
    return [[NSString alloc] initWithData:fullData encoding:NSUTF8StringEncoding];
}

@end
