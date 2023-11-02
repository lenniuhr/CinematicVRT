Shader "Hidden/OctreeRendering"
{
    Properties
    {
        _Threshold("Threshold", Float) = 0.5
        _OctreeLevel("Octree Level", Float) = 7
    }
    SubShader
    {
        ZTest Off 
		ZWrite Off
        Cull Off

        Pass
        {
            Name "OctreeRendering"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment OctreeFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/OctreeRendering.hlsl"
            ENDHLSL
        }
    }
}