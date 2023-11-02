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
            Name "Accumulate"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment AccumulateFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/CinematicRendering.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "Copy"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment CopyFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/CinematicRendering.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "Ray Tracing"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment RaytraceFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/CinematicRendering.hlsl"
            ENDHLSL
        }
    }
}