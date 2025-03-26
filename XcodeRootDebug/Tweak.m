#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Foundation/NSUserDefaults+Private.h>
#include <unistd.h>
#include <substrate.h>

extern char **environ;

#define LOG(fmt, ...) NSLog(@"[XcodeRootDebug] " fmt "\n", ##__VA_ARGS__)

static BOOL enabled = YES;
static NSString *debugserverPath = nil;
static NSString *systemDebugserverPath;
typedef CFTypeRef AuthorizationRef;
static NSString * nsNotificationString = @"com.test.xcoderootdebug/preferences.changed";
static BOOL isRootUser = YES;

static NSString* getDebugServerPath()  {
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/debugserver"]) {
        debugserverPath = @"/usr/bin/debugserver";
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/bin/debugserver"]) {
        debugserverPath = @"/var/jb/bin/debugserver";
    }
    return debugserverPath;
}

static void notificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	exit(0);
}


#if __arm64e__
#include <ptrauth.h>
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"


static void *make_sym_callable(void *ptr) {
#if __arm64e__
    ptr = ptrauth_sign_unauthenticated(ptrauth_strip(ptr, ptrauth_key_function_pointer), ptrauth_key_function_pointer, 0);
#endif
    return ptr;
}


static void *make_sym_readable(void *ptr) {
#if __arm64e__
    ptr = ptrauth_strip(ptr, ptrauth_key_function_pointer);
#endif
    return ptr;
}

#pragma clang diagnostic pop

bool (*original_SMJobSubmit)(CFStringRef domain, CFDictionaryRef job, AuthorizationRef auth, CFErrorRef _Nullable *error);
bool hooked_SMJobSubmit(CFStringRef domain, CFDictionaryRef job, AuthorizationRef auth, CFErrorRef _Nullable *error) {
	LOG(@"进入 hooked_SMJobSubmit 原始参数: %@", job);
    
    if (getDebugServerPath() == nil) {
        LOG(@"未找到debugserver命令");
    }
    
	NSMutableDictionary *newJobInfo = [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary *)job];
	NSMutableArray *programArgs = [newJobInfo[@"ProgramArguments"] mutableCopy];
	NSString *program = programArgs[0];
	if (enabled) {
		if([program isEqualToString:@"/Developer/usr/bin/debugserver"] || [program isEqualToString:@"/usr/libexec/debugserver"]) {
			LOG("Found launch %@", program);
			systemDebugserverPath = [program copy];
			if(debugserverPath.length > 0 && access(debugserverPath.UTF8String, F_OK) == 0){
				LOG("Change to launch %@", debugserverPath);
				programArgs[0] = debugserverPath;
				newJobInfo[@"ProgramArguments"] = programArgs;
			} else {
				LOG("Debug Server does not exist at %@", debugserverPath);
			}
			if(isRootUser) {
				LOG("Change to launch with root");
				newJobInfo[@"UserName"] = @"root";
			} else {
				newJobInfo[@"UserName"] = @"mobile";
			}
			LOG(@"Now SMJobSubmit %@", newJobInfo);
		} else if([program isEqualToString:debugserverPath]) {
			LOG("Found launch %@",debugserverPath);
			if(isRootUser) {
				LOG("Change to launch with root");
				newJobInfo[@"UserName"] = @"root";
			} else {
				newJobInfo[@"UserName"] = @"mobile";
			}
			LOG(@"Now SMJobSubmit %@", newJobInfo);
		}
	} else {
		if([program isEqualToString:debugserverPath]) {
			LOG("Found launch %@", debugserverPath);
			LOG("Restore launch system debugserver at %@ with mobile", systemDebugserverPath);
			programArgs[0] = systemDebugserverPath;
			newJobInfo[@"ProgramArguments"] = programArgs;
			newJobInfo[@"UserName"] = @"mobile";
			LOG(@"Now SMJobSubmit %@", newJobInfo);
		}
	}
	LOG(@"新参数: %@", newJobInfo);
	return original_SMJobSubmit(domain, (__bridge CFDictionaryRef)newJobInfo, auth, error);
}

void (* old_SpringBoard_applicationDidFinishLaunching_)(id _self, SEL sel, id application);
void new_SpringBoard_applicationDidFinishLaunching_(id _self, SEL sel, id application) {
    old_SpringBoard_applicationDidFinishLaunching_(_self, sel, application);

    NSString* content = @"XCodeRootDebug设置成功";
    if (getDebugServerPath() == nil) {
        LOG(@"未找到debugserver命令");
        content = @"XCodeRootDebug未找到debugserver命令";
    }

//    // 这个代码在ios16版本会崩溃, 有可能是没有UIAlertView类了
//    UIAlertController* ctlr = [UIAlertController alertControllerWithTitle:@"XCodeRootDebug提示"
//                                                                  message:content
//                                                           preferredStyle:UIAlertControllerStyleAlert];
//
//    [ctlr addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//    }]];
//    UIWindow *keyWindow = [UIApplication sharedApplication].windows.firstObject;
//    [keyWindow.rootViewController presentViewController:ctlr animated:YES completion:nil];
}

static __attribute__((constructor)) void dyld_init(int argc, char **argv, char **envp) {
    LOG(@"hook success (%s = %d) !!!!!!!!!!!!!!!!!!!!!!!!!!!", getprogname(), getpid());
    if (getDebugServerPath() == nil) {
        LOG(@"未找到debugserver命令");
    }
    
    NSString* processName = [NSProcessInfo processInfo].processName;
    LOG(@"当前进程名: %@", processName);
    if ([processName isEqualToString:@"SpringBoard"]) {
        MSHookMessageEx(objc_getClass("SpringBoard"), @selector(applicationDidFinishLaunching:), (IMP)new_SpringBoard_applicationDidFinishLaunching_, (IMP*)&old_SpringBoard_applicationDidFinishLaunching_);
    } else if ([processName isEqualToString:@"lockdownd"]) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, notificationCallback, (CFStringRef)nsNotificationString, NULL, CFNotificationSuspensionBehaviorCoalesce);
        MSImageRef image = MSGetImageByName("/System/Library/PrivateFrameworks/ServiceManagement.framework/ServiceManagement");
        if (!image) {
            LOG("ServiceManagement framework not found, it is impossible");
            return;
        }
        MSHookFunction(MSFindSymbol(image, "_SMJobSubmit"), (void *)hooked_SMJobSubmit, (void **)&original_SMJobSubmit);
    }
}


// 注意不能使用hikari打包，否则会提示ptrauth.h找不到
