Shader "Hidden/RayTracing"
{
    Properties
    {
        _FrameID("Frame ID", Float) = 0
        _MaxBounces("Max Bounces", Float) = 5
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
            #include "Assets/Shaders/RayTracing.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "Copy"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment CopyFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/RayTracing.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "RayTracing"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment RayTracingFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/RayTracing.hlsl"
            ENDHLSL
        }
    }
}