using UnityEngine;

[System.Serializable]
public struct RayTracingMaterial
{
    public Color color;
    public Color emissionColor;
}

public struct Sphere
{
    public Vector3 position;
    public float radius;
    public RayTracingMaterial material;
}
