using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class EnvironmentManager : MonoBehaviour
{

    public Texture EnvironmentMap4K;
    public Texture EnvironmentMap1K;

    public Cubemap EnvironmentMap;
    public Cubemap IrradianceMap;
    public Cubemap ReflectionMap;

    public ComputeShader computeShader;

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
        Shader.SetGlobalTexture("_EnvironmentMap", EnvironmentMap);
        Shader.SetGlobalTexture("_IrradianceMap", IrradianceMap);
        Shader.SetGlobalTexture("_ReflectionMap", ReflectionMap);
    }

    public void GenerateIrradianceTexture()
    {

    }
}
