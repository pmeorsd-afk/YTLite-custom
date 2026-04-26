#import <Foundation/Foundation.h>

// jbroot() is only available with roothide - define a no-op fallback for normal builds
#ifndef jbroot
#define jbroot(x) (x)
#endif


NS_ASSUME_NONNULL_BEGIN

@interface NSBundle (YTLite)

// Returns YTLite default bundle. Supports rootless if defined in compilation parameters
@property (class, nonatomic, readonly) NSBundle *ytl_defaultBundle;

@end

NS_ASSUME_NONNULL_END
