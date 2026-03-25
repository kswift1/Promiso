@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface OpenURLHelper : NSObject
+ (BOOL)openURL:(NSURL *)url fromResponder:(UIResponder *)responder;
@end

NS_ASSUME_NONNULL_END
