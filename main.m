#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <simd/simd.h>

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

struct Vertex {
	vector_float2 position;
	vector_float2 textureCoordinate;
};

struct Uniforms {
	vector_float2 position;
	vector_float2 size;
	vector_float4 color;
	bool isGlyph;
};

#define QUAD_COUNT 5

@interface MainView : MTKView {
	id<MTLCommandQueue> commandQueue;
	id<MTLRenderPipelineState> renderPipeline;
	id<MTLBuffer> vertexBuffer;
	id<MTLBuffer> indexBuffer;
	id<MTLBuffer> uniformsBuffer;
	id<MTLTexture> texture;
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

	struct Vertex vertexBufferData[4] = {
		{ .position = { -1, -1 }, .textureCoordinate = { 0, 1 } },
		{ .position = { -1, 1 }, .textureCoordinate = { 0, 0 } },
		{ .position = { 1, 1 }, .textureCoordinate = { 1, 0 } },
		{ .position = { 1, -1 }, .textureCoordinate = { 1, 1 } }
	};
	vertexBuffer = [device newBufferWithBytes:vertexBufferData
	                                   length:sizeof(vertexBufferData)
	                                  options:MTLResourceCPUCacheModeDefaultCache];

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
	MTLRegion region = {
		.origin = { 0, 0, 0 },
		.size = { kGlyphWidth, kGlyphHeight, 1 },
	};
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

	MTLRenderPipelineColorAttachmentDescriptor* framebufferAttachment
	        = desc.colorAttachments[0];

	framebufferAttachment.pixelFormat = self.colorPixelFormat;

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

	return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

	MTLRenderPassDescriptor* passDesc = self.currentRenderPassDescriptor;

	id<MTLRenderCommandEncoder> commandEncoder =
	        [commandBuffer renderCommandEncoderWithDescriptor:passDesc];
	[commandEncoder setRenderPipelineState:renderPipeline];

	[commandEncoder setVertexBuffer:vertexBuffer
	                         offset:0
	                        atIndex:0];

	float factor = 1;
	float padding = 100;
	struct Uniforms uniforms[QUAD_COUNT] = {
		{
		        .position = { 0, 0 },
		        .size = {
		                self.drawableSize.width,
		                self.drawableSize.height,
		        },
		        .color = { 0, 0, 0, 0.5 },
		        .isGlyph = false,
		},
		{
		        .position = {
		                padding,
		                (self.drawableSize.height - kGlyphHeight * factor) / 2,
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
		                (self.drawableSize.height - kGlyphHeight * factor) / 2,
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
		                (self.drawableSize.width - kGlyphWidth * factor) / 2,
		                (self.drawableSize.height - kGlyphHeight * factor) / 2,
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
		                self.drawableSize.width - kGlyphWidth * factor - padding,
		                (self.drawableSize.height - kGlyphHeight * factor) / 2,
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
	                        atIndex:1];

	vector_uint2 viewportSize = simd_make_uint2(
	        self.drawableSize.width, self.drawableSize.height);
	[commandEncoder setVertexBytes:&viewportSize
	                        length:sizeof(viewportSize)
	                       atIndex:2];

	float edrMax = self.window.screen.maximumExtendedDynamicRangeColorComponentValue;
	[commandEncoder setVertexBytes:&edrMax
	                        length:sizeof(edrMax)
	                       atIndex:3];

	[commandEncoder setFragmentTexture:texture
	                           atIndex:0];

	[commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
	                           indexCount:6
	                            indexType:MTLIndexTypeUInt16
	                          indexBuffer:indexBuffer
	                    indexBufferOffset:0
	                        instanceCount:QUAD_COUNT];

	[commandEncoder endEncoding];

	[commandBuffer presentDrawable:self.currentDrawable];
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

		NSMenuItem* quitMenuItem = [NSMenuItem alloc];
		[quitMenuItem initWithTitle:@"Quit metallll"
		                     action:@selector(terminate:)
		              keyEquivalent:@"q"];
		[appMenu addItem:quitMenuItem];

		NSRect rect = NSMakeRect(100, 100, 500, 400);

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
