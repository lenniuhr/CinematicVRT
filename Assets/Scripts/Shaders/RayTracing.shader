Shader "Hidden/RayTracing"
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
            Name "Copy"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment CopyFragment
            #include "Assets/Scripts/Shaders/DefaultVertex.hlsl"
            #include "Assets/Scripts/Shaders/RayTracing.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "RayTracing"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment RayTracingFragment
            #include "Assets/Scripts/Shaders/DefaultVertex.hlsl"
            #include "Assets/Scripts/Shaders/RayTracing.hlsl"
            ENDHLSL
        }
    }
}