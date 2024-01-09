#ifndef CINEMATIC_RENDERING_INCLUDED
#define CINEMATIC_RENDERING_INCLUDED

#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Random.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/RayUtils.hlsl"
#include "Assets/Shaders/Library/Environment.hlsl"
#include "Assets/Shaders/Library/Classification.hlsl"
#include "Assets/Shaders/Library/Octree.hlsl"
#include "Assets/Shaders/Library/PBR.hlsl"
#include "Assets/Shaders/Library/TransferFunction.hlsl"
#include "Assets/Shaders/Library/PhaseFunction.hlsl"

TEXTURE2D(_CopyTex);
TEXTURE2D(_Result);    
TEXTURE2D(_PrevFrame);
TEXTURE2D(_CurrentFrame);
float4 _CurrentFrame_TexelSize;

TEXTURE2D(_TransferTex);  SAMPLER(sampler_TransferTex);

TEXTURECUBE(_Skybox);       SAMPLER(sampler_Skybox);

TEXTURE2D(_1DTransferTex);  SAMPLER(sampler_1DTransferTex);

float4 _Color;
int _FrameID;
float _Threshold;

float _SD;
float _Blend;
float _IncreaseThreshold;
float _DivergeStrength;

HitInfo DeltaTraceHomogenous(float3 position, Ray ray, inout uint rngState)
{
    HitInfo hitInfo = (HitInfo) 0;

    float3 dirWS = mul(_VolumeLocalToWorldMatrix, ray.dirOS);
    float factor = 1 / length(dirWS);
        
    float dist = -log(1.0 - RandomValue(rngState)) / _SigmaT;
    float t = dist * factor;
    
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

float4 SampleColor(float density, float3 gradient)
{
    float density01 = InverseLerp(-1000.0, 2000.0, density);
    
    //density01 += 0.12 * InverseLerp(0, 0.05, length(gradient));
    
    return SAMPLE_TEXTURE2D_LOD(_1DTransferTex, sampler_1DTransferTex, float2(density01, 0.05), 0);
}

void IncreaseOctreeLevel(inout int level, inout int3 octreeId, float3 uv, int maxLevel = 7)
{
    while (level < maxLevel)
    {
        float octreeValue = GetOctreeValueById(level, octreeId);
        float sigmaTCell = DensityToSigma(octreeValue);
        
        float meanFreePath = 1.0 / sigmaTCell;
        float cellSize = GetCellSize(level);
            
        if (meanFreePath < cellSize * _IncreaseThreshold)
        {
            octreeId = GetChildOctreeId(level, octreeId, uv);
            level++;
        }
        else
        {
            return;
        }
    }
}

HitInfo DeltaTrackOctree(float3 position, Ray ray, inout uint rngState)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float3 uv = GetVolumeCoords(position);
    
    // Initialize octree variables
    int octreeLevel = 0;
    int3 octreeId = GetOctreeId(octreeLevel, uv);
    
    float t = 0;
    float3 dirWS = mul(_VolumeLocalToWorldMatrix, ray.dirOS);
    float factor = 1 / length(dirWS);

    for (int i = 0; i < 300; i++)
    {
        float3 prevSamplePos = position + ray.dirOS * t;
        float3 prevUv = GetVolumeCoords(prevSamplePos);
        
        float octreeValue = GetOctreeValueById(octreeLevel, octreeId);
        float sigmaTCell = DensityToSigma(octreeValue);
        sigmaTCell = max(sigmaTCell, 0.001);
        
        float meanFreePath = 1.0 / sigmaTCell;
        float cellSize = GetCellSize(octreeLevel);
        
        if (octreeLevel < 7 && meanFreePath < cellSize * _IncreaseThreshold)
        {
            octreeId = GetChildOctreeId(octreeLevel, octreeId, prevUv);
            octreeLevel++;
        }
        else if (octreeLevel > 0) // If octree level > 0 and level not increased
        {
            float parentCellSize = GetCellSize(octreeLevel - 1);
            int3 parentId = floor(octreeId / 2);
            
            float parentValue = GetOctreeValueById(octreeLevel - 1, parentId);
            float parentCellSigmaT = DensityToSigma(parentValue);
            parentCellSigmaT = max(parentCellSigmaT, 0.001);
            
            float parentMeanFreePath = 1.0 / parentCellSigmaT;
            if (parentMeanFreePath > parentCellSize * _IncreaseThreshold)
            {
                octreeId = parentId;
                octreeLevel--;
                sigmaTCell = parentCellSigmaT;
            }
        }
        
        float dist = -log(1.0 - RandomValue(rngState)) / sigmaTCell;
        float step = dist * factor;
        
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
                hitInfo.material.color = i / 300.0;
                return hitInfo;
            }
        }
        else
        {
            t += step;
            
            float3 samplePos = position + ray.dirOS * t;
        
            if (!InVolumeBoundsOS(samplePos))
            {
                hitInfo.material.color = i / 300.0;
                return hitInfo;
            }
           
            float3 uv = GetVolumeCoords(samplePos);
            float density = SampleDensity(uv);
            float sigma = DensityToSigma(density);
            
            float value01 = sigma / sigmaTCell;
            
            if (value01 > RandomValue(rngState))
            {
                float3 gradient;
                float3 normal;
                SampleGradientAndNormal(uv, gradient, normal);
                
                hitInfo.didHit = true;
                hitInfo.hitPointOS = samplePos;
                hitInfo.normalOS = normal;
                hitInfo.gradient = gradient;
                hitInfo.material = SampleMaterial(density, gradient);
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
        float dist = -log(1.0 - RandomValue(rngState)) / _SigmaT;
        float step = dist * factor;
        
        t += step;
        
        float3 samplePos = position + ray.dirOS * t;
        
        if (!InVolumeBoundsOS(samplePos))
        {
            hitInfo.material.color = 1;
            return hitInfo;
        }
           
        float3 uv = GetVolumeCoords(samplePos);
        float density = SampleDensity(uv);
        float sigma = DensityToSigma(density);
        
        float value01 = sigma / _SigmaT;
        
        if (value01 > RandomValue(rngState))
        {
            float3 gradient;
            float3 normal;
            SampleGradientAndNormal(uv, gradient, normal);
            
            hitInfo.didHit = true;
            hitInfo.hitPointOS = samplePos;
            hitInfo.normalOS = normal;
            hitInfo.gradient = gradient;
            hitInfo.material.color = i / 1000.0;
            return hitInfo;
        }
    }
    hitInfo.debug = true;
    return hitInfo;
}

float3 SampleDiffuseImportance(in float3 V, in float3 N, in float3 baseColor, inout uint rngState, out float3 nextFactor)
{
    float theta = asin(sqrt(RandomValue(rngState)));
    float phi = 2.0 * PI * RandomValue(rngState);
    
    float3 localDiffuseDir = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
    float3 diffuseDir = normalize(mul(getNormalSpace(N), localDiffuseDir));
    
    nextFactor = baseColor;

    return normalize(diffuseDir);
}

float3 SampleDiffuseBruteForceRiemann(in float3 V, in float3 N, in float3 baseColor, inout uint rngState, out float3 nextFactor)
{
    float theta = 0.5 * PI * RandomValue(rngState);
    float phi = 2.0 * PI * RandomValue(rngState);
    
    float3 localDiffuseDir = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
    float3 diffuseDir = mul(getNormalSpace(N), localDiffuseDir);
    
    nextFactor = baseColor * PI * cos(theta) * sin(theta);

    return normalize(diffuseDir);
}
float3 SampleDiffuseBruteForceEqual(in float3 V, in float3 N, in float3 baseColor, inout uint rngState, out float3 nextFactor)
{
    float theta = acos(1.0 - RandomValue(rngState));
    float phi = 2.0 * PI * RandomValue(rngState);
    
    float3 localDiffuseDir = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
    float3 diffuseDir = mul(getNormalSpace(N), localDiffuseDir);
    
    nextFactor = baseColor * cos(theta);

    return normalize(diffuseDir);
}

float3 SampleDiffuseBruteForce(in float3 V, in float3 N, in float3 baseColor, inout uint rngState, out float3 nextFactor)
{
    
    float3 nextDir = RandomHemisphereDirection(N, rngState);
    
    float cosTheta = dot(N, nextDir);
    
    float brdf = cosTheta / PI;
    
    nextFactor = baseColor * brdf * 2 * PI;

    return nextDir;
}

float3 Trace(float3 position, Ray ray, inout uint rngState)
{
    float3 throughput = 1;
    float3 incomingLight = 0;
    
    for (int i = 0; i < 7; i++)
    {
        HitInfo hit = DeltaTrackOctree(position, ray, rngState);
        //HitInfo hit = DeltaTraceHeterogenous(position, ray, rngState);
        
        if (hit.debug)
        {
            //return float3(1, 0, 1);
        }
        
        if (hit.didHit)
        {
            // Calculate surface/volume probability
            float3 uv = GetVolumeCoords(hit.hitPointOS);
            float density = SampleDensity(uv);
            float sigma = DensityToSigma(density);
            float a = sigma / _SigmaT;
            
            float pBRDF = a * (1 - exp(-_SD * length(hit.gradient)));
            
            //pBRDF = _SD / 20;//
            //pBRDF = 1;
            
            //return saturate(hit.normalOS);
            
            if (pBRDF > RandomValue(rngState))
            {
                if (dot(-ray.dirOS, hit.normalOS) < 0)
                {
                    continue;
                }
                    
                // Surface scattering
                float3 r = float3(RandomValue(rngState), RandomValue(rngState), RandomValue(rngState));
                
                float3 nextFactor;
                float3 nextDir;
                if (RandomValue(rngState) > 2.0 / 3.0)
                {
                    nextDir = SampleSpecularMicrofacetBRDF(normalize(-ray.dirOS), normalize(hit.normalOS), hit.material.color, 0.0, 1.0, hit.material.roughness, r, nextFactor);
                    ray.type = 2;
                    nextFactor *= 3;
                }
                else
                {
                    nextDir = SampleDiffuseMicrofacetBRDF(normalize(-ray.dirOS), normalize(hit.normalOS), hit.material.color, 0.0, 1.0, hit.material.roughness, r, nextFactor);
                    ray.type = 1;
                    nextFactor *= 1.5;

                }
                position = hit.hitPointOS;
                ray.originOS = hit.hitPointOS;
                ray.dirOS = nextDir;
                throughput *= nextFactor;
            }
            else
            {
                // Volumetric scattering
                float3 nextDir = SamplePhaseFunctionHG(ray.dirOS, _Blend, rngState);
            
                position = hit.hitPointOS;
                ray.originOS = hit.hitPointOS;
                ray.dirOS = nextDir;
                ray.type = 1;
                throughput *= pow(hit.material.color, 0.5);
            }
        }
        else
        {
            float3 dirWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, ray.dirOS));
            float4 skyData = SampleEnvironment(dirWS, ray.type);
            
            incomingLight = throughput * skyData.rgb;
        }
    }
    
    return incomingLight;
}

float4 DeltaTrackingFragment(Varyings IN) : SV_TARGET
{
    float2 pixelOffset = float2(Halton(2, _FrameID) - 0.5, Halton(3, _FrameID) - 0.5) / _ScreenParams.xy;
    
    // Create seed for random number generator
    uint2 numPixels = _ScreenParams.xy;
    uint2 pixelCoord = IN.uv * numPixels;
    uint pixelIndex = pixelCoord.y * numPixels.x + pixelCoord.x;
    uint rngState = pixelIndex + _FrameID * 719393;
    //uint rngState = _FrameID * 719393;
    
    float2 jitter = RandomPointInCircle(rngState) * _DivergeStrength;
    Ray ray = GetRay(IN.uv, _VolumeWorldToLocalMatrix, pixelOffset, jitter);
    
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
    
    float4 accumulatedColor = prevColor * (1.0 - weight) + color * weight;
    
    return accumulatedColor;
}

#endif