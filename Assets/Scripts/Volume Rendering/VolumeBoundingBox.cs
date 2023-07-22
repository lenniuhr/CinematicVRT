using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class VolumeBoundingBox : MonoBehaviour
{
    public Texture3D texture;

    public VolumeDataset volumeData;

    private void OnValidate()
    {
        if (volumeData != null)
        {
            Shader.SetGlobalTexture("_VolumeTex", volumeData.GetTexture());
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
    }
}
