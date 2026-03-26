#import "OpenURLHelper.h"

@implementation OpenURLHelper

+ (BOOL)openURL:(NSURL *)url fromResponder:(UIResponder *)responder {
    UIResponder *current = responder;
    while (current) {
        if ([current isKindOfClass:[UIApplication class]]) {
            UIApplication *app = (UIApplication *)current;
            [app openURL:url options:@{} completionHandler:nil];
            return YES;
        }
        current = [current nextResponder];
    }
    return NO;
}

@end
