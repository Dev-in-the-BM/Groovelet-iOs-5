#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <TargetConditionals.h>

// iOS 5 has no Objective-C collection subscripting methods. Install small
// methods only when the runtime does not provide them.
#if TARGET_OS_IPHONE
static id GLArraySubscript(id object, SEL selector, NSUInteger index) {
    return [object objectAtIndex:index];
}

static id GLDictionarySubscript(id object, SEL selector, id key) {
    return [object objectForKey:key];
}

static void GLMutableArraySubscript(id object, SEL selector, id value, NSUInteger index) {
    [object replaceObjectAtIndex:index withObject:value];
}

static void GLMutableDictionarySubscript(id object, SEL selector, id value, id key) {
    [object setObject:value forKey:key];
}

@interface GLCompatInstaller : NSObject
@end

@implementation GLCompatInstaller

+ (void)load {
    class_addMethod([NSArray class], sel_registerName("objectAtIndexedSubscript:"),
                    (IMP)GLArraySubscript, "@@:I");
    class_addMethod([NSMutableArray class], sel_registerName("setObject:atIndexedSubscript:"),
                    (IMP)GLMutableArraySubscript, "v@:@I");
    class_addMethod([NSDictionary class], sel_registerName("objectForKeyedSubscript:"),
                    (IMP)GLDictionarySubscript, "@@:@");
    class_addMethod([NSMutableDictionary class], sel_registerName("setObject:forKeyedSubscript:"),
                    (IMP)GLMutableDictionarySubscript, "v@:@@");
}

@end
#endif
