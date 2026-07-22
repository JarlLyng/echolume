//
//  ObjCExceptionCatcher.m
//  echolume
//

#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher

+ (nullable NSString *)reasonRunning:(void (^)(void))block {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        NSString *name = exception.name ?: @"NSException";
        NSString *reason = exception.reason ?: @"unknown";
        return [NSString stringWithFormat:@"%@: %@", name, reason];
    }
}

@end
