#include <metal_common>
#include <metal_stdlib>

using namespace metal;

struct Uniforms {
	float2 position;
	float2 size;
	ushort2 glyphTopLeft;
	ushort2 glyphSize;
	float4 topColor;
	float4 bottomColor;
	bool isGlyph;
};

struct VertexOut {
	float4 position [[position]];
	float2 textureCoordinate;
	float4 color;
	bool isGlyph;
};

constant float2 quadPositions[4] = {
	float2(-1, -1),
	float2(-1, 1),
	float2(1, 1),
	float2(1, -1),
};

constant float2 quadTextureCoordinates[4] = {
	float2(0, 1),
	float2(0, 0),
	float2(1, 0),
	float2(1, 1),
};

vertex VertexOut vertexShader(
        const device Uniforms* uniformsBuffer [[buffer(0)]],
        const device uint2* viewportSizeInt [[buffer(1)]],
        const device ushort2* atlasSize [[buffer(2)]],
        const device float* edrMax [[buffer(3)]],
        uint vid [[vertex_id]],
        uint iid [[instance_id]])
{
	Uniforms u = uniformsBuffer[iid];
	float2 viewportSize = float2(*viewportSizeInt);

	float2 portionOfViewportCovered = u.size / viewportSize;

	// normalized space:  -1 .. 1,            zero is center,   y goes up
	//      pixel space:   0 .. viewportSize, zero is top left, y goes down

	float2 pixelSpaceFullScreenPosition
	        = (quadPositions[vid] * float2(1, -1) + 1) / 2 * viewportSize;

	float2 pixelSpacePosition
	        = pixelSpaceFullScreenPosition * portionOfViewportCovered + u.position;

	float2 normalizedSpacePosition
	        = (pixelSpacePosition / viewportSize * 2 - 1) * float2(1, -1);

	float2 textureCoordinate = quadTextureCoordinates[vid];
	textureCoordinate *= float2(u.glyphSize);
	textureCoordinate += float2(u.glyphTopLeft);
	textureCoordinate /= float2(*atlasSize);

	float4 color = normalizedSpacePosition.y == 1 ? u.topColor : u.bottomColor;

	return {
		.position = float4(normalizedSpacePosition, 0, 1),
		.textureCoordinate = textureCoordinate,
		.color = clamp(color, float4(0), float4(*edrMax, *edrMax, *edrMax, 1)),
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
