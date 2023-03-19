#include <metal_common>

using namespace metal;

struct Vertex {
	float4 position;
	float4 color;
};

struct VertexOut {
	float4 position [[position]];
	float4 color;
};

vertex VertexOut vertexShader(
        const device Vertex* vertexArray [[buffer(0)]],
        const device float* edrMax [[buffer(1)]],
        const device float4* translation [[buffer(2)]],
        const device float4* scale [[buffer(3)]],
        uint vid [[vertex_id]])
{
	return {
		.position = vertexArray[vid].position * *scale + *translation,
		.color = clamp(vertexArray[vid].color, float4(0), float4(*edrMax)),
	};
}

fragment float4 fragmentShader(VertexOut interpolated [[stage_in]])
{
	return interpolated.color;
}
