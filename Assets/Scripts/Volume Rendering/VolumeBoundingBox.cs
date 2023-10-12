using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class VolumeBoundingBox : MonoBehaviour
{
    public VolumeDataset dataset;

    [Range(0, 1)]
    public float Roughness;
    [Range(0, 1)]
    public float Metallicness;

    private Texture3D dataTexture;
    private Texture3D gradientTexture;

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
        UpdateShaderVariables();
    }

    public Texture3D GetDataTexture()
    {
        return dataTexture;
    }

    public async void ReloadTextures()
    {
        if (dataset == null) return;

        dataTexture = await dataset.GetTexture();
        gradientTexture = await dataset.GetGradientTexture();

        Debug.Log("Generated Textures");

        if (dataset != null)
        {
            transform.localScale = dataset.GetScale();
            Shader.SetGlobalTexture("_VolumeTex", dataTexture);
            Shader.SetGlobalTexture("_GradientTex", gradientTexture);
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

        Shader.SetGlobalFloat("_Roughness", Roughness);
        Shader.SetGlobalFloat("_Metallicness", Metallicness);
    }
}
