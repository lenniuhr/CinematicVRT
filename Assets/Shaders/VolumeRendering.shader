Shader "Hidden/VolumeRendering"
{
    Properties
    {
        _StepSize("Step Size", Float) = 0.001
        _Threshold("Threshold", Float) = 0.04
        _Color("Color", Color) = (1,1,1,1)
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
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/VolumeRendering.hlsl"
            ENDHLSL
        }
    }
}