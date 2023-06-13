#ifndef DEFAULT_VERTEX_INCLUDED
#define DEFAULT_VERTEX_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Scripts/Shaders/DefaultInput.hlsl"

Varyings DefaultVertex(uint vertexID : SV_VertexID) {
	Varyings OUT;
	OUT.positionHCS = float4(
		vertexID <= 1 ? -1.0 : 3.0,
		vertexID == 1 ? 3.0 : -1.0,
		0.0, 1.0
	);
	OUT.uv = float2(
		vertexID <= 1 ? 0.0 : 2.0,
		vertexID == 1 ? 2.0 : 0.0
	);
	if (_ProjectionParams.x < 0.0) { // flipped projection matrix
		OUT.positionHCS.y *= -1;
	}
	return OUT;
}

#endif