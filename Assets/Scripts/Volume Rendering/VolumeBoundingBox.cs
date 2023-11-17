using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using static VolumeClassifier;

[ExecuteInEditMode]
public class VolumeBoundingBox : MonoBehaviour
{
    public VolumeDataset dataset;

    private Texture3D dataTexture;
    private RenderTexture gradientTexture2;


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
        UpdateShaderVariables();
    }

    private void OnValidate()
    {
        Debug.Log("Set gradient tex");
        Shader.SetGlobalTexture("_GradientTex", gradientTexture2);

        UpdateShaderVariables();
    }

    public Texture3D GetDataTexture()
    {
        return dataTexture;
    }

    public RenderTexture GetGradientTexture()
    {
        return gradientTexture2;
    }

    public void ReloadTextures()
    {
        if (dataset == null) return;

        //dataTexture = await dataset.GetTexture();
        dataTexture = dataset.dataTex;

        GenerateGradientTexture();

        Debug.Log("Generated Textures");

        if (dataset != null)
        {
            transform.localScale = dataset.GetScale();
            Shader.SetGlobalTexture("_GradientTex", gradientTexture2);
            Shader.SetGlobalTexture("_VolumeTex", dataset.dataTex);
        }
        else
        {
            Texture3D emptyTex = new Texture3D(1, 1, 1, TextureFormat.R8, false);
            emptyTex.SetPixel(0, 0, 0, Color.clear);
            emptyTex.Apply();
            Shader.SetGlobalTexture("_VolumeTex", emptyTex);
        }
    }

    private void UpdateShaderVariables()
    {
        Shader.SetGlobalVector("_VolumePosition", transform.position);
        Shader.SetGlobalVector("_VolumeScale", transform.localScale);
        Shader.SetGlobalMatrix("_VolumeWorldToLocalMatrix", transform.worldToLocalMatrix);
        Shader.SetGlobalMatrix("_VolumeLocalToWorldMatrix", transform.localToWorldMatrix);
    }

    public void GenerateGradientTexture()
    {
        // Initalize
        int kernel = computeShader.FindKernel("GenerateGradient");

        Texture3D densityTex = dataset.dataTex;

        if (densityTex == null) return;

        ShaderHelper.CreateRenderTexture3D(ref gradientTexture2, densityTex.width, densityTex.height, densityTex.depth, "Gradient", RenderTextureFormat.ARGB32);

        // Run compute shader
        computeShader.SetTexture(kernel, "_DensityTex", densityTex);
        computeShader.SetTexture(kernel, "_GradientTex", gradientTexture2);
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
