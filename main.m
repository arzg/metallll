#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <simd/simd.h>

struct Vertex {
	vector_float4 position;
	vector_float4 color;
};

@interface MainView : NSView {
	CVDisplayLinkRef displayLink;
	id<MTLDevice> device;
	CAMetalLayer* metalLayer;
	id<MTLCommandQueue> commandQueue;
	id<MTLRenderPipelineState> renderPipeline;
	id<MTLBuffer> vertexArray;
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

	struct Vertex vertexArrayData[3] = {
		{ .position = { 0.0, 0.5, 0, 1 }, .color = { 1, 0, 0, 1 } },
		{ .position = { -0.5, -0.5, 0, 1 }, .color = { 0, 1, 0, 1 } },
		{ .position = { 0.5, -0.5, 0, 1 }, .color = { 0, 0, 1, 1 } }
	};
	vertexArray = [device newBufferWithBytes:vertexArrayData
	                                  length:sizeof(vertexArrayData)
	                                 options:MTLResourceCPUCacheModeDefaultCache];

	NSError* error = nil;

	NSURL* path = [NSURL fileURLWithPath:@"shaders.metal" isDirectory:false];
	NSString* shaders =
	        [[NSString alloc] initWithContentsOfURL:path
	                                       encoding:NSUTF8StringEncoding
	                                          error:&error];
	if (error != nil) {
		NSLog(@"%@", error);
		exit(1);
	}

	id<MTLLibrary> library =
	        [device newLibraryWithSource:shaders
	                             options:[[MTLCompileOptions alloc] init]
	                               error:&error];
	if (error != nil) {
		NSLog(@"%@", error);
		exit(1);
	}

	MTLRenderPipelineDescriptor* desc =
	        [[MTLRenderPipelineDescriptor alloc] init];
	desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
	desc.vertexFunction = [library newFunctionWithName:@"vertexShader"];
	desc.fragmentFunction = [library newFunctionWithName:@"fragmentShader"];

	renderPipeline = [device newRenderPipelineStateWithDescriptor:desc
	                                                        error:&error];
	if (error != nil) {
		NSLog(@"%@", error);
		exit(1);
	}

	commandQueue = [device newCommandQueue];

	CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
	CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, self);
	CVDisplayLinkStart(displayLink);
	return self;
}

- (void)setFrameSize:(NSSize)size
{
	[super setFrameSize:size];

	CGFloat scaleFactor = self.window.screen.backingScaleFactor;
	CGSize newSize = self.bounds.size;
	newSize.width *= scaleFactor;
	newSize.height *= scaleFactor;

	if (newSize.width <= 0 || newSize.width <= 0) {
		return;
	}

	if (newSize.width == metalLayer.drawableSize.width && newSize.height == metalLayer.drawableSize.height) {
		return;
	}

	metalLayer.drawableSize = newSize;
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

		MTLRenderPassDescriptor* passDesc = [[MTLRenderPassDescriptor alloc] init];
		passDesc.colorAttachments[0].texture = texture;
		passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
		passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
		passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.3, 0.4, 0.5, 1);

		id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

		id<MTLRenderCommandEncoder> commandEncoder =
		        [commandBuffer renderCommandEncoderWithDescriptor:passDesc];
		[commandEncoder setRenderPipelineState:renderPipeline];
		[commandEncoder setVertexBuffer:vertexArray
		                         offset:0
		                        atIndex:0];
		[commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle
		                   vertexStart:0
		                   vertexCount:3];
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
