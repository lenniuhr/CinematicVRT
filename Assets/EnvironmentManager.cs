using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class EnvironmentManager : MonoBehaviour
{
    public Cubemap Skybox;

    private void OnEnable()
    {
        UpdateShaderParams();
    }

    private void OnValidate()
    {
        UpdateShaderParams();
    }

    private void UpdateShaderParams()
    {
        if (Skybox == null) return;

        Shader.SetGlobalTexture("_Skybox", Skybox);
    }
}
