#ifndef CINEMATIC_RENDERING_INCLUDED
#define CINEMATIC_RENDERING_INCLUDED

#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Random.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/Octree.hlsl"
#include "Assets/Shaders/Library/Classification.hlsl"
#include "Assets/Shaders/Library/Environment.hlsl"
#include "Assets/Shaders/Library/PBR.hlsl"

TEXTURE2D(_CopyTex);    SAMPLER(sampler_point_clamp);
TEXTURE2D(_ResultTex);    
TEXTURE2D(_PrevFrame);
TEXTURE2D(_CurrentFrame);

TEXTURE2D(_TransferTex);  SAMPLER(sampler_TransferTex);

TEXTURECUBE(_Skybox);       SAMPLER(sampler_Skybox);


float4 _Color;

int _FrameID;
float _Threshold;

HitInfo RaymarchCell(int level, int3 currentId, float3 position, float3 dirOS)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float3 stopPos = position;
    RayOctree(dirOS, level, currentId, stopPos);
    
    // TODO: do i need to check at position and newPos ?
    float3 t = stopPos - position;
    float3 step = t / 20;
    for (int i = 0; i <= 20; i++)
    {
        float3 stepPos = position + i * step;
        
        float3 uv = GetVolumeCoords(stepPos);
        
        float4 classification = SampleClassification(uv);
        float maxValue = max(max(max(classification.r, classification.g), classification.b), classification.a);
                    
        if (maxValue > _Threshold) // Surface hit
        {
            hitInfo.didHit = true;
            hitInfo.hitPointOS = stepPos - step;
            uv = GetVolumeCoords(hitInfo.hitPointOS);
            hitInfo.normalOS = SampleNormal(uv);
            
            //hitInfo.material.color = GetClassColor(classification);
            //hitInfo.material.color = (float) i / 10.0;
            hitInfo.material = GetMaterial(classification);
            
            return hitInfo;
        }
    }
    hitInfo.didHit = false;
    return hitInfo;
}

HitInfo TraverseOctree(float3 position, Ray ray)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    int octreeLevel = 0;
    float3 uv = GetVolumeCoords(position);
    int3 octreeId = GetOctreeId(octreeLevel, uv);
    
    if (!IsValid(position, ray.dirOS, octreeLevel, octreeId))
    {
        return hitInfo;
    }
    
    [loop]
    for (int i = 0; i < 256; i++)
    {
        float value = GetOctreeValueById(octreeLevel, octreeId);
        
    // when the current cell is above the threshold, increase the octree level
        if (value > _Threshold)
        {
            uv = GetVolumeCoords(position);
            
            IncreaseOctreeLevel(octreeLevel, octreeId, uv, _Threshold);
            
        // When the threshold is reached on max level, break
            value = GetOctreeValueById(octreeLevel, octreeId);
            if (octreeLevel >= 7 && value > _Threshold)
            {
                hitInfo = RaymarchCell(octreeLevel, octreeId, position, ray.dirOS);
                
                if (hitInfo.didHit)
                {
                    return hitInfo;
                }
            }
        }
        else
        {
        // Check if the octree level can be lowered again
            if (octreeLevel > 0)
            {
                ReduceOctreeLevel(octreeLevel, octreeId, _Threshold);
            }
        }
        
        bool valid = RayOctree(ray.dirOS, octreeLevel, octreeId, position);
        
        if (!valid)
        {
            break;
        }
        
    // Break when the octree id is out of bounds
        if (IsInvalid(octreeLevel, octreeId))
        {
            break;
        }
    }
    return hitInfo;
}

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


HitInfo RayMarchVolumeCollision(float3 position, Ray ray, inout uint rngState)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float _StepSize = 0.001;
    
    position += ray.dirOS * 0.001;
    
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
        float4 classification = SampleClassification(uv);
        
        if (density > _Threshold)
        {
            float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
                
            float3 normalOS = normalize(gradient);
                
            hitInfo.didHit = true;
            hitInfo.hitPointOS = position - ray.dirOS * _StepSize;
            hitInfo.normalOS = normalOS;
            hitInfo.material.color = GetClassColor(classification);;
                
            return hitInfo;
        }
        position += normalize(ray.dirOS) * _StepSize;
    }
    return hitInfo;
}


HitInfo RayMarchInsideVolume(float3 position, Ray ray, float radius, inout uint rngState)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float _StepSize = 0.001;
    
    float3 startPos = position;
    
    position += ray.dirOS * 0.001;
    
    [loop]
    for (int i = 0; i < 200; i++)
    {
        if (!InVolumeBoundsOS(position))
        {
            return hitInfo;
        }
        
        if (distance(position, startPos) > radius)
        {
            return hitInfo;
            hitInfo.hitPointOS = position;
        }
           
        float3 uv = GetVolumeCoords(position);
        float density = SampleDensity(uv);
        
        float4 classification = SampleClassification(uv);
        
        if (length(classification) < _Threshold)
        {
            float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
                
            float3 normalOS = normalize(gradient);
                
            hitInfo.didHit = true;
            hitInfo.hitPointOS = position - ray.dirOS * _StepSize;
            hitInfo.normalOS = normalOS;
            hitInfo.material.color = GetClassColor(classification);
                
            hitInfo.hitPointOS = lerp(startPos, hitInfo.hitPointOS, 0.5);
            
            return hitInfo;
        }
        position += normalize(ray.dirOS) * _StepSize;
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
        HitInfo hit = TraverseOctree(position, ray);
        if (hit.didHit)
        {
            /*
            // Diffuse
            ray.originOS = hit.hitPointOS;
            ray.dirOS = normalize(normalize(hit.normalOS) + RandomDirection(rngState));
            position = hit.hitPointOS;
            color *= hit.material.color;
            */
            
            //float3 randomVec = normalize(float3(RandomValue(rngState), RandomValue(rngState), RandomValue(rngState)) * 2 - 1);
            
            /*
            // BRDF
            position = hit.hitPointOS;
            ray.originOS = hit.hitPointOS;
            float3 newDirOS = normalize(normalize(hit.normalOS) + RandomDirection(rngState));
            
            float3 brdf = MicrofacetBRDF(newDirOS, -ray.dirOS, hit.normalOS, hit.material.color, 0.0, 0.5, 0.2);
            float illuminance = max(dot(newDirOS, hit.normalOS), 0.0);
            color *= brdf;// * illuminance;
            
            ray.dirOS = newDirOS;
            */
            
            // Specular
                
            float3 r = float3(RandomValue(rngState), RandomValue(rngState), RandomValue(rngState));
            
            float3 nextFactor;
            float3 nextDir;
            if (RandomValue(rngState) > 0.5)
            {
                nextDir = SampleSpecularMicrofacetBRDF(-ray.dirOS, hit.normalOS, hit.material.color, hit.material.metallicness, hit.material.reflectance, hit.material.roughness, r, nextFactor);
                ray.type = 2;
            }
            else
            {
                nextDir = SampleDiffuseMicrofacetBRDF(-ray.dirOS, hit.normalOS, hit.material.color, hit.material.metallicness, hit.material.reflectance, hit.material.roughness, r, nextFactor);
                ray.type = 1;
            }
            
            position = hit.hitPointOS;
            ray.originOS = hit.hitPointOS;
            ray.dirOS = nextDir;
            color *= nextFactor * 2;
            
            
            
            //return hit.normalOS;
            
            //position = hit.hitPointOS;
            //ray.originOS = hit.hitPointOS;
            //ray.dirOS = reflect(ray.dirOS, hit.normalOS);
            //color *= hit.material.color;

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

HitInfo RayMarchVolumeCollisions(float3 position, Ray ray, float radius, float3 pos0, inout uint rngState)
{
    HitInfo hitInfos[2];
    
    int hits = 0;
    
    float _StepSize = 0.001;
    
    int minSteps = ceil(radius / _StepSize);
    
    // Check if start pos is inside or outside volume
    float3 uv = GetVolumeCoords(position);
    float density = SampleDensity(uv);
    bool insideVolume = density > _Threshold;
    
    [loop]
    for (int i = 0; i < 200; i++)
    {
        if (i > minSteps && distance(position, pos0) > radius)
        {
            break;
        }
        
        if (hits > 1)
        {
            break;
        }
           
        float3 uv = GetVolumeCoords(position);
        float density = SampleDensity(uv);
        
        if (insideVolume)
        {
            if (density < _Threshold)
            {
                float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
                float3 normalOS = normalize(gradient);
                
                hitInfos[hits].didHit = true;
                hitInfos[hits].hitPointOS = position + ray.dirOS * _StepSize;
                hitInfos[hits].normalOS = normalOS;
                
                insideVolume = false;
                hits++;
            }
        }
        else
        {
            if (density > _Threshold)
            {
                float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
                float3 normalOS = normalize(gradient);
                
                hitInfos[hits].didHit = true;
                hitInfos[hits].hitPointOS = position - ray.dirOS * _StepSize;
                hitInfos[hits].normalOS = normalOS;
                
                insideVolume = true;
                hits++;
            }
        }
        position += normalize(ray.dirOS) * _StepSize;
    }        
    
    if (hits == 0)
    {
        return (HitInfo) 0;
    }
    else if (hits == 1)
    {
        return hitInfos[0];
    }
    else
    {
        float random = RandomValue(rngState);
        if (random > 0.5)
        {
            return hitInfos[0];
        }
        else
        {
            return hitInfos[1];
        }
    }
}

float3 GetTangent(in float3 normal)
{
    float3 someVec = float3(1.0, 0.0, 0.0);
    float dd = dot(someVec, normal);
    float3 tangent = float3(0.0, 1.0, 0.0);
    if (1.0 - abs(dd) > 1e-6)
    {
        tangent = normalize(cross(someVec, normal));
    }
    return tangent;
}

float _SSSRadius;
float _DisneyD;

float3 SampleSSSPosition(HitInfo hit, inout uint rngState)
{
    float radius = _SSSRadius;
    
    float phi = 2 * PI * RandomValue(rngState);
    float theta = sqrt(RandomValue(rngState));

    float3 normal = normalize(hit.normalOS);
    float3 tangent = GetTangent(normal);

    float3x3 rot = AngleAxis3x3(phi, normal);

    float3 sampleOffset = mul(rot, tangent) * radius * theta;

    float3 origin = hit.hitPointOS + (normal * radius) + sampleOffset;

    return origin;
}

float ReflectanceProfile(float r, float d)
{
    float a = exp(-r / d) + exp(-r / (3 * d));
    float b = 8 * PI * d * r;
    return a / b;
}

float3 TraceSSS(float3 position, Ray ray, inout uint rngState)
{
    float3 color = 1;
    float3 incomingLight = 0;
    
    float radius = _SSSRadius;
    
    for (int i = 0; i <= 2; i++)
    {
        HitInfo hit = RayMarchVolumeCollision(position, ray, rngState);
        if (hit.didHit)
        {
            /*
            Ray sssRay;
            sssRay.originOS = hit.hitPointOS;
            sssRay.dirOS = normalize(-hit.normalOS);
            HitInfo innerHit = RayMarchInsideVolume(hit.hitPointOS, sssRay, radius, rngState);
            
            Ray innerRay;
            innerRay.originOS = innerHit.hitPointOS;
            innerRay.dirOS = RandomDirection(rngState);
            HitInfo outerHit = RayMarchInsideVolume(innerHit.hitPointOS, innerRay, radius * 2, rngState);
            
            if (outerHit.didHit)
            {
                ray.originOS = outerHit.hitPointOS;
                ray.dirOS = normalize(normalize(outerHit.normalOS) + RandomDirection(rngState));
                position = outerHit.hitPointOS;
                //color *= float3(0.7, 0.4, 0.3);
            }
            else
            {
                return 0;
            }
            */
            
            if (i == 0)
            {
                // Sample Disc
            
                float3 sssOrigin = SampleSSSPosition(hit, rngState);
                Ray sssRay;
                sssRay.originOS = sssOrigin;
                sssRay.dirOS = normalize(-hit.normalOS);
                
                HitInfo sssHit = RayMarchVolumeCollisions(sssOrigin, sssRay, _SSSRadius, hit.hitPointOS, rngState);
                
                if (sssHit.didHit && distance(sssHit.hitPointOS, hit.hitPointOS) < _SSSRadius)
                {
                    // Calculate reflectance profile
                    float r = distance(sssHit.hitPointOS, hit.hitPointOS);
                    float rProfile = ReflectanceProfile(r, _DisneyD);
                    //return rProfile;
                    
                    ray.originOS = sssHit.hitPointOS;
                    ray.dirOS = normalize(normalize(sssHit.normalOS) + RandomDirection(rngState));
                    position = sssHit.hitPointOS;
                    color *= _Color * rProfile;
                }
                else
                {
                    return 0;
                }
            }
            else
            {
                ray.originOS = hit.hitPointOS;
                ray.dirOS = normalize(normalize(hit.normalOS) + RandomDirection(rngState));
                position = hit.hitPointOS;
                color *= hit.material.color;
            }
        }
        else
        {
            int rayType = (i == 0) ? 0 : 1;
            
            float3 dirWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, ray.dirOS));
            float4 skyData = SampleEnvironment(dirWS, rayType);
            incomingLight = color * skyData.rgb;
            break;
        }
    }
    return incomingLight;
}

float4 SampleEnvironmentMap(float3 dirWS)
{
    float s = frac(1.0 / (2.0 * PI) * atan2(-dirWS.x, -dirWS.z));
    float t = 1.0 / (PI) * acos(-dirWS.y);
    float2 uv = float2(s, t);
    
    return 0;
    //return SAMPLE_TEXTURE2D_LOD(_EnvironmentMap, sampler_EnvironmentMap, uv, 0);
}

float4 RaytraceFragment(Varyings IN) : SV_TARGET
{
    float2 pixelOffset = float2(Halton(2, _FrameID) - 0.5, Halton(3, _FrameID) - 0.5) / _ScreenParams.xy;
    
    //return Rand3dTo1d(float3(IN.uv, _FrameID));
    
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
            
    float4 skyData = SampleEnvironment(ray.dirWS, 0);
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