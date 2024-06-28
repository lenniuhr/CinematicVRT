using JetBrains.Annotations;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class TransferFunctionManager : MonoBehaviour
{
    public TransferFunction transferFunction;

    private const int WIDTH = 2048;

    private bool hasChanged = false;

    private Texture2D albedoTexture;
    private Texture2D roughnessTexture;
    private Texture2D metallicTexture;
    private Texture2D alphaTexture;

    public bool HasChanged()
    {
        if (hasChanged)
        {
            hasChanged = false;
            return true;
        }
        return false;
    }

    private void OnEnable()
    {
        UpdateTransferTex();
    }

    private void OnDisable()
    {

    }

    private void Update()
    {
        if(transferFunction != null && transferFunction.HasChanged())
        {
            UpdateTransferTex();
        }
    }

    private void OnValidate()
    {
        if (!enabled) return;

        UpdateTransferTex();
    }

    private void UpdateTransferTex()
    {
        if (transferFunction == null)
        {
            return;
        }

        GenerateTexture(ref albedoTexture, transferFunction.Albedo);
        GenerateTexture(ref roughnessTexture, transferFunction.Roughness);
        GenerateTexture(ref metallicTexture, transferFunction.Metallic);
        GenerateTexture(ref alphaTexture, transferFunction.Alpha);

        Shader.SetGlobalTexture("_AlbedoTex", albedoTexture);
        Shader.SetGlobalTexture("_RoughnessTex", roughnessTexture);
        Shader.SetGlobalTexture("_MetallicTex", metallicTexture);
        Shader.SetGlobalTexture("_AlphaTex", alphaTexture);

        Shader.SetGlobalFloat("_SigmaT", transferFunction.SigmaT);
        Shader.SetGlobalFloat("_Reflectance", transferFunction.Reflectance);

        Shader.SetGlobalFloat("_MinDensity", transferFunction.MinDensity);
        Shader.SetGlobalFloat("_MaxDensity", transferFunction.MaxDensity);
        Shader.SetGlobalFloat("_GradientShift", transferFunction.GradientShift);
        Shader.SetGlobalFloat("_GradientLimit", transferFunction.GradientLimit);

        Debug.Log("Updated Transfer Texture");
        hasChanged = true;
    }

    private void GenerateTexture(ref Texture2D texture, Gradient gradient)
    {
        if(texture == null)
        {
            texture = new Texture2D(WIDTH, 1, TextureFormat.ARGB32, false);
            texture.wrapMode = TextureWrapMode.Clamp;
            texture.filterMode = FilterMode.Bilinear;
        }

        for (int i = 0; i < WIDTH; ++i)
        {
            var t = (float)i / WIDTH;
            texture.SetPixel(i, 0, gradient.Evaluate(t));
        }
        texture.Apply(false);
    }

    public Texture2D GenerateCombinedTexture(float rangeMin, float rangeMax)
    {

        Texture2D tex = new Texture2D(4096, 8, TextureFormat.ARGB32, false);
        tex.wrapMode = TextureWrapMode.Clamp;
        tex.filterMode = FilterMode.Bilinear;
        
        for(int row = 0; row < 8; row++)
        {
            for (int i = 0; i < 4096; ++i)
            {
                float t = (float)i / 4096;
                float density = Mathf.Lerp(rangeMin, rangeMax, t);
                float x = Mathf.InverseLerp(transferFunction.MinDensity, transferFunction.MaxDensity, density);

                if(row < 2)
                {
                    tex.SetPixel(i, row, transferFunction.Albedo.Evaluate(x));
                }
                else if (row < 4)
                {
                    tex.SetPixel(i, row, transferFunction.Roughness.Evaluate(x));
                }
                else if (row < 6)
                {
                    tex.SetPixel(i, row, transferFunction.Metallic.Evaluate(x));
                }
                else if (row < 8)
                {
                    tex.SetPixel(i, row, transferFunction.Alpha.Evaluate(x));
                }
            }
        }
        tex.Apply(false);
        return tex;
    }
}
