#include <Cocoa/Cocoa.h>
#include <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

@interface MainView : NSView {
	CVDisplayLinkRef displayLink;
	id<MTLDevice> device;
	CAMetalLayer* metalLayer;
	id<MTLCommandQueue> commandQueue;
}
@end

@implementation MainView

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	self.wantsLayer = YES;
	self.layer = [CAMetalLayer layer];
	self.layer.backgroundColor = CGColorCreateSRGB(0, 0, 0, 0);
	metalLayer = (CAMetalLayer*)self.layer;
	metalLayer.opaque = NO;

	device = MTLCreateSystemDefaultDevice();
	metalLayer.device = device;
	commandQueue = [device newCommandQueue];

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
	@autoreleasepool {
		id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
		id<MTLTexture> texture = drawable.texture;

		MTLRenderPassDescriptor* renderPassDescriptor =
		        [MTLRenderPassDescriptor renderPassDescriptor];
		renderPassDescriptor.colorAttachments[0].texture = texture;
		renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
		renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
		renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);

		id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

		id<MTLRenderCommandEncoder> commandEncoder =
		        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
		[commandEncoder endEncoding];

		[commandBuffer presentDrawable:drawable];
		[commandBuffer commit];
	}
}

@end

int main()
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

		NSMenu* menuBar = [[NSMenu alloc] init];
		NSMenuItem* appMenuItem = [[NSMenuItem alloc] init];
		[menuBar addItem:appMenuItem];
		NSMenu* appMenu = [[NSMenu alloc] init];
		appMenuItem.submenu = appMenu;

		NSApp.mainMenu = menuBar;

		NSMenuItem* quitMenuItem = [NSMenuItem alloc];
		[quitMenuItem initWithTitle:@"Quit metallll"
		                     action:@selector(terminate:)
		              keyEquivalent:@"q"];
		[appMenu addItem:quitMenuItem];

		NSRect rect = NSMakeRect(0, 0, 420, 69);

		NSWindow* window = [NSWindow alloc];
		NSWindowStyleMask style = NSWindowStyleMaskTitled
		        | NSWindowStyleMaskResizable
		        | NSWindowStyleMaskClosable;
		[window
		        initWithContentRect:rect
		                  styleMask:style
		                    backing:NSBackingStoreBuffered
		                      defer:NO];
		window.title = @"metalllllllllll";
		window.contentView = [[MainView alloc] initWithFrame:rect];

		// Zero alpha results in no window shadow, so we use “almost zero”.
		window.backgroundColor = [NSColor colorWithRed:0
		                                         green:0
		                                          blue:0
		                                         alpha:CGFLOAT_EPSILON];

		[window makeKeyAndOrderFront:nil];

		dispatch_async(dispatch_get_main_queue(), ^{
		    [NSApp activateIgnoringOtherApps:YES];
		});

		[NSApp run];
	}
}
