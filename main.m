#include <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface MainView : NSView {
	CVDisplayLinkRef displayLink;
}
@end

@implementation MainView

- (id)initWithFrame:(CGRect)frame
{
	puts("init");
	self = [super initWithFrame:frame];
	self.wantsLayer = YES;
	self.layer = [CAMetalLayer layer];
	CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
	CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, self);
	CVDisplayLinkStart(displayLink);
	return self;
}

static CVReturn displayLinkCallback(
        CVDisplayLinkRef displayLink,
        const CVTimeStamp* now,
        const CVTimeStamp* outputTime,
        CVOptionFlags flagsIn,
        CVOptionFlags* flagsOut,
        void* displayLinkContext)
{
	MainView* view = (MainView*)displayLinkContext;
	[view renderFrame:outputTime];
	return kCVReturnSuccess;
}

- (void)renderFrame:(const CVTimeStamp*)outputTime
{
	CAMetalLayer* metalLayer = (CAMetalLayer*)self.layer;
	puts("render here");
}

@end

int main()
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

	NSRect rect = NSMakeRect(0, 0, 420, 69);

	NSWindow* window = [NSWindow alloc];
	[window
	        initWithContentRect:rect
	                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable
	                    backing:NSBackingStoreBuffered
	                      defer:NO];
	window.title = @"metalllllllllll";
	window.contentView = [[MainView alloc] initWithFrame:rect];

	[window makeKeyAndOrderFront:nil];
	[NSApp activateIgnoringOtherApps:YES];

	[NSApp run];
}
