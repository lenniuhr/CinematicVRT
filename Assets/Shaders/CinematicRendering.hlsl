#ifndef CINEMATIC_RENDERING_INCLUDED
#define CINEMATIC_RENDERING_INCLUDED

#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Random.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/Octree.hlsl"

TEXTURE2D(_CopyTex);    SAMPLER(sampler_point_clamp);
TEXTURE2D(_ResultTex);    
TEXTURE2D(_PrevFrame);
TEXTURE2D(_CurrentFrame);

TEXTURE2D(_TransferTex);  SAMPLER(sampler_TransferTex);

TEXTURECUBE(_Skybox);       SAMPLER(sampler_Skybox);

float4 _Color;

int _FrameID;
float _Threshold;

int IncreaseOctreeLevel(int level, float3 uv)
{
    int newLevel = level;
    while (newLevel < OCTREE_DEPTH)
    {
        newLevel++;
        float value = GetOctreeValue(newLevel, uv);
        
        if (value <= _Threshold)
        {
            break;
        }
    }
    return newLevel;
}

float Halton(uint base, uint index)
{
    float result = 0;
    float digitWeight = 1;
    while (index > 0u)
    {
        digitWeight = digitWeight / float(base);
        uint nominator = index % base;
        result += float(nominator) * digitWeight;
        index = index / base;
    }
    return result;
}


HitInfo RayMarchVolumeCollision(float3 position, Ray ray)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float _StepSize = 0.001;
    
    [loop]
    for (int i = 0; i < 1000; i++)
    {
        if (!InVolumeBoundsOS(position))
        {
            // TODO ray goes out of volume
            return hitInfo;
        }
           
        float3 uv = GetVolumeCoords(position);
        float density = SampleDensity(uv);
        
        if (density > _Threshold)
        {
            float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
                
            float3 normalOS = normalize(gradient);
                
            hitInfo.didHit = true;
            hitInfo.hitPointOS = position - ray.dirOS * _StepSize;
            hitInfo.normalOS = normalOS;
            hitInfo.material.color = _Color;
                
            return hitInfo;
        }
        position += ray.dirOS * _StepSize;
    }
    return hitInfo;
}

HitInfo CalculateRayVolumeCollision(float3 position, Ray ray)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    int octreeLevel = 0;
    float octreeDim = OCTREE_DIM[octreeLevel];
    
    // Octree id
    int3 parentId;
    
    [loop]
    for (int i = 0; i < 300; i++)
    {
        if (!InVolumeBoundsOS(position))
        {
            // TODO ray goes out of volume
            return hitInfo;
        }
        
        float3 uv = GetVolumeCoords(position);
        float value = GetOctreeValue(octreeLevel, uv);
        
        if (value > _Threshold)
        {
            octreeLevel = IncreaseOctreeLevel(octreeLevel, uv);
            parentId = GetOctreeId(octreeLevel - 1, uv);
            
            value = GetOctreeValue(octreeLevel, uv);
                
            if (value > _Threshold)
            {
                for (int step = 0; step < 50; step++)
                {
                    float density = SampleDensity(uv);
                    if (density > _Threshold)
                    {
                        // Surface hit
                        float density = SampleDensity(uv);
                        float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
                
                        float2 transferUV = float2(density, length(gradient));
                        float4 color = SAMPLE_TEXTURE2D_LOD(_TransferTex, sampler_TransferTex, transferUV, 0);
                        
                
                        float3 normalWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, gradient));
                        float3 normalOS = normalize(gradient);
                
                        hitInfo.didHit = true;
                        hitInfo.hitPointOS = position + 0.01 * normalOS;
                        hitInfo.normalOS = normalOS;
                        hitInfo.material.color = _Color;
                
                        return hitInfo;
                    }
                    else
                    {
                        position += ray.dirOS * (1 / 512.0) * 0.5;
                    }
                }
            }
        }
        else
        {
            if (octreeLevel > 0)
            {
                int3 currentId = GetOctreeId(octreeLevel - 1, uv);
                if (currentId.x != parentId.x || currentId.y != parentId.y || currentId.z != parentId.z)
                {
                    float parentValue = GetOctreeValue(octreeLevel - 1, uv);
                    if (parentValue <= _Threshold)
                    {
                        octreeLevel--;
                    }
                }
            }
        }
                
        // Calculate step
        float3 hitPoint = RayOctreeBB(uv, octreeLevel, position, ray.dirOS);
        position = hitPoint;
    }
    return hitInfo;
}

float3 Trace(float3 position, Ray ray, inout uint rngState)
{
    float3 color = 1;
    float3 incomingLight = 0;
    
    for (int i = 0; i <= 5; i++)
    {
        HitInfo hit = RayMarchVolumeCollision(position, ray);
        if (hit.didHit)
        {
            ray.originOS = hit.hitPointOS;
            ray.dirOS = normalize(normalize(hit.normalOS) + RandomDirection(rngState));
            
            position = hit.hitPointOS + ray.dirOS * 0.0;
            
            //incomingLight += color * hit.material.emissionColor;
            
            color *= hit.material.color;
            
        }
        else
        {
            // TODO envmap
            float3 dirWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, ray.dirOS));
            float4 skyData = SAMPLE_TEXTURECUBE(_Skybox, sampler_Skybox, dirWS);
            
            incomingLight = color * skyData.rgb;
            
            break;
        }
    }
    return incomingLight;
}

float4 RaytraceFragment(Varyings IN) : SV_TARGET
{
    //float2 pixelOffset = float2(Halton(2, _FrameID) - 0.5, Halton(3, _FrameID) - 0.5);
    
    //return Rand3dTo1d(float3(IN.uv, _FrameID));
    
    // Create seed for random number generator
    uint2 numPixels = _ScreenParams.xy;
    uint2 pixelCoord = IN.uv * numPixels;
    uint pixelIndex = pixelCoord.y * numPixels.x + pixelCoord.x;
    uint rngState = pixelIndex + _FrameID * 719393;
    
    Ray ray = GetRay(IN.uv);
    
    float3 hitPoint;
    if (RayBoundingBoxOS(ray, hitPoint))
    {
        float3 color = Trace(hitPoint, ray, rngState);
        return float4(color, 1);
    }
    
    float4 skyData = SAMPLE_TEXTURECUBE(_Skybox, sampler_Skybox, ray.dirWS);
    return skyData;
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