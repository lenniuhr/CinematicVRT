#ifndef RAYTRACING_INCLUDED
#define RAYTRACING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shaders/RayTracingUtils.hlsl"
#include "Assets/Shaders/DefaultInput.hlsl"

TEXTURE2D(_CopyTex);    SAMPLER(sampler_point_clamp);
TEXTURE2D(_ResultTex);    
TEXTURE2D(_PrevFrame);

float3 _ViewParams;
float4x4 _CamLocalToWorldMatrix;

int _FrameID;

int _MaxBounces;

struct RayTracingMaterial
{
    half4 color;
    half4 emissionColor;
};

struct Ray
{
	float3 origin;
	float3 dir;
};

struct Sphere
{
    float3 position;
    float radius;
    RayTracingMaterial material;
};

struct Cube
{
    float3 position;
    float3 scale;
    RayTracingMaterial material;
};

struct HitInfo
{
    bool didHit;
    float dist;
    float3 hitPoint;
    float3 normal;
    RayTracingMaterial material;
};

StructuredBuffer<Sphere> _Spheres;
int _NumSpheres;

StructuredBuffer<Cube> _Cubes;
int _NumCubes;

// Calculate the intersection of a ray with a sphere
HitInfo RaySphere(Ray ray, float3 sphereCenter, float sphereRadius, RayTracingMaterial material)
{
    HitInfo hitInfo = (HitInfo) 0;
	
	float3 offsetRayOrigin = ray.origin - sphereCenter;
	// From the equation: sqrLength(rayOrigin + rayDir * dst) = radius^2
	// Solving for dst results in a quadratic equation with coefficients:
	float a = dot(ray.dir, ray.dir); // a = 1 (assuming unit vector)
	float b = 2 * dot(offsetRayOrigin, ray.dir);
	float c = dot(offsetRayOrigin, offsetRayOrigin) - sphereRadius * sphereRadius;
	// Quadratic discriminant
	float discriminant = b * b - 4 * a * c; 

	// No solution when d < 0 (ray misses sphere)
	if (discriminant >= 0) {
		// Distance to nearest intersection point (from quadratic formula)
        float dist = (-b - sqrt(discriminant)) / (2 * a);

		// Ignore intersections that occur behind the ray
        if (dist >= 0) 
		{
            hitInfo.didHit = true;
            hitInfo.dist = dist;
            hitInfo.hitPoint = ray.origin + ray.dir * dist;
            hitInfo.normal = normalize(hitInfo.hitPoint - sphereCenter);
            hitInfo.material = material;
        }
	}
    return hitInfo;
}

// Thanks to https://gist.github.com/DomNomNom/46bb1ce47f68d255fd5d
HitInfo RayBoundingBox(Ray ray, float3 boxMin, float3 boxMax, RayTracingMaterial material)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float3 invDir = 1 / ray.dir;
    float3 tMin = (boxMin - ray.origin) * invDir;
    float3 tMax = (boxMax - ray.origin) * invDir;
    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    
    
    if (tNear >= 0)
    {
        hitInfo.didHit = tNear <= tFar;
        hitInfo.dist = tNear;
        hitInfo.hitPoint = ray.origin + ray.dir * tNear;
        hitInfo.material = material;
        
        float3 normal;
        if (t1.x > t1.y && t1.x > t1.z)
        {
            normal = float3(1, 0, 0) * -sign(ray.dir.x);
        }
        else if(t1.y > t1.x && t1.y > t1.z)
        {
            normal = float3(0, 1, 0) * -sign(ray.dir.y);
        }
        else if (t1.z > t1.x && t1.z > t1.y)
        {
            normal = float3(0, 0, 1) * -sign(ray.dir.z);
        }
        
        hitInfo.normal = normal;
    }
    
    return hitInfo;
};

HitInfo CalculateRayCollision(Ray ray)
{
	HitInfo closestHit = (HitInfo) 0;
    closestHit.dist = 1.#INF;
	
    for (int i = 0; i < _NumSpheres; i++)
    {
        Sphere sphere = _Spheres[i];
        HitInfo hit = RaySphere(ray, sphere.position, sphere.radius, sphere.material);

        if (hit.didHit && hit.dist < closestHit.dist)
        {
            closestHit = hit;
        }
    }
    
    for (int i = 0; i < _NumCubes; i++)
    {
        Cube cube = _Cubes[i];
        float3 boxMin = cube.position - cube.scale / 2.0;
        float3 boxMax = cube.position + cube.scale / 2.0;
        HitInfo hit = RayBoundingBox(ray, boxMin, boxMax, cube.material);

        if (hit.didHit && hit.dist < closestHit.dist)
        {
            closestHit = hit;
        }
    }
    
    return closestHit;
}

half3 Trace(Ray ray, inout uint rngState)
{
    float3 color = 1;
    float3 incomingLight = 0;
    
    for (int i = 0; i <= _MaxBounces; i++)
    {
        HitInfo hit = CalculateRayCollision(ray);
        if (hit.didHit)
        {
            ray.origin = hit.hitPoint;
            ray.dir = normalize(hit.normal + RandomDirection(rngState));
            
            incomingLight += color * hit.material.emissionColor;
            color *= hit.material.color;
            
            // Russian Roulette
            /*float p = max(color.r, max(color.g, color.b));
            if (RandomValue(rngState) > p)
            {
                break;
            }
            color *= 1 / p;*/
        }
        else
        {
            break;
        }
    }
    return incomingLight;
}

// from http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
// Hacker's Delight, Henry S. Warren, 2001
float radicalInverse(uint bits)
{
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10; // / 0x100000000
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

float2 hammersley(uint n, uint N)
{
    return float2((float(n) + 0.5) / float(N), radicalInverse(n + 1u));
}


float4 RayTracingFragment(Varyings IN) : SV_TARGET
{
    // compute random pixel offset
    float2 pixelOffset = hammersley(uint(_FrameID), uint(1000)) / _ScreenParams.xy;
    
    pixelOffset = float2(Halton(2, _FrameID) - 0.5, Halton(3, _FrameID) - 0.5) / _ScreenParams.xy;
    
    //return -Halton(2, _FrameID);
    
    // Create seed for random number generator
    uint2 numPixels = _ScreenParams.xy;
    uint2 pixelCoord = IN.uv * numPixels;
    uint pixelIndex = pixelCoord.y * numPixels.x + pixelCoord.x;
    uint rngState = pixelIndex + _FrameID * 719393;
    
    float3 viewPointLocal = float3(IN.uv - 0.5 + pixelOffset, 1) * _ViewParams;
	float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1)).xyz;

	Ray ray;
	ray.origin = _WorldSpaceCameraPos;
	ray.dir = normalize(viewPoint - ray.origin);
    
    float3 color = Trace(ray, rngState);
    
    return float4(saturate(color), 1);
}

float4 CopyFragment(Varyings IN) : SV_TARGET
{
    return SAMPLE_TEXTURE2D(_CopyTex, sampler_point_clamp, IN.uv);
}

float4 AccumulateFragment(Varyings IN) : SV_Target
{
    float4 color = SAMPLE_TEXTURE2D(_ResultTex, sampler_point_clamp, IN.uv);
    float4 prevColor = SAMPLE_TEXTURE2D(_PrevFrame, sampler_point_clamp, IN.uv);
    
    float weight = 1.0 / (_FrameID + 1.0);
    
    float4 accumulatedColor = prevColor * (1.0 - weight) + color * weight;
				
    return accumulatedColor;
}

#endif