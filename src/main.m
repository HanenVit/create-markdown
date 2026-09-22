#import <Cocoa/Cocoa.h>
#include <string.h>

static void createMarkdownAtFolder(NSString *folderPath) {
    if (folderPath.length == 0) {
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:folderPath isDirectory:&isDir] || !isDir) {
        folderPath = [folderPath stringByDeletingLastPathComponent];
    }
    NSString *base = @"Новый документ";
    NSString *name = [base stringByAppendingPathExtension:@"md"];
    NSUInteger index = 2;
    while ([fm fileExistsAtPath:[folderPath stringByAppendingPathComponent:name]]) {
        name = [[NSString stringWithFormat:@"%@ %lu", base, (unsigned long)index] stringByAppendingPathExtension:@"md"];
        index += 1;
        if (index > 999) {
            return;
        }
    }
    NSString *filePath = [folderPath stringByAppendingPathComponent:name];
    if (![fm createFileAtPath:filePath contents:[NSData data] attributes:nil]) {
        NSLog(@"CreateMarkdown: failed %@", filePath);
        NSBeep();
        return;
    }
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:filePath]]];
}

static NSString *pathFromCreateURL(NSURL *url) {
    if (url == nil || ![url.scheme isEqualToString:@"createmd"]) {
        return nil;
    }
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"path"]) {
            return item.value;
        }
    }
    return nil;
}

// Ask Finder off the main thread. A synchronous AppleEvent during launch
// deadlocks: Finder waits for this app to finish opening.
static NSString *frontFinderFolder(void) {
    NSString *source =
        @"tell application \"Finder\"\n"
        "if (count of Finder windows) is 0 then\n"
        "return POSIX path of (path to desktop folder)\n"
        "end if\n"
        "try\n"
        "set t to target of front Finder window\n"
        "if t is missing value then error \"no target\"\n"
        "return POSIX path of (t as alias)\n"
        "end try\n"
        "end tell";
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/osascript"];
    task.arguments = @[@"-e", source];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = [NSPipe pipe];
    if (![task launchAndReturnError:nil]) {
        return nil;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        if (task.isRunning) {
            [task terminate];
        }
    });
    [task waitUntilExit];
    if (task.terminationStatus != 0) {
        return nil;
    }
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *path = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    path = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return path.length > 0 ? path : nil;
}

@interface CreateMarkdownDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, assign) BOOL handledURL;
@end

@implementation CreateMarkdownDelegate

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    self.handledURL = YES;
    for (NSURL *url in urls) {
        createMarkdownAtFolder(pathFromCreateURL(url));
    }
    [application terminate:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.handledURL) {
            [NSApp terminate:nil];
            return;
        }
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSString *folder = frontFinderFolder();
            dispatch_async(dispatch_get_main_queue(), ^{
                if (folder.length == 0) {
                    NSBeep();
                } else {
                    createMarkdownAtFolder(folder);
                }
                [NSApp terminate:nil];
            });
        });
    });
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--create") == 0 && i + 1 < argc) {
                createMarkdownAtFolder([NSString stringWithUTF8String:argv[i + 1]]);
                return 0;
            }
        }
        CreateMarkdownDelegate *delegate = [CreateMarkdownDelegate new];
        NSApplication *app = [NSApplication sharedApplication];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}
