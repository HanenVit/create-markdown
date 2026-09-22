#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc < 3) {
            return 1;
        }
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        if (image == nil) {
            return 1;
        }
        BOOL ok = [[NSWorkspace sharedWorkspace] setIcon:image forFile:[NSString stringWithUTF8String:argv[2]] options:0];
        return ok ? 0 : 1;
    }
}
