using UnityEngine;

[ExecuteInEditMode]
public class TransferFunctionManager : MonoBehaviour
{
    public TransferFunction transferFunction;

    private const int WIDTH = 2048;

    private bool hasChanged = false;

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

        Texture2D albedoTexture = GenerateTexture(transferFunction.Albedo);
        Texture2D roughnessTexture = GenerateTexture(transferFunction.Roughness);
        Texture2D alphaTexture = GenerateTexture(transferFunction.Alpha);

        Shader.SetGlobalTexture("_AlbedoTex", albedoTexture);
        Shader.SetGlobalTexture("_RoughnessTex", roughnessTexture);
        Shader.SetGlobalTexture("_AlphaTex", alphaTexture);
        Shader.SetGlobalFloat("_SigmaT", transferFunction.SigmaT);
        Shader.SetGlobalFloat("_MinDensity", transferFunction.MinDensity);
        Shader.SetGlobalFloat("_MaxDensity", transferFunction.MaxDensity);
        Shader.SetGlobalFloat("_GradientShift", transferFunction.GradientShift);
        Shader.SetGlobalFloat("_GradientLimit", transferFunction.GradientLimit);

        Debug.Log("Updated Transfer Texture");
        hasChanged = true;
    }

    private Texture2D GenerateTexture(Gradient gradient)
    {
        Texture2D texture = new Texture2D(WIDTH, 1, TextureFormat.ARGB32, false);
        texture.wrapMode = TextureWrapMode.Clamp;
        texture.filterMode = FilterMode.Bilinear;

        for (int i = 0; i < WIDTH; ++i)
        {
            var t = (float)i / WIDTH;
            texture.SetPixel(i, 0, gradient.Evaluate(t));
        }
        texture.Apply(false);

        return texture;
    }
}
