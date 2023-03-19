#include <metal_common>

using namespace metal;

struct Vertex {
	float4 position;
};

struct Uniforms {
	float4 translation;
	float4 scale;
	float4 color;
};

struct VertexOut {
	float4 position [[position]];
	float4 color;
};

vertex VertexOut vertexShader(
        const device Vertex* vertexBuffer [[buffer(0)]],
        const device float* edrMax [[buffer(1)]],
        const device Uniforms* uniformsBuffer [[buffer(2)]],
        uint vid [[vertex_id]],
        uint iid [[instance_id]])
{
	Vertex v = vertexBuffer[vid];
	Uniforms u = uniformsBuffer[iid];
	return {
		.position = v.position * u.scale + u.translation,
		.color = clamp(u.color, float4(0), float4(*edrMax)),
	};
}

fragment float4 fragmentShader(VertexOut interpolated [[stage_in]])
{
	return interpolated.color;
}
