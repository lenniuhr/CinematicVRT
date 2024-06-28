Shader "Hidden/CinematicRendering"
{
    Properties
    {
        _SD("SD", Float) = 20
        _Blend("Blend", Float) = 0.1
        _IncreaseThreshold("Increase Threshold", Float) = 0.5
        _DivergeStrength("Diverge Strength", Float) = 0
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
            Name "Delta Tracking"

            HLSLPROGRAM
            #pragma multi_compile _ TRICUBIC_SAMPLING
            #pragma multi_compile _ CUTTING_PLANE
            #pragma vertex DefaultVertex
            #pragma fragment DeltaTrackingFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/CinematicRendering.hlsl"
            ENDHLSL
        }
    }
}