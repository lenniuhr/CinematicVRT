using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu]
public class TransferFunction : ScriptableObject
{
    public Gradient Albedo;
    public Gradient Roughness;
    public Gradient Alpha;

    [Range(0, 1000)]
    public float SigmaT;
    public float MinDensity;
    public float MaxDensity;
    [Range(0, 0.3f)]
    public float GradientShift;
    [Range(0, 0.3f)]
    public float GradientLimit;

    private bool hasChanged = false;

    public bool HasChanged()
    {
        if(hasChanged)
        {
            hasChanged = false;
            return true;
        }
        return false;
    }

    private void OnValidate()
    {
        hasChanged = true;
    }
}
