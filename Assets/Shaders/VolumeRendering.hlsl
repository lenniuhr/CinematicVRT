#ifndef VOLUME_RENDERING_INCLUDED
#define VOLUME_RENDERING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/Shaders/Library/DefaultInput.hlsl"
#include "Assets/Shaders/Library/Common.hlsl"
#include "Assets/Shaders/Library/BRDF.hlsl"
#include "Assets/Shaders/Library/Volume.hlsl"
#include "Assets/Shaders/Library/Tricubic.hlsl"
#include "Assets/Shaders/Library/Classification.hlsl"
#include "Assets/Shaders/Library/Octree.hlsl"

float _StepSize;
float _Threshold;
half4 _Color;

float _Roughness;
float _Metallicness;


TEXTURE2D(_TransferTex);  SAMPLER(sampler_TransferTex);
TEXTURE2D(_1DTransferTex);  SAMPLER(sampler_1DTransferTex);

TEXTURECUBE(_Skybox);       SAMPLER(sampler_Skybox);


TEXTURE3D(_ClassifyTex);  SAMPLER(sampler_ClassifyTex);

float3 ComputeNormal(float3 uv)
{
    float offsetXY = 1 / 256.0;
    float offsetZ = 1 / 256.0;
    
    float3 rightUV = uv + float3(offsetXY, 0, 0);
    float3 leftUV = uv + float3(-offsetXY, 0, 0);
    float3 topUV = uv + float3(0, offsetXY, 0);
    float3 bottomUV = uv + float3(0, -offsetXY, 0);
    float3 frontUV = uv + float3(0, 0, offsetZ);
    float3 backUV = uv + float3(0, 0, -offsetZ);
    
    float value = SampleDensity(uv);
    
    float rightValue = SampleDensity(rightUV);
    float leftValue = SampleDensity(leftUV);
    float topValue = SampleDensity(topUV);
    float bottomValue = SampleDensity(bottomUV);
    float frontValue = SampleDensity(frontUV);
    float backValue = SampleDensity(backUV);    

    float gx = leftValue - rightValue;
    float gy = bottomValue - topValue;
    float gz = backValue - frontValue;

    return float3(gx, gy, gz);
}

StructuredBuffer<float> _ClassifyBuffer;

HitInfo RaymarchCell(int level, int3 currentId, float3 position, float3 dirOS, out int3 newId, out float3 newPos)
{
    HitInfo hitInfo = (HitInfo)0;
    
    RayOctree(level, currentId, position, dirOS, newId, newPos);
    
    // TODO: do i need to check at position and newPos ?
    
    float3 t = newPos - position;
    float3 step = t / 10;
    for (int i = 0; i <= 10; i++)
    {
        float3 stepPos = position + i * step;
        
        
        float3 uv = GetVolumeCoords(stepPos);
        float density = SampleDensity(uv);
                    
        if (density > _Threshold)
        {
            // Surface hit
            float3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
            float3 normalOS = normalize(gradient);
                
            hitInfo.didHit = true;
            hitInfo.hitPointOS = position;
            hitInfo.normalOS = normalOS;
            hitInfo.material.color = normalize(normalOS) * 0.5 + 0.5;
                
            return hitInfo;
        }
    }
    hitInfo.didHit = false;
    return hitInfo;
}

HitInfo RayMarchOctree(float3 position, Ray ray)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    int steps = 0;    
    int octreeLevel = 0;
    float3 uv = GetVolumeCoords(position);
    int3 octreeId = GetOctreeId(octreeLevel, uv);
    
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
                // TODO: Raymarch octree cell
                float3 hitPoint;
                int3 nextId;
                hitInfo = RaymarchCell(octreeLevel, octreeId, position, ray.dirOS, nextId, hitPoint);
                
                if (hitInfo.didHit)
                    return hitInfo;
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
        
        float3 hitPoint;
        int3 nextId;
        RayOctree(octreeLevel, octreeId, position, ray.dirOS, nextId, hitPoint);
        
        if (Equals(nextId, octreeId))
        {
            hitInfo.didHit = true;
            hitInfo.material.color = float4(1, 1, 1, 1);
            return hitInfo;
        }
            
        position = hitPoint;
        octreeId = nextId;
        steps++;
        
        // Break when the octree id is out of bounds
        if (IsInvalid(octreeLevel, octreeId))
        {
            break;
        }
    }
    
    return hitInfo;
}

float4 RayMarch(float3 position, Ray ray)
{
    float3 step = ray.dirOS * _StepSize;
    float4 output = 0;

    int steps = 0;
    
    [loop]
    for (int i = 0; i < 720; i++)
    {
        position += step;
        steps++;
        
        if (!InVolumeBoundsOS(position))
        {
            break;
        }
        
        float3 uv = GetVolumeCoords(position);
        
        int x = clamp(floor(uv.x * 512), 0, 512 - 1);
        int y = clamp(floor(uv.y * 512), 0, 512 - 1);
        int z = clamp(floor(uv.z * 460), 0, 460 - 1);

        int index = (512 * 512 * z + 512 * y + x);
        
        
        
        float4 value = SAMPLE_TEXTURE3D_LOD(_ClassifyTex, sampler_ClassifyTex, uv, 0);
        
        //float4 value = tex3DTricubic(_ClassifyTex, sampler_ClassifyTex, uv, float3(512, 512, 460));
        
        
        /*
        if (length(value) > _Threshold)
        {
            half3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
            
            //if (length(gradient) > 0.2)
                //continue;
            
            float3 normalWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, gradient));
            
            //float4 color = SAMPLE_TEXTURE2D_LOD(_1DTransferTex, sampler_1DTransferTex, float2(value, 0.5), 0);
            
            float4 color = GetClassColor(value);
            
            float3 gi = SampleSH(normalWS);
            color.rgb = PBRLighting(color.rgb, 1 - _Roughness, _Metallicness, -ray.dirWS, normalWS, gi);
            output.rgb = color;
            output.a = 1;
            
            break;
        }
        */
        
        float density = SampleDensity(uv);
        
        if (density  > _Threshold)
        {
            half3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
            
            //if (length(gradient) > 0.2)
                //continue;
            
            float3 normalWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, gradient));
            
            //float4 color = SAMPLE_TEXTURE2D_LOD(_1DTransferTex, sampler_1DTransferTex, float2(value, 0.5), 0);
            
            float4 color = float4(normalWS, 1);
            
            float3 gi = SampleSH(normalWS);
            color.rgb = PBRLighting(color.rgb, 1 - _Roughness, _Metallicness, -ray.dirWS, normalWS, gi);
            output.rgb = color;
            output.a = 1;
            break;
        }
        
        /*
        half3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
        float3 normalWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, gradient));

        float2 transferUV = float2(density, length(gradient));
        float4 color = SAMPLE_TEXTURE2D_LOD(_TransferTex, sampler_TransferTex, transferUV, 0);
        
        if(color.a < 0.001)
        {
            continue;
        }
        
        
        // PBR Lighting
        float3 gi = SampleSH(normalWS);
        color.rgb = PBRLighting(color.rgb, 1 - _Roughness , _Metallicness, -ray.dirWS, normalWS, gi);
        
        //color.rgb = gi;
        
        // alpha is per 0.1 units
        float transparency = _StepSize / 0.002;

        float oneMinusAlpha = 1.0 - output.a;
        output.a += oneMinusAlpha * color.a * transparency;
        output.rgb += oneMinusAlpha * color.a * transparency * color.rgb;

        if(output.a > 0.999)
        {
            break;
        }*/
    }
    
    return output;
}

int IncreaseOctreeLevel(int level, float3 uv)
{
    int newLevel = level;
    while (newLevel < _OctreeDepth)
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

HitInfo CalculateRayVolumeCollision(float3 position, Ray ray)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    int octreeLevel = 0;
    float octreeDim = OCTREE_DIM[octreeLevel];
    
    // Octree id
    int3 parentId = int3(-1, -1, -1);
    int3 myId = int3(-1, -1, -1);
    
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
        
        int3 newId = GetOctreeId(octreeLevel, uv);
        if (newId.x == myId.x && newId.y == myId.y && newId.z == myId.z)
        {
            hitInfo.didHit = true;
            hitInfo.material.color = float3(0, 1, 0);
                
            return hitInfo;
        }
        myId = newId;
        
        if (value > _Threshold)
        {
            octreeLevel = IncreaseOctreeLevel(octreeLevel, uv);
            parentId = GetOctreeId(octreeLevel - 1, uv);
            
            value = GetOctreeValue(octreeLevel, uv);
                
            if (value > _Threshold)
            {
                for (int step = 0; step < 50; step++)
                {
                    
                    uv = GetVolumeCoords(position);
                    float density = SampleDensity(uv);
                    
                // TODO when box is left, exit stepping
                    
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
                        hitInfo.hitPointOS = position;
                        hitInfo.normalOS = normalOS;
                        hitInfo.material.color = normalize(normalOS);
                
                        return hitInfo;
                    }
                    else
                    {
                        position += ray.dirOS * 0.0003;
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

float4 VolumeRenderingFragment(Varyings IN) : SV_TARGET
{
    Ray ray = GetRay(IN.uv);
    
    //return SAMPLE_TEXTURE2D(_TransferTex, sampler_TransferTex, IN.uv);

    float4 skyData = SAMPLE_TEXTURECUBE(_Skybox, sampler_Skybox, ray.dirWS);
    
    //half3 gi = SampleSH(dirWS);
    //return half4(gi, 1);
    
    float3 hitPoint;
    if (RayBoundingBoxOS(ray, hitPoint))
    {
        //float4 output = RayMarch(hitPoint, ray);
        //output += (1.0 - output.a) * saturate(skyData);
        //return output;
        
        //HitInfo hitInfo = CalculateRayVolumeCollision(hitPoint, ray);
        HitInfo hitInfo = RayMarchOctree(hitPoint, ray);
        if (hitInfo.didHit)
        {
            float3 uv = GetVolumeCoords(hitInfo.hitPointOS);
            half3 gradient = SAMPLE_TEXTURE3D_LOD(_GradientTex, sampler_GradientTex, uv, 0).xyz * 2 - 1;
            
            //float4 color = GetClassColor(value);
            
            float3 normalWS = normalize(mul((float3x3) _VolumeLocalToWorldMatrix, hitInfo.normalOS));
            
            float3 gi = SampleSH(normalWS);
            float4 output = 0;
            output.rgb = PBRLighting(hitInfo.material.color.rgb, 1 - _Roughness, _Metallicness, -ray.dirWS, normalWS, gi);
            output.a = 1;
            
            //output.rgb = hitInfo.material.color.rgb;
            
            return output;
        }

    }

    //half mip = PerceptualRoughnessToMipmapLevel(info.perceptualRoughness);
    //half4 encodedIrradiance = half4(SAMPLE_TEXTURECUBE_LOD(_GlossyEnvironmentCubeMap, sampler_GlossyEnvironmentCubeMap, reflectVector, mip));
    //half3 indirectSpecular = DecodeHDREnvironment(encodedIrradiance, _GlossyEnvironmentCubeMap_HDR);
    
    //return float4(0, 0, 0, 1);
    return skyData;
}

#endif