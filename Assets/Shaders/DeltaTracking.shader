Shader "Hidden/DeltaTracking"
{
    Properties
    {
        _StepSize("Step Size", Float) = 0.004
        _NormalOffset("Normal Offset", Float) = 1
        _Threshold("Threshold", Float) = 0.5
        _SigmaT("Sigma T", Float) = 1
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
            #include "Assets/Shaders/DeltaTracking.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "Copy"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment CopyFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/DeltaTracking.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "Delta Tracking"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment DeltaTrackingFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/DeltaTracking.hlsl"
            ENDHLSL
        }
    }
}