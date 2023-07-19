#ifndef GAUSSIAN_BLUR_INCLUDED
#define GAUSSIAN_BLUR_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/DefaultInput.hlsl"

TEXTURE2D(_MainTex);    SAMPLER(sampler_MainTex);
float4 _MainTex_TexelSize;

TEXTURE3D(_VolumeTex);  SAMPLER(sampler_VolumeTex);

float Gauss(float sigma, int x, int y)
{
    return exp(-(x * x + y * y) / (2 * sigma * sigma));
}

float3 GaussSimilarity(float sigmaR, float3 center, float3 value)
{
    return exp(-abs(center - value) / (2 * sigmaR * sigmaR));
}

float3 GaussianBlur(float2 uv)
{
    int kernelRadius = 2;
    float sigma = 1;
    float sigmaR = 0.5;
    
    float3 color = 0;
    float totalWeight = 0;
    
    for (int x = -kernelRadius; x <= kernelRadius; x++)
    {
        for (int y = -kernelRadius; y <= kernelRadius; y++)
        {
            // if inside boundarys
            
            float2 neighborUV = uv + _MainTex_TexelSize.xy * int2(x, y);
            float3 value = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, neighborUV).rgb;
            
            float weight = Gauss(sigma, x, y);
            
            color += weight * value;
            totalWeight += weight;
        }
    }

    return color / totalWeight;
}

float3 BilateralBlur(float2 uv)
{
    int kernelRadius = 2;
    float sigma = 1;
    float sigmaR = 0.5;
    
    float3 color = 0;
    float3 totalWeight = 0;
    
    float3 center = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;
    
    for (int x = -kernelRadius; x <= kernelRadius; x++)
    {
        for (int y = -kernelRadius; y <= kernelRadius; y++)
        {
            // if inside boundarys
            
            float2 neighborUV = uv + _MainTex_TexelSize.xy * int2(x, y);
            float3 value = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, neighborUV).rgb;
            
            float3 weight = Gauss(sigma, x, y) * GaussSimilarity(sigmaR, center, value);
            
            color += weight * value;
            totalWeight += weight;
        }
    }

    return color / totalWeight;
}

float4 GaussianBlurFragment(Varyings IN) : SV_TARGET
{
    //return SAMPLE_TEXTURE3D(_VolumeTex, sampler_VolumeTex, float3(IN.uv, 0.5));
    
    float offset = 1.0 / 512.0;
    
    half3 center = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb;
    half3 right = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv + offset).rgb;
    half3 left = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv - offset).rgb;
    
    half3 color = 1.0 / 4.0 * (right + left + 2 * center);
    
    color = GaussianBlur(IN.uv);
    
    return float4(center, 1);

}

#endif