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
		uint vid [[vertex_id]])
{
	VertexOut out;
	out.position = vertexArray[vid].position;
	out.color = vertexArray[vid].color;
	return out;
}

fragment float4 fragmentShader(VertexOut interpolated [[stage_in]])
{
	return interpolated.color;
}
