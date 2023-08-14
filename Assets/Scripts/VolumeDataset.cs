using System;
using System.Threading.Tasks;
using Unity.Mathematics;
using UnityEngine;

public class VolumeDataset : ScriptableObject
{
    public string datasetName;
    public DataFormat dataFormat;
    public int width;
    public int height;
    public int depth;
    public float minValue;
    public float maxValue;
    public Vector3 spacing;

    [HideInInspector][SerializeField]
    private float[] data;

    private Texture3D dataTexture;
    private Texture3D gradientTexture;
    private Texture2D histogram;

    public async Task<Texture3D> GetTexture()
    {
        if(dataTexture != null)
        {
            return dataTexture;
        }
        else
        {
            Debug.Log("Start generation");

            Texture.allowThreadedTextureCreation = true;
            dataTexture = new Texture3D(width, height, depth, TextureFormat.RHalf, false);
            dataTexture.wrapMode = TextureWrapMode.Clamp;
            dataTexture.filterMode = FilterMode.Bilinear;

            ushort[] shorts = new ushort[width * height * depth];

            await Task.Run(() =>
            {
                for (int z = 0; z < depth; z++)
                {
                    for (int x = 0; x < width; x++)
                    {
                        for (int y = 0; y < height; y++)
                        {
                            int i = z * (width * height) + y * width + x;

                            // Convert to [0, 1] range
                            float value = (data[i] - minValue) / (maxValue - minValue);
                            shorts[i] = Mathf.FloatToHalf(value);

                        }
                    }
                }
            });

            dataTexture.SetPixelData(shorts, 0);
            dataTexture.Apply();

            return dataTexture;
        }
    }

    public async Task<Texture3D> GetGradientTexture()
    {
        if (gradientTexture != null)
        {
            return gradientTexture;
        }
        else
        {
            Texture.allowThreadedTextureCreation = true;
            gradientTexture = new Texture3D(width, height, depth, TextureFormat.RGB24, false);
            gradientTexture.wrapMode = TextureWrapMode.Clamp;
            gradientTexture.filterMode = FilterMode.Bilinear;

            Color[] colors = new Color[width * height * depth];
            await Task.Run(() =>
            {
                for (int z = 0; z < depth; z++)
                {
                    for (int x = 0; x < width; x++)
                    {
                        for (int y = 0; y < height; y++)
                        {
                            int i = z * (width * height) + y * width + x;

                            // Convert to [0, 1] range
                            Vector3 gradient = GetGradient(x, y, z);
                            colors[i] = new Color(gradient.x, gradient.y, gradient.z);
                        }
                    }
                }
            });

            gradientTexture.SetPixels(colors, 0);
            gradientTexture.Apply();

            return gradientTexture;
        }
    }

    private Vector3 GetGradient(int x, int y, int z)
    {
        float valueRange = maxValue - minValue;
        float x1 = data[Math.Min(x + 1, width - 1) + y * width + z * (width * height)] - minValue;
        float x2 = data[Math.Max(x - 1, 0) + y * width + z * (width * height)] - minValue;
        float y1 = data[x + Math.Min(y + 1, height - 1) * width + z * (width * height)] - minValue;
        float y2 = data[x + Math.Max(y - 1, 0) * width + z * (width * height)] - minValue;
        float z1 = data[x + y * width + Math.Min(z + 1, depth - 1) * (width * height)] - minValue;
        float z2 = data[x + y * width + Math.Max(z - 1, 0) * (width * height)] - minValue;

        return new Vector3((x2 - x1) / valueRange, (y2 - y1) / valueRange, (z2 - z1) / valueRange);
    }

    public Vector3 GetScale()
    {
        Vector3 scale = new Vector3(width * spacing.x, height * spacing.y, depth * spacing.z);
        float maxDim = Mathf.Max(scale.x, Mathf.Max(scale.y, scale.z));
        return scale / maxDim;
    }

    public void SetData(float[] data)
    {
        this.data = data;
    }

    public async Task<Texture2D> GetHistogram()
    {
        if (histogram != null && false)
        {
            return histogram;
        }
        else
        {
            Debug.Log("Generating Histogram");

            int hWidth = 1024;
            int hHeight = 512;

            Texture.allowThreadedTextureCreation = true;
            histogram = new Texture2D(hWidth, hHeight, TextureFormat.RGBAFloat, false);
            histogram.wrapMode = TextureWrapMode.Clamp;
            histogram.filterMode = FilterMode.Bilinear;

            Color[] colors = new Color[hWidth * hHeight];
            float[] values = new float[hWidth * hHeight];

            const float maxNormalisedMagnitude = 1;

            await Task.Run(() =>
            {
                // Count pixels
                for (int z = 0; z < depth; z++)
                {
                    for (int x = 0; x < width; x++)
                    {
                        for (int y = 0; y < height; y++)
                        {
                            int i = z * (width * height) + y * width + x;

                            // Convert to [0, 1] range
                            float value = (data[i] - minValue) / (maxValue - minValue);
                            Vector3 gradient = GetGradient(x, y, z);

                            int pixelX = Mathf.Min(hWidth - 1, Mathf.FloorToInt(value * hWidth));

                            float gradient01 = Mathf.Clamp01(gradient.magnitude / maxNormalisedMagnitude);

                            int pixelY = Mathf.Min(hHeight - 1, Mathf.FloorToInt(gradient01 * hHeight));

                            int pixelIndex = pixelX + hWidth * pixelY;

                            values[pixelIndex]++;
                        }
                    }
                }

                float maxVal = 0;
                // Calculate average
                for (int i = 0; i < hWidth * hHeight; i++)
                {
                    maxVal = Mathf.Max(maxVal, values[i]);
                }
                float maxLog = Mathf.Log10(maxVal);
                Debug.Log($"Max Log: {maxLog}");

                // Apply logarithmic color scale
                for (int i = 0; i < hWidth * hHeight; i++)
                {
                    float log = Mathf.Log10(values[i]);
                    float c = Mathf.Clamp01(log / (maxLog * 0.7f));
                    values[i] = c;
                }

                // Correct empty columns
                float brightness = 1;
                if(dataFormat == DataFormat.UInt8)
                {
                    brightness = hWidth / 256.0f;
                }

                // Gaussian Blur
                for (int x = 0; x < hWidth; x++)
                {
                    for (int y = 0; y < hHeight; y++)
                    {
                        float c = GaussianBlur(x, y, hWidth, hHeight, values) * brightness;
                        // Prevent screen flickering by removing fully black values
                        c = 0.05f + 0.95f * c;

                        int pixelIndex = x + hWidth * y;
                        colors[pixelIndex] = new Color(c, c, c, 1).linear;
                    }
                }
            });

            histogram.SetPixels(colors, 0);
            histogram.Apply();

            Debug.Log("Finished Histogram Generation");

            return histogram;
        }
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
