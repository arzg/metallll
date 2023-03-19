#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <simd/simd.h>

struct Vertex {
	vector_float4 position;
	vector_float4 color;
};

@interface MainView : MTKView {
	id<MTLCommandQueue> commandQueue;
	id<MTLRenderPipelineState> renderPipeline;
	id<MTLBuffer> vertexArray;
}
@end

@implementation MainView

- (id)initWithFrame:(CGRect)frame device:(id<MTLDevice>)device
{
	self = [super initWithFrame:frame device:device];
	self.colorPixelFormat = MTLPixelFormatRGBA16Float;
	self.sampleCount = 4;
	self.clearColor = MTLClearColorMake(0, 0, 0, 0);
	self.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceLinearDisplayP3);
	self.layer.backgroundColor = CGColorCreateSRGB(0, 0, 0, 0);
	self.layer.opaque = NO;
	((CAMetalLayer*)self.layer).wantsExtendedDynamicRangeContent = YES;

	struct Vertex vertexArrayData[3] = {
		{ .position = { 0.0, 0.5, 0, 1 }, .color = { 16, 0, 0, 1 } },
		{ .position = { -0.5, -0.5, 0, 1 }, .color = { 0, 16, 0, 1 } },
		{ .position = { 0.5, -0.5, 0, 1 }, .color = { 0, 0, 16, 1 } }
	};
	vertexArray = [device newBufferWithBytes:vertexArrayData
	                                  length:sizeof(vertexArrayData)
	                                 options:MTLResourceCPUCacheModeDefaultCache];

	NSError* error = nil;
	NSURL* path = [NSURL fileURLWithPath:@"out/shaders.metallib" isDirectory:false];
	id<MTLLibrary> library =
	        [device newLibraryWithURL:path
	                            error:&error];
	if (error != nil) {
		NSLog(@"%@", error);
		exit(1);
	}

	MTLRenderPipelineDescriptor* desc =
	        [[MTLRenderPipelineDescriptor alloc] init];
	desc.colorAttachments[0].pixelFormat = self.colorPixelFormat;
	desc.vertexFunction = [library newFunctionWithName:@"vertexShader"];
	desc.fragmentFunction = [library newFunctionWithName:@"fragmentShader"];

	renderPipeline = [device newRenderPipelineStateWithDescriptor:desc
	                                                        error:&error];
	if (error != nil) {
		NSLog(@"%@", error);
		exit(1);
	}

	commandQueue = [device newCommandQueue];

	return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

	MTLRenderPassDescriptor* passDesc = self.currentRenderPassDescriptor;

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

	[commandBuffer presentDrawable:self.currentDrawable];
	[commandBuffer commit];
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
		MainView* view = [MainView alloc];
		[view initWithFrame:rect
		             device:MTLCreateSystemDefaultDevice()];
		window.contentView = view;

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
