//
//  ObjCExceptionCatcher.h
//  echolume
//
//  Swift cannot catch Objective-C NSExceptions, and AVAudioEngine's
//  installTapOnBus:/start: raise them (not Swift errors) on bad device
//  transitions — an uncaught NSException calls abort(), which crashes with
//  no recoverable path. This tiny shim runs a block inside @try/@catch so the
//  Swift side can treat an AVFAudio throw as a normal failure.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCExceptionCatcher : NSObject

/// Runs `block`. Returns nil on success, or the NSException's reason string if
/// the block raised one. (Deliberately NOT the NSError** convention, which
/// Swift would auto-bridge into a `throws` method.)
+ (nullable NSString *)reasonRunning:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
