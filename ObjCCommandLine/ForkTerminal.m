//
//  ForkTerminal.m
//  ObjCCommandLine
//
//  Created by 詹迟晶 on 2020/7/12.
//  Copyright © 2020 dijkst. All rights reserved.
//

#import "ForkTerminal.h"
#import "TerminalBase+Private.h"
#import "NSFileHandle+isReadableAddon.h"
#import "ObjCShell.h"
#include "sys/pipe.h"
#include "sys/ioctl.h"

@implementation ForkTerminal

- (void)startProcess {
    [super startProcess];
    if (self.detach) {
        [self startProcessWithDetachMode];
    } else {
        [self startProcessWithAttachMode];
    }
}

- (void)startProcessWithAttachMode {
    int pipefd[4];
    pipe(pipefd);
    pipe(pipefd + 2);

    int saved_stdin = dup(STDIN_FILENO);
    pid_t pid = fork();
    if (pid > 0) {
        childProcessID = pid;

        int outfd = pipefd[0];
        int errfd = pipefd[2];

        dispatch_async(dispatch_queue_create("STDOUT Reader Thread", DISPATCH_QUEUE_CONCURRENT), ^(void) {
            unsigned char buf[PIPE_SIZE];
            while (!self->taskDidTerminate) {
                ssize_t i = read(outfd, &buf, PIPE_SIZE);
                NSData *data = [NSData dataWithBytes:buf length:i];
                [self appendOutput:data];
            }
            self->stdoutEmpty = YES;
            [self cleanup];
        });

        dispatch_async(dispatch_queue_create("STDERR Reader Thread", DISPATCH_QUEUE_CONCURRENT), ^(void) {
            unsigned char buf[PIPE_SIZE];
            while (!self->taskDidTerminate) {
                ssize_t i = read(errfd, &buf, PIPE_SIZE);
                NSData *data = [NSData dataWithBytes:buf length:i];
                [self appendError:data];
            }
            self->stderrEmpty = YES;
            [self cleanup];
        });

        dispatch_async(dispatch_queue_create("Shell Wait Thread", DISPATCH_QUEUE_CONCURRENT), ^(void) {
            int status = 0;
            waitpid(self->childProcessID, &status, 0);
            self.terminationStatus = WEXITSTATUS(status);

            ssize_t outfdSize = PIPE_SIZE;
            while (outfdSize > 0) {
                ioctl(outfd, FIONREAD, &outfdSize);
            }

            ssize_t errfdSize = PIPE_SIZE;
            while (errfdSize > 0) {
                ioctl(errfd, FIONREAD, &errfdSize);
            }

            self->taskDidTerminate = YES;
            close(outfd);
            close(errfd);
        });
    } else if (pid == 0) {
        setvbuf(stdout, nil, _IONBF, 0);
        setvbuf(stderr, nil, _IONBF, 0);

        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);

        dup2(pipefd[3], STDERR_FILENO);
        close(pipefd[3]);

        dup2(saved_stdin, STDIN_FILENO);
        close(saved_stdin);

        [self runChildProcess];
    } else {
        NSLog(@"error");
    }
}

- (void)startProcessWithDetachMode {
    pid_t pid = fork();
    if (pid > 0) {
        childProcessID = pid;
    } else if (pid == 0) {
        int stdoutId = open("/dev/null", O_WRONLY);
        dup2(stdoutId, STDOUT_FILENO);
        close(stdoutId);

        int stderrId = open("/dev/null", O_WRONLY);
        dup2(stderrId, STDERR_FILENO);
        close(stderrId);

        int stdinId = open("/dev/null", O_RDONLY);
        dup2(stdinId, STDIN_FILENO);
        close(stdinId);

        [self runChildProcess];
    } else {
        NSLog(@"error");
    }
}

- (BOOL)handleReadable:(NSFileHandle *)handle {
    return [super handleReadable:handle] || handle.readable;
}

@end
