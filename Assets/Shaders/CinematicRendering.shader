Shader "Hidden/CinematicRendering"
{
    Properties
    {
        _StepSize("Step Size", Float) = 0.004
        _NormalOffset("Normal Offset", Float) = 1
        _Threshold("Threshold", Float) = 0.5
    }
    SubShader
    {
        ZTest Off 
		ZWrite Off
        Cull Off

        Pass
        {
            Name "Ray Tracing"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment RaytraceFragment
            #include "Assets/Shaders/DefaultVertex.hlsl"
            #include "Assets/Shaders/VolumeRendering.hlsl"
            ENDHLSL
        }
    }
}