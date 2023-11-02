Shader "Hidden/BlurImage"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "white" {}
    }
    SubShader
    {
        ZTest Off 
		ZWrite Off
        Cull Off

        Pass
        {
            Name "BilateralBlur"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment BilateralBlurFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/ImageProcessing/BlurImage.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "GaussianBlur"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment GaussianBlurFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/ImageProcessing/BlurImage.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "BilateralBlur3D"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment BilateralBlur3DFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/ImageProcessing/Blur3D.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "GaussianBlur3D"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment GaussianBlur3DFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/ImageProcessing/Blur3D.hlsl"
            ENDHLSL
        }
    }
}