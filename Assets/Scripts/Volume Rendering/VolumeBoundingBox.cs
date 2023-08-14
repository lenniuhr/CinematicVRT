using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class VolumeBoundingBox : MonoBehaviour
{
    public VolumeDataset dataset;


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

    private async void UpdateShaderVariables()
    {
        if (dataset != null)
        {
            transform.localScale = dataset.GetScale();
            Shader.SetGlobalTexture("_VolumeTex", await dataset.GetTexture());
            Shader.SetGlobalTexture("_GradientTex", await dataset.GetGradientTexture());
        }
        else
        {
            Texture3D emptyTex = new Texture3D(1, 1, 1, TextureFormat.R8, false);
            emptyTex.SetPixel(0, 0, 0, Color.clear);
            emptyTex.Apply();
            Shader.SetGlobalTexture("_VolumeTex", emptyTex);
        }
        Shader.SetGlobalVector("_VolumePosition", transform.position);
        Shader.SetGlobalVector("_VolumeScale", transform.localScale);
        Shader.SetGlobalMatrix("_VolumeWorldToLocalMatrix", transform.worldToLocalMatrix);
    }
}
