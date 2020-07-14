//
//  ForkTerminal.m
//  ObjCCommandLine
//
//  Created by 詹迟晶 on 2020/7/12.
//  Copyright © 2020 dijkst. All rights reserved.
//

#import "ForkTerminal.h"
#import "TerminalBase+Private.h"
#import "ObjCShell.h"

@implementation ForkTerminal

- (void)startProcess {
    [super startProcess];

    int pipefd[4];
    pipe(pipefd);
    pipe(pipefd + 2);

    int saved_stdin = dup(STDIN_FILENO);
    pid_t pid = fork();
    if (pid > 0) {
        childProcessID = pid;
        int outfd = pipefd[0];
        int errfd = pipefd[2];

        outHandle = [[NSFileHandle alloc] initWithFileDescriptor:outfd closeOnDealloc:YES];
        [self watchSTDOUT:outHandle];

        errorHandle = [[NSFileHandle alloc] initWithFileDescriptor:errfd closeOnDealloc:YES];
        [self watchSTDERR:errorHandle];

        dispatch_async(dispatch_queue_create("Shell Wait Thread", DISPATCH_QUEUE_CONCURRENT), ^(void) {
            int status = 0;
            waitpid(self->childProcessID, &status, 0);
            self.terminationStatus = WEXITSTATUS(status);
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

@end
