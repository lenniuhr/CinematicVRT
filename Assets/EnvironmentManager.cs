using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class EnvironmentManager : MonoBehaviour
{
    public Cubemap EnvironmentMap;
    public Cubemap IrradianceMap;
    public Cubemap ReflectionMap;
    public bool ShowEnvironment = true;

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
        Shader.SetGlobalInteger("_ShowEnvironment", ShowEnvironment ? 1 : 0);
    }

    public void GenerateIrradianceTexture()
    {

    }
}
