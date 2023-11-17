#ifndef BLUR_IMAGE_INCLUDED
#define BLUR_IMAGE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/Library/DefaultInput.hlsl"

TEXTURE2D(_MainTex);    SAMPLER(sampler_point_repeat);
float4 _MainTex_TexelSize;
int _KernelRadius;
float _Sigma;
float _SigmaR;

TEXTURE3D(_VolumeTex);  SAMPLER(sampler_VolumeTex);

float Gauss(int x, int y)
{
    return exp(-(x * x + y * y) / (2 * _Sigma * _Sigma));
}

float3 GaussSimilarity(float3 center, float3 value)
{
    return exp(-abs(center - value) / (2 * _SigmaR * _SigmaR));
}

float3 GaussianBlur(float2 uv)
{
    float3 color = 0;
    float totalWeight = 0;
    
    for (int x = -_KernelRadius; x <= _KernelRadius; x++)
    {
        for (int y = -_KernelRadius; y <= _KernelRadius; y++)
        {
            float2 nUV = uv + _MainTex_TexelSize.xy * int2(x, y);
            
            if (nUV.y > 0 && nUV.y < 1)
            {
                float3 value = SAMPLE_TEXTURE2D(_MainTex, sampler_point_repeat, nUV).rgb;
            
                float weight = Gauss(x, y);
            
                color += weight * value;
                totalWeight += weight;
            }
        }
    }

    return color / totalWeight;
}

float3 BilateralBlur(float2 uv)
{
    float3 color = 0;
    float3 totalWeight = 0;
    
    float3 center = SAMPLE_TEXTURE2D(_MainTex, sampler_point_repeat, uv).rgb;
    
    for (int x = -_KernelRadius; x <= _KernelRadius; x++)
    {
        for (int y = -_KernelRadius; y <= _KernelRadius; y++)
        {
            float2 nUV = uv + _MainTex_TexelSize.xy * int2(x, y);
            
            if (nUV.x > 0 && nUV.y > 0 && nUV.x < 1 && nUV.y < 1)
            {
                float3 value = SAMPLE_TEXTURE2D(_MainTex, sampler_point_repeat, nUV).rgb;
            
                float3 weight = Gauss(x, y) * GaussSimilarity(center, value);
            
                color += weight * value;
                totalWeight += weight;
            }
        }
    }

    return color / totalWeight;
}

float4 GaussianBlurFragment(Varyings IN) : SV_TARGET
{
    float3 color = GaussianBlur(IN.uv);
    return float4(color, 1);
}

float4 BilateralBlurFragment(Varyings IN) : SV_TARGET
{
    float3 color = BilateralBlur(IN.uv);
    return float4(color, 1);
}

#endif