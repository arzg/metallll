#include <metal_common>

using namespace metal;

struct Vertex {
	float4 position;
};

struct Uniforms {
	float2 position;
	float2 size;
	float4 color;
};

struct VertexOut {
	float4 position [[position]];
	float4 color;
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
	        = (v.position.xy * float2(1, -1) + 1) / 2 * viewportSize;

	float2 pixelSpacePosition
	        = pixelSpaceFullScreenPosition * portionOfViewportCovered + u.position;

	float2 normalizedSpacePosition
	        = (pixelSpacePosition / viewportSize * 2 - 1) * float2(1, -1);

	return {
		.position = float4(normalizedSpacePosition.xy, 0, 1),
		.color = clamp(u.color, float4(0), float4(*edrMax)),
	};
}

fragment float4 fragmentShader(VertexOut interpolated [[stage_in]])
{
	return interpolated.color;
}
