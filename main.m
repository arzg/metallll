#include <Cocoa/Cocoa.h>

int main()
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

	NSWindow* window = [NSWindow alloc];
	[window
	        initWithContentRect:NSMakeRect(0, 0, 420, 69)
	                  styleMask:NSWindowStyleMaskTitled
	                    backing:NSBackingStoreBuffered
	                      defer:NO];
	[window setTitle:@"metalllllllllll"];

	[window makeKeyAndOrderFront:nil];

	[NSApp activateIgnoringOtherApps:YES];

	[NSApp run];
}
