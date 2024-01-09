using System;
using System.Data;
using System.Threading.Tasks;
using UnityEditor;
using UnityEngine;
using UnityEngine.UIElements;

public class VolumeDataset : ScriptableObject
{
    public string datasetName;
    public DataFormat dataFormat;
    public int width;
    public int height;
    public int depth;
    public float minValue;
    public float maxValue;
    [SerializeField] public Texture3D dataTex;

    [Header("Editable")]
    public Vector3 spacing;
    public float clampRangeMin;
    public float clampRangeMax;

    public float GetRangeMin()
    {
        return Mathf.Max(minValue, clampRangeMin);
    }

    public float GetRangeMax()
    {
        return Mathf.Min(maxValue, clampRangeMax);
    }

    public Vector3 GetScale()
    {
        Vector3 scale = new Vector3(width * spacing.x, height * spacing.y, depth * spacing.z);
        float maxDim = Mathf.Max(scale.x, Mathf.Max(scale.y, scale.z));
        return scale / maxDim;
    }

    public Vector3 GetNormalizedSpacing()
    {
        Vector3 normSpacing = spacing / Mathf.Min(spacing.x, Mathf.Min(spacing.y, spacing.z));
        return normSpacing;
    }

    public async Task<Texture2D> GetHistogram()
    {
        return null;
    }

    private float Gauss(float sigma, int x, int y)
    {
        return Mathf.Exp(-(x * x + y * y) / (2 * sigma * sigma));
    }

    float GaussianBlur(int xCenter, int yCenter, int hWidth, int hHeight, float[] values)
    {
        int kernelRadius = 6;
        float sigma = 6;

        float valueAcc = 0;
        float totalWeight = 0;

        for (int x = -kernelRadius; x <= kernelRadius; x++)
        {
            for (int y = -kernelRadius; y <= kernelRadius; y++)
            {
                float weight = Gauss(sigma, x, y);

                int pixelX = xCenter + x;
                int pixelY = yCenter + y;

                if(pixelX < 0 || pixelX >= hWidth || pixelY < 0 || pixelY >= hHeight)
                {
                    continue;
                }

                int pixelIndex = pixelX + hWidth * pixelY;
                float value = values[pixelIndex];

                valueAcc += weight * value;
                totalWeight += weight;
            }
        }

        return valueAcc / totalWeight;
    }
}
