#ifndef CINEMATIC_RENDERING_INCLUDED
#define CINEMATIC_RENDERING_INCLUDED

#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Random.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/RayUtils.hlsl"
#include "Assets/Shaders/Library/Environment.hlsl"
#include "Assets/Shaders/Library/Octree.hlsl"
#include "Assets/Shaders/Library/PBR.hlsl"
#include "Assets/Shaders/Library/TransferFunction.hlsl"
#include "Assets/Shaders/Library/PhaseFunction.hlsl"

#define MAX_BOUNCES 5

TEXTURE2D(_CopyTex);  
TEXTURE2D(_PrevFrame);
TEXTURE2D(_CurrentFrame);
float4 _CurrentFrame_TexelSize;

int _FrameID;

float _SD;
float _GPhaseFunction;
float _IncreaseThreshold;
float _DivergeStrength;
float _PTerminate;

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
        float3 prevUV = GetVolumeCoords(prevSamplePos);
        
        float octreeValue = GetOctreeValueById(octreeLevel, octreeId);
        float sigmaTCell = DensityToSigma(octreeValue);
        
        float meanFreePath = 1.0 / sigmaTCell;
        float cellSize = GetCellSize(octreeLevel);
        
        if (octreeLevel < 7 && meanFreePath < cellSize * _IncreaseThreshold)
        {
            octreeId = GetChildOctreeId(octreeLevel, octreeId, prevUV);
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

float3 Trace(float3 position, Ray ray, inout uint rngState)
{
    float3 throughput = 1;
    float3 incomingLight = 0;
    
    for (int i = 0; i < MAX_BOUNCES; i++)
    {
        HitInfo hit = DeltaTrackOctree(position, ray, rngState);
        
        if (hit.didHit)
        {
            // Calculate surface/volume scattering probability
            float3 uv = GetVolumeCoords(hit.hitPointOS);
            float density = SampleDensity(uv);
            float sigma = DensityToSigma(density);
            float a = sigma / _SigmaS;
            
            float pBRDF = a * (1 - exp(-_SD * length(hit.gradient)));
            float2 random = float2(RandomValue(rngState), RandomValue(rngState));
            
            if (pBRDF > RandomValue(rngState)) // Surface scattering
            {
                if (dot(ray.dirOS, hit.normalOS) > 0)
                {
                    position = hit.hitPointOS;
                    continue;
                }
                
                float3 nextFactor;
                float3 nextDir;
                if (RandomValue(rngState) < 2.0 / 3.0) // 2/3 - 1/3 diffuse-specular-split delivered good results
                {
                    
                    nextDir = SampleDiffuseMicrofacetBRDF(normalize(-ray.dirOS), normalize(hit.normalOS), hit.material, random, nextFactor);
                    ray.type = 1;
                    nextFactor *= 3.0 / 2.0;
                }
                else
                {
                    nextDir = SampleSpecularMicrofacetBRDF(normalize(-ray.dirOS), normalize(hit.normalOS), hit.material, random, nextFactor);
                    ray.type = 2;
                    nextFactor *= 3.0;
                }
                position = hit.hitPointOS;
                ray.originOS = hit.hitPointOS;
                ray.dirOS = normalize(nextDir);
                throughput *= nextFactor;
            }
            else // Volumetric scattering
            {
                float3 nextDir = SamplePhaseFunctionHG(ray.dirOS, _GPhaseFunction, random);
                float3 H = normalize(-ray.dirOS + nextDir);
                
                position = hit.hitPointOS;
                ray.originOS = hit.hitPointOS;
                ray.dirOS = normalize(nextDir);
                ray.type = 1;
                throughput *= pow(hit.material.color, 0.5); // pow for better look (reduce color loss)
            }
                
            // Russian roulette
            if (i > 3)
            {
                float pExtinct = saturate(1.0 - max(max(throughput.r, throughput.g), throughput.b));
                
                if (RandomValue(rngState) < pExtinct)
                {
                    return 0;
                }
                else
                {
                    throughput /= (1.0 - pExtinct);
                }
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