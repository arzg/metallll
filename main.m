#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <simd/simd.h>

#define kSampleCount 4

#define kGlyphWidth 256
#define kGlyphHeight 512

void* fontGlyph()
{
	void* p = calloc(kGlyphWidth * kGlyphHeight, 1);
	CGColorSpaceRef colorspace = CGColorSpaceCreateWithName(kCGColorSpaceLinearGray);
	CGContextRef ctx = CGBitmapContextCreate(
	        p,
	        kGlyphWidth, kGlyphHeight, 8, kGlyphWidth,
	        colorspace, kCGImageAlphaOnly);

	CTFontRef font = (__bridge CTFontRef)
	        [NSFont systemFontOfSize:kGlyphWidth * 2
	                          weight:NSFontWeightRegular];

	CGGlyph glyph;
	uint16_t encoded = 'a';
	CTFontGetGlyphsForCharacters(font, &encoded, &glyph, 1);

	CGPoint position = { 0, CTFontGetDescent(font) };
	CTFontDrawGlyphs(font, &glyph, &position, 1, ctx);

	return p;
}

struct Uniforms {
	vector_float2 position;
	vector_float2 size;
	vector_float4 color;
	bool isGlyph;
};

#define QUAD_COUNT 5

@interface MainView : NSView {
	CAMetalLayer* metalLayer;
	CVDisplayLinkRef displayLink;
	id<MTLDevice> device;
	id<MTLCommandQueue> commandQueue;
	id<MTLRenderPipelineState> renderPipeline;

	MTLTextureDescriptor* multisampleTextureDesc;
	id<MTLTexture> multisampleTexture;

	id<MTLBuffer> indexBuffer;
	id<MTLBuffer> uniformsBuffer;
	id<MTLTexture> texture;
}
@end

@implementation MainView

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	self.wantsLayer = YES;
	self.layer = [CAMetalLayer layer];
	metalLayer = (CAMetalLayer*)self.layer;
	device = MTLCreateSystemDefaultDevice();
	metalLayer.device = device;

	metalLayer.pixelFormat = MTLPixelFormatRGBA16Float;
	metalLayer.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearDisplayP3);
	metalLayer.wantsExtendedDynamicRangeContent = YES;
	self.layer.opaque = NO;

	metalLayer.framebufferOnly = NO;

	multisampleTextureDesc = [[MTLTextureDescriptor alloc] init];
	multisampleTextureDesc.pixelFormat = metalLayer.pixelFormat;
	multisampleTextureDesc.textureType = MTLTextureType2DMultisample;
	multisampleTextureDesc.sampleCount = kSampleCount;

	uint16_t indexBufferData[6] = { 0, 1, 2, 0, 2, 3 };
	indexBuffer = [device newBufferWithBytes:indexBufferData
	                                  length:sizeof(indexBufferData)
	                                 options:MTLResourceCPUCacheModeDefaultCache];

	uniformsBuffer = [device newBufferWithLength:sizeof(struct Uniforms) * QUAD_COUNT
	                                     options:MTLResourceCPUCacheModeDefaultCache];

	NSError* error = nil;

	MTLTextureDescriptor* textureDesc
	        = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatA8Unorm
	                                                             width:kGlyphWidth
	                                                            height:kGlyphHeight
	                                                         mipmapped:NO];
	texture = [device newTextureWithDescriptor:textureDesc];
	MTLRegion region = MTLRegionMake2D(0, 0, kGlyphWidth, kGlyphHeight);
	[texture replaceRegion:region
	           mipmapLevel:0
	             withBytes:fontGlyph()
	           bytesPerRow:kGlyphWidth];

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
	desc.rasterSampleCount = kSampleCount;

	MTLRenderPipelineColorAttachmentDescriptor* framebufferAttachment
	        = desc.colorAttachments[0];

	framebufferAttachment.pixelFormat = metalLayer.pixelFormat;

	framebufferAttachment.blendingEnabled = YES;
	framebufferAttachment.sourceRGBBlendFactor = MTLBlendFactorOne;
	framebufferAttachment.sourceAlphaBlendFactor = MTLBlendFactorOne;
	framebufferAttachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
	framebufferAttachment.destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

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
	CVDisplayLinkSetOutputCallback(
	        displayLink, displayLinkCallback, (__bridge void*)self);
	CVDisplayLinkStart(displayLink);

	NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self
	                       selector:@selector(windowWillClose:)
	                           name:NSWindowWillCloseNotification
	                         object:self.window];

	return self;
}

- (void)windowWillClose:(NSNotification*)notification
{
	if (notification.object == self.window)
		CVDisplayLinkStop(displayLink);
}

- (void)viewDidChangeBackingProperties
{
	[super viewDidChangeBackingProperties];
	[self updateDrawableSize];
}

- (void)setFrameSize:(NSSize)size
{
	[super setFrameSize:size];
	[self updateDrawableSize];
}

- (void)updateDrawableSize
{
	NSSize size = self.bounds.size;
	size.width *= self.window.screen.backingScaleFactor;
	size.height *= self.window.screen.backingScaleFactor;
	if (size.width == 0 && size.height == 0)
		return;
	metalLayer.drawableSize = size;

	[self updateMultisampleTexture:size];
}

- (void)updateMultisampleTexture:(NSSize)size
{
	multisampleTextureDesc.width = size.width;
	multisampleTextureDesc.height = size.height;
	multisampleTexture
	        = [device newTextureWithDescriptor:multisampleTextureDesc];
}

static CVReturn displayLinkCallback(
        CVDisplayLinkRef displayLink,
        const CVTimeStamp* now,
        const CVTimeStamp* outputTime,
        CVOptionFlags flagsIn,
        CVOptionFlags* flagsOut,
        void* displayLinkContext)
{
	MainView* view = (__bridge MainView*)displayLinkContext;
	[view renderOneFrame];
	return kCVReturnSuccess;
}

- (void)renderOneFrame
{
	id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

	MTLRenderPassDescriptor* passDesc = [[MTLRenderPassDescriptor alloc] init];
	passDesc.colorAttachments[0].texture = multisampleTexture;
	passDesc.colorAttachments[0].resolveTexture = drawable.texture;
	passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
	passDesc.colorAttachments[0].storeAction = MTLStoreActionMultisampleResolve;
	passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);

	id<MTLRenderCommandEncoder> commandEncoder =
	        [commandBuffer renderCommandEncoderWithDescriptor:passDesc];
	[commandEncoder setRenderPipelineState:renderPipeline];

	float width = metalLayer.drawableSize.width;
	float height = metalLayer.drawableSize.height;
	float factor = 1;
	float padding = 100;
	struct Uniforms uniforms[QUAD_COUNT] = {
		{
		        .position = { 0, 0 },
		        .size = {
		                width,
		                height,
		        },
		        .color = { 0, 0, 0, 0.5 },
		        .isGlyph = false,
		},
		{
		        .position = {
		                padding,
		                (height - kGlyphHeight * factor) / 2,
		        },
		        .size = {
		                kGlyphWidth * factor,
		                kGlyphHeight * factor,
		        },
		        .color = { 1, 0, 0, 0.1 },
		        .isGlyph = false,
		},
		{
		        .position = {
		                padding,
		                (height - kGlyphHeight * factor) / 2,
		        },
		        .size = {
		                kGlyphWidth * factor,
		                kGlyphHeight * factor,
		        },
		        .color = { 1, 0, 0, 0.5 },
		        .isGlyph = true,
		},
		{
		        .position = {
		                (width - kGlyphWidth * factor) / 2,
		                (height - kGlyphHeight * factor) / 2,
		        },
		        .size = {
		                kGlyphWidth * factor,
		                kGlyphHeight * factor,
		        },
		        .color = { 0, 1, 0, 0.5 },
		        .isGlyph = true,
		},
		{
		        .position = {
		                width - kGlyphWidth * factor - padding,
		                (height - kGlyphHeight * factor) / 2,
		        },
		        .size = {
		                kGlyphWidth * factor,
		                kGlyphHeight * factor,
		        },
		        .color = { 0, 0, 1, 0.5 },
		        .isGlyph = true,
		}
	};
	memcpy(uniformsBuffer.contents, &uniforms, sizeof(uniforms));
	[commandEncoder setVertexBuffer:uniformsBuffer
	                         offset:0
	                        atIndex:0];

	vector_uint2 viewportSize = { width, height };
	[commandEncoder setVertexBytes:&viewportSize
	                        length:sizeof(viewportSize)
	                       atIndex:1];

	float edrMax = self.window.screen.maximumExtendedDynamicRangeColorComponentValue;
	[commandEncoder setVertexBytes:&edrMax
	                        length:sizeof(edrMax)
	                       atIndex:2];

	[commandEncoder setFragmentTexture:texture
	                           atIndex:0];

	[commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
	                           indexCount:6
	                            indexType:MTLIndexTypeUInt16
	                          indexBuffer:indexBuffer
	                    indexBufferOffset:0
	                        instanceCount:QUAD_COUNT];

	[commandEncoder endEncoding];

	[commandBuffer presentDrawable:drawable];
	[commandBuffer commit];
}

// We accept key events.
- (BOOL)acceptsFirstResponder
{
	return YES;
}

// Forward raw key events to relevant methods
// like insertText:, insertNewline, etc.
- (void)keyDown:(NSEvent*)event
{
	[self interpretKeyEvents:[NSArray arrayWithObject:event]];
}

- (void)insertText:(id)s
{
	NSAssert(
	        [s isKindOfClass:[NSString class]],
	        @"insertText: was passed a class other than NSString");
	NSString* string = s;
	NSLog(@"string: “%@”", string);
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

		NSMenuItem* quitMenuItem
		        = [[NSMenuItem alloc] initWithTitle:@"Quit metallll"
		                                     action:@selector(terminate:)
		                              keyEquivalent:@"q"];
		[appMenu addItem:quitMenuItem];

		NSRect rect = NSMakeRect(100, 100, 500, 400);

		NSWindowStyleMask style = NSWindowStyleMaskTitled
		        | NSWindowStyleMaskResizable
		        | NSWindowStyleMaskClosable;
		NSWindow* window
		        = [[NSWindow alloc] initWithContentRect:rect
		                                      styleMask:style
		                                        backing:NSBackingStoreBuffered
		                                          defer:NO];
		window.title = @"metalllllllllll";
		MainView* view = [[MainView alloc] initWithFrame:rect];
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
