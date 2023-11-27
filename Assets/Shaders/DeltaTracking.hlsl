#ifndef CINEMATIC_RENDERING_INCLUDED
#define CINEMATIC_RENDERING_INCLUDED

#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Random.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/Environment.hlsl"
#include "Assets/Shaders/Library/Classification.hlsl"

TEXTURE2D(_CopyTex);    SAMPLER(sampler_point_clamp);
TEXTURE2D(_Result);    
TEXTURE2D(_PrevFrame);
TEXTURE2D(_CurrentFrame);

TEXTURE2D(_TransferTex);  SAMPLER(sampler_TransferTex);

TEXTURECUBE(_Skybox);       SAMPLER(sampler_Skybox);


float4 _Color;
int _FrameID;
float _Threshold;

float _SigmaT;

float _Blend;

HitInfo DeltaTraceHomogenous(float3 position, Ray ray, inout uint rngState)
{
    HitInfo hitInfo = (HitInfo) 0;

    float3 dirWS = mul(_VolumeLocalToWorldMatrix, ray.dirOS);
    float factor = 1 / length(dirWS);
        
    float dist = -log(1.0 - RandomValue(rngState)) / _SigmaT;
    float t = dist * factor;
    
    //position += mul(_VolumeWorldToLocalMatrix, normalize(ray.dirWS) * dist);
    
    position += ray.dirOS * t;
    
    if (InVolumeBoundsOS(position))
    {
        float pdf = _SigmaT * exp(-_SigmaT * t);
        
        hitInfo.didHit = true;
        hitInfo.material.color = pdf;
        return hitInfo;
    }
    
    return hitInfo;
}

float DensityToSigma(float density)
{
    return InverseLerp(130, 131, density);
}

void CoordinateSystem(float3 v1, out float3 v2, out float3 v3)
{
    if (abs(v1.x) > abs(v1.y))
    {
        v2 = float3(-v1.z, 0, v1.x) / sqrt(v1.x * v1.x + v1.z * v1.z);
    }
    else
    {
        v2 = float3(0, v1.z, -v1.y) / sqrt(v1.y * v1.y + v1.z * v1.z);
    }
    v3 = cross(v1, v2);
}

float3 SphericalDirection(float sinTheta, float cosTheta, float phi, float3 x, float3 y, float3 z)
{
    return sinTheta * cos(phi) * x + sinTheta * sin(phi) * y + cosTheta * z;
}

float3 SampleDirection(float3 direction, float g, inout uint rngState)
{
    float cosTheta;
    if (abs(g) < 1e-3)
    {
        cosTheta = 1.0 - 2.0 * RandomValue(rngState);
    }
    else
    {
        float sqrTerm = (1.0 - g * g) / (1.0 - g + 2.0 * g * RandomValue(rngState));
        cosTheta = (1.0 + g * g - sqrTerm * sqrTerm) / (2.0 * g);
    }
    
    float sinTheta = sqrt(max(0.0, 1.0 - cosTheta * cosTheta));
    float phi = 2.0 * PI * RandomValue(rngState);
    
    
    float3 v1, v2;
    CoordinateSystem(direction, v1, v2);
    
    return SphericalDirection(sinTheta, cosTheta, phi, v1, v2, direction);
}

HitInfo DeltaTraceHeterogenous(float3 position, Ray ray, inout uint rngState)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float invMaxDensity = 1.0 / 255.0;
    float t = 0;
    
    //position += ray.dirOS * 0.001;
    
    float3 dirWS = mul(_VolumeLocalToWorldMatrix, ray.dirOS);
    float factor = 1 / length(dirWS);
    
    for (int i = 0; i < 100; i++)
    {
        t -= log(1.0 - RandomValue(rngState)) / _SigmaT;
        
        float3 samplePos = position + ray.dirOS * t * factor;
        
        if (!InVolumeBoundsOS(samplePos))
        {
            return hitInfo;
        }
           
        float3 uv = GetVolumeCoords(samplePos);
        float density = SampleDensity(uv);
        
        float sigma = DensityToSigma(density);
        
        if (sigma > RandomValue(rngState))
        {
            float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
            float3 normalOS = normalize(gradient);
            
            hitInfo.didHit = true;
            hitInfo.hitPointOS = samplePos;
            hitInfo.material.color = GetClassColorFromDensity(density, gradient);
            return hitInfo;
        }
    }
    return hitInfo;
}

float3 Trace(float3 position, Ray ray, inout uint rngState)
{
    float3 color = 1;
    float3 incomingLight = 0;
    
    for (int i = 0; i <= 20; i++)
    {
        HitInfo hit = DeltaTraceHeterogenous(position, ray, rngState);
        if (hit.didHit)
        {
            
            float3 nextDir = SampleDirection(ray.dirOS, _Blend, rngState);
            
            //return nextDir;
            
            position = hit.hitPointOS;
            ray.originOS = hit.hitPointOS;
            ray.dirOS = nextDir;
            ray.type = 1;
            color *= hit.material.color;
        }
        else
        {
            float3 dirWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, ray.dirOS));
            
            float4 skyData = SampleEnvironment(dirWS, ray.type);
            
            incomingLight = color * skyData.rgb;
            
            break;
        }
    }
    
    return incomingLight;
}

int _TestInt;

float4 DeltaTrackingFragment(Varyings IN) : SV_TARGET
{
    float2 pixelOffset = float2(Halton(2, _FrameID) - 0.5, Halton(3, _FrameID) - 0.5) / _ScreenParams.xy;
    
    // Create seed for random number generator
    uint2 numPixels = _ScreenParams.xy;
    uint2 pixelCoord = IN.uv * numPixels;
    uint pixelIndex = pixelCoord.y * numPixels.x + pixelCoord.x;
    uint rngState = pixelIndex + _FrameID * 719393;
    
    Ray ray = GetRay(IN.uv, pixelOffset);
    
    float3 hitPoint;
    if (RayBoundingBoxOS(ray, hitPoint))
    {
        float3 color = Trace(hitPoint, ray, rngState);
        
        return float4(color, 1);
    }
    return SampleEnvironment(ray.dirWS, 0);
}

float4 CopyFragment(Varyings IN) : SV_TARGET
{
    return SAMPLE_TEXTURE2D(_CopyTex, sampler_point_clamp, IN.uv);
}

float4 AccumulateFragment(Varyings IN) : SV_Target
{
    float4 color = SAMPLE_TEXTURE2D(_CurrentFrame, sampler_point_clamp, IN.uv);
    float4 prevColor = SAMPLE_TEXTURE2D(_PrevFrame, sampler_point_clamp, IN.uv);
    
    float weight = 1.0 / (_FrameID + 1.0);
    
    //weight = _Blend;
    
    float4 accumulatedColor = prevColor * (1.0 - weight) + color * weight;
    
    return accumulatedColor;
}

#endif