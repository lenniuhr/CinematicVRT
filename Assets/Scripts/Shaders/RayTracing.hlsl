#ifndef RAYTRACING_INCLUDED
#define RAYTRACING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Scripts/Shaders/DefaultInput.hlsl"

TEXTURE2D(_ResultTex);    SAMPLER(sampler_point_clamp);

float3 _ViewParams;
float4x4 _CamLocalToWorldMatrix;

struct Ray
{
	float3 origin;
	float3 dir;
};

struct Sphere
{
	float3 position;
	float radius;
};

struct HitInfo
{
    bool didHit;
    float dist;
    float3 hitPoint;
    float3 normal;
};

StructuredBuffer<Sphere> _Spheres;
int _NumSpheres;

// Calculate the intersection of a ray with a sphere
HitInfo RaySphere(Ray ray, float3 sphereCenter, float sphereRadius)
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
        }
	}
    return hitInfo;
}

HitInfo CalculateRayCollision(Ray ray)
{
	HitInfo closestHit = (HitInfo) 0;
    closestHit.dist = 1.#INF;
	
    for (int i = 0; i < _NumSpheres; i++)
    {
        Sphere sphere = _Spheres[i];
        HitInfo hit = RaySphere(ray, sphere.position, sphere.radius);

        if (hit.didHit && hit.dist < closestHit.dist)
        {
            closestHit = hit;
        }
    }
    return closestHit;
}

half4 RayTracingFragment(Varyings IN) : SV_TARGET
{
	float3 viewPointLocal = float3(IN.uv - 0.5, 1) * _ViewParams;
	float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1)).xyz;

	Ray ray;
	ray.origin = _WorldSpaceCameraPos;
	ray.dir = normalize(viewPoint - ray.origin);

    HitInfo hit = CalculateRayCollision(ray);
    if (hit.didHit)
    {
        return 1;
    }
    return half4(ray.dir, 1);
}

half4 CopyFragment(Varyings IN) : SV_TARGET
{
	return SAMPLE_TEXTURE2D(_ResultTex, sampler_point_clamp, IN.uv);
}

#endif