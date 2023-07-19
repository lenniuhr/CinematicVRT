Shader "Hidden/GaussianBlur"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "white" {}
        _VolumeTex("Volume Texture", 3D) = "white" {}
        _VolumePosition("Volume Position", Vector) = (0, 0, 0)
        _VolumeScale("Volume Scale", Vector) = (0, 0, 0)
        _StepSize("Step Size", Float) = 0.004
    }
    SubShader
    {
        ZTest Off 
		ZWrite Off
        Cull Off

        Pass
        {
            Name "GaussianBlur"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment GaussianBlurFragment
            #include "Assets/Shaders/DefaultVertex.hlsl"
            #include "Assets/Shaders/GaussianBlur.hlsl"
            ENDHLSL
        }
    }
}