using UnityEngine;

[ExecuteAlways]
public class VolumeBoundingBox : MonoBehaviour
{
    public VolumeDataset dataset;

    [Range(0, 1)]
    public float ClampRadius = 0.45f;

    private bool _initalized = false;

    private RenderTexture gradientTexture;
    public ComputeShader computeShader;

    private void Update()
    {
        if(transform.hasChanged)
        {
            transform.hasChanged = false;
            UpdateShaderVariables();
        }
    }

    private void OnEnable()
    {
        Initialize();
    }

    private void OnValidate()
    {
        Initialize();
    }

    public bool IsInitialized()
    {
        return _initalized;
    }

    public void Initialize()
    {
        if (dataset == null || dataset.dataTex == null)
        {
            _initalized = false;
            Debug.LogWarning("No Volume Texture Found!");
        }

        transform.localScale = dataset.GetScale();
        UpdateTexture();
        UpdateShaderVariables();
        _initalized = true;
    }

    private void UpdateTexture()
    {
        Shader.SetGlobalTexture("_VolumeTex", dataset.dataTex);
        Shader.SetGlobalVector("_VolumeTexelSize", new Vector3(1.0f / dataset.dataTex.width, 1.0f / dataset.dataTex.height, 1.0f / dataset.dataTex.depth));
    }

    private void UpdateShaderVariables()
    {
        Shader.SetGlobalFloat("_VolumeClampRadius", ClampRadius);
        Shader.SetGlobalVector("_VolumePosition", transform.position);
        Shader.SetGlobalVector("_VolumeScale", transform.localScale);

        Shader.SetGlobalMatrix("_VolumeWorldToLocalMatrix", transform.worldToLocalMatrix);
        Shader.SetGlobalMatrix("_VolumeLocalToWorldMatrix", transform.localToWorldMatrix);
    }






    public Texture3D GetDataTexture()
    {
        return dataset.dataTex;
    }

    public RenderTexture GetGradientTexture()
    {
        return gradientTexture;
    }

    public void ReloadTextures()
    {
        if (dataset == null) return;

        GenerateGradientTexture();

        Debug.Log("Generated Textures");

        if (dataset != null)
        {
            transform.localScale = dataset.GetScale();
            Shader.SetGlobalTexture("_GradientTex", gradientTexture);
            Shader.SetGlobalTexture("_VolumeTex", dataset.dataTex);
            Shader.SetGlobalVector("_VolumeTexelSize", new Vector3(1.0f / dataset.dataTex.width, 1.0f / dataset.dataTex.height, 1.0f / dataset.dataTex.depth));
        }
        else
        {
            Texture3D emptyTex = new Texture3D(1, 1, 1, TextureFormat.R8, false);
            emptyTex.SetPixel(0, 0, 0, Color.clear);
            emptyTex.Apply();
            Shader.SetGlobalTexture("_VolumeTex", emptyTex);
        }
    }

    public void GenerateGradientTexture()
    {
        // Initalize
        int kernel = computeShader.FindKernel("GenerateGradient");

        Texture3D densityTex = dataset.dataTex;

        if (densityTex == null) return;

        ShaderHelper.CreateRenderTexture3D(ref gradientTexture, densityTex.width, densityTex.height, densityTex.depth, "Gradient", RenderTextureFormat.ARGB32);

        // Run compute shader
        computeShader.SetTexture(kernel, "_DensityTex", densityTex);
        computeShader.SetTexture(kernel, "_GradientTex", gradientTexture);
        computeShader.SetFloat("_RangeMin", dataset.GetRangeMin());
        computeShader.SetFloat("_RangeMax", dataset.GetRangeMax());
        computeShader.SetVector("_Dimension", new Vector4(densityTex.width, densityTex.height, densityTex.depth));

        Debug.Log($"Texture size: ({densityTex.width}, {densityTex.height}, {densityTex.depth})...");

        computeShader.GetKernelThreadGroupSizes(kernel, out uint threadGroupSizeX, out uint threadGroupSizeY, out uint threadGroupSizeZ);
        int threadGroupsX = Mathf.CeilToInt(densityTex.width / (float)threadGroupSizeX);
        int threadGroupsY = Mathf.CeilToInt(densityTex.height / (float)threadGroupSizeY);
        int threadGroupsZ = Mathf.CeilToInt(densityTex.depth / (float)threadGroupSizeZ);

        Debug.Log($"Dispatch Size: ({threadGroupsX}, {threadGroupsY}, {threadGroupsZ})");
        computeShader.Dispatch(kernel, threadGroupsX, threadGroupsY, threadGroupsZ);

        Debug.Log("Finished classification");
    }
}
