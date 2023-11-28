#ifndef CINEMATIC_RENDERING_INCLUDED
#define CINEMATIC_RENDERING_INCLUDED

#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Random.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/Environment.hlsl"
#include "Assets/Shaders/Library/Classification.hlsl"
#include "Assets/Shaders/Library/Octree.hlsl"

TEXTURE2D(_CopyTex);    SAMPLER(sampler_point_clamp);
TEXTURE2D(_Result);    
TEXTURE2D(_PrevFrame);
TEXTURE2D(_CurrentFrame);

TEXTURE2D(_TransferTex);  SAMPLER(sampler_TransferTex);

TEXTURECUBE(_Skybox);       SAMPLER(sampler_Skybox);

TEXTURE2D(_1DTransferTex);  SAMPLER(sampler_1DTransferTex);


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
    //return InverseLerp(35, 45, density);
    return saturate(InverseLerp(0, 150, density));
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

float4 SampleColor(float density, float3 gradient)
{
    float density01 = InverseLerp(-1000.0, 2500.0, density);
    
    density01 += 0.12 * InverseLerp(0, 0.05, gradient);
    
    return SAMPLE_TEXTURE2D_LOD(_1DTransferTex, sampler_1DTransferTex, float2(density01, 0.05), 0);
}

HitInfo DeltaTrackOctree(float3 position, Ray ray, inout uint rngState)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float3 uv = GetVolumeCoords(position);
    
    // Initialize octree variables
    int octreeLevel = 5;
    int3 octreeId = GetOctreeId(octreeLevel, uv);
    
    float t = 0;
    float3 dirWS = mul(_VolumeLocalToWorldMatrix, ray.dirOS);
    float factor = 1 / length(dirWS);
    

    for (int i = 0; i < 500; i++)
    {
        float3 prevSamplePos = position + ray.dirOS * t;
        float3 prevUv = GetVolumeCoords(prevSamplePos);
        
        float octreeValue = GetOctreeValueById(octreeLevel, octreeId);
        float sigmaT = _SigmaT * DensityToSigma(octreeValue);
        sigmaT = max(sigmaT, 0.01);
        float step = -log(1.0 - RandomValue(rngState)) / sigmaT;
        
        // Step not further than current cell
        float3 newId;
        float3 newPos;
        float maxStep = RayOctreeT(octreeLevel, octreeId, prevSamplePos, ray.dirOS, newId, newPos);
        
        
        if (maxStep <= step) // Change octree cell
        {
            octreeId = newId;
            t += maxStep;
            
            if (IsInvalid(octreeLevel, octreeId))
            {
                return hitInfo;
            }
        }
        else
        {
            t += step;
            
            float3 samplePos = position + ray.dirOS * t;
        
            if (!InVolumeBoundsOS(samplePos))
            {
                return hitInfo;
            }
           
            float3 uv = GetVolumeCoords(samplePos);
            float density = SampleDensity(uv);
            float sigma = DensityToSigma(density);
            
            if (sigma / DensityToSigma(octreeValue) > RandomValue(rngState))
            {
                hitInfo.didHit = true;
                return hitInfo;
            }
        }
    }
    hitInfo.debug = true;
    return hitInfo;
}

HitInfo DeltaTraceHeterogenous(float3 position, Ray ray, inout uint rngState)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float t = 0;
    
    float3 dirWS = mul(_VolumeLocalToWorldMatrix, ray.dirOS);
    float factor = 1 / length(dirWS);
    
    for (int i = 0; i < 1000; i++)
    {
        float step = -log(1.0 - RandomValue(rngState)) / _SigmaT;
        
        t += step;
        
        float3 samplePos = position + ray.dirOS * t;
        
        if (!InVolumeBoundsOS(samplePos))
        {
            return hitInfo;
        }
           
        float3 uv = GetVolumeCoords(samplePos);
        float density = SampleDensity(uv);
        float sigma = DensityToSigma(density);
        
        if (sigma > RandomValue(rngState))
        {
            hitInfo.didHit = true;
            return hitInfo;
        }
    }
    hitInfo.debug = true;
    return hitInfo;
}

bool TestCollision2(inout uint rngState)
{
    float t = 0;
    bool crossedMiddle = false;
    
    for (int i = 0; i < 100; i++)
    {
        float sigmaT = (!crossedMiddle) ? 0.5 : 2;
        
        float step = -log(1.0 - RandomValue(rngState)) / sigmaT;

        t += step;
        
        if (!crossedMiddle && t > 0.5)
        {
            t = 0.5;
            crossedMiddle = true;
            continue;
        }
        
        if (t > 1)
        {
            return 0;
        }
        
        float density = (!crossedMiddle) ? 0.5 : 2;
        
        if (density / sigmaT > RandomValue(rngState))
        {
            return 1;
        }
    }
    return 0;
}

float3 TestCollision(inout uint rngState)
{
    float t = 0;
    float sigmaT = 2;
    
    for (int i = 0; i < 100; i++)
    {
        float step = -log(1.0 - RandomValue(rngState)) / sigmaT;

        t += step;
        
        if (t > 1)
        {
            return 0;
        }
        
        float density = (t < 0.5) ? 0.5 : 2;
        
        if (density / sigmaT > RandomValue(rngState))
        {
            return 1;
        }
    }
    return 0;
}

float3 Trace(float3 position, Ray ray, inout uint rngState)
{
    float3 color = 1;
    float3 incomingLight = 0;
    
    for (int i = 0; i <= 20; i++)
    {
        HitInfo hit = DeltaTrackOctree(position, ray, rngState);
        HitInfo hit2 = DeltaTraceHeterogenous(position, ray, rngState);
        
        if (hit.didHit && !hit2.didHit)
        {
            return 1;
        }
        if (!hit.didHit && hit2.didHit)
        {
            return 0;
        }
        return 0.5;
        
        if (hit.debug)
        {
            return float3(1, 0, 1);
        }
        
        if (hit.didHit)
        {
            return 1;
            
            float3 nextDir = SampleDirection(ray.dirOS, _Blend, rngState);
            
            position = hit.hitPointOS;
            ray.originOS = hit.hitPointOS;
            ray.dirOS = nextDir;
            ray.type = 1;
            color *= _Color; //hit.material.color;
        }
        else
        {
            return 0;
            
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