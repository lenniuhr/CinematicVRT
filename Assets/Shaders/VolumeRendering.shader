Shader "Hidden/VolumeRendering"
{
    Properties
    {

    }
    SubShader
    {
        ZTest Off 
		ZWrite Off
        Cull Off

        Pass
        {
            Name "VolumeRendering"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment VolumeRenderingFragment
            #include "Assets/Shaders/DefaultVertex.hlsl"
            #include "Assets/Shaders/VolumeRendering.hlsl"
            ENDHLSL
        }
    }
}