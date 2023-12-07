Shader "Hidden/ToneMapping"
{
    Properties
    {
        _ShoulderStrength("Shoulder Strength", Range(0, 1)) = 0.22
        _LinearStrength("Linear Strength", Range(0, 1)) = 0.3
        _LinearAngle("Linear Angle", Range(0, 1)) = 0.1
        _ToeStrength("Toe Strength", Range(0, 1)) = 0.2
        _ToeNumerator("Toe Numerator", Range(0, 1)) = 0.01
        _ToeDenominator("Toe Denominator", Range(0, 1)) = 0.3
        _LinearWhite("Linear White", Range(0, 100)) = 3
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
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/ToneMapping.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "Tone Mapping"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment ToneMappingFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/ToneMapping.hlsl"
            ENDHLSL
        }
    }
}