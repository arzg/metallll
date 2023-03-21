#include <metal_common>
#include <metal_stdlib>

using namespace metal;

struct Vertex {
	float2 position;
	float2 textureCoordinate;
};

struct Uniforms {
	float2 position;
	float2 size;
	float4 color;
	bool isGlyph;
};

struct VertexOut {
	float4 position [[position]];
	float2 textureCoordinate;
	float4 color;
	bool isGlyph;
};

vertex VertexOut vertexShader(
        const device Vertex* vertexBuffer [[buffer(0)]],
        const device Uniforms* uniformsBuffer [[buffer(1)]],
        const device uint2* viewportSizePtr [[buffer(2)]],
        const device float* edrMax [[buffer(3)]],
        uint vid [[vertex_id]],
        uint iid [[instance_id]])
{
	Vertex v = vertexBuffer[vid];
	Uniforms u = uniformsBuffer[iid];
	float2 viewportSize = float2(*viewportSizePtr);

	float2 portionOfViewportCovered = u.size / viewportSize;

	// normalized space:  -1 .. 1,            zero is center,   y goes up
	//      pixel space:   0 .. viewportSize, zero is top left, y goes down

	float2 pixelSpaceFullScreenPosition
	        = (v.position * float2(1, -1) + 1) / 2 * viewportSize;

	float2 pixelSpacePosition
	        = pixelSpaceFullScreenPosition * portionOfViewportCovered + u.position;

	float2 normalizedSpacePosition
	        = (pixelSpacePosition / viewportSize * 2 - 1) * float2(1, -1);

	return {
		.position = float4(normalizedSpacePosition, 0, 1),
		.textureCoordinate = v.textureCoordinate,
		.color = clamp(u.color, float4(0), float4(*edrMax, *edrMax, *edrMax, 1)),
		.isGlyph = u.isGlyph,
	};
}

fragment float4 fragmentShader(VertexOut interpolated [[stage_in]],
        texture2d<float> texture [[texture(0)]])
{
	constexpr sampler textureSampler(mag_filter::nearest, min_filter::nearest);
	float4 out = interpolated.color;
	if (interpolated.isGlyph) {
		float glyphCoverage
		        = texture.sample(textureSampler, interpolated.textureCoordinate).a;
		out.a *= glyphCoverage;
	}
	out.rgb *= out.a;
	return out;
}
