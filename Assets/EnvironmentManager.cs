using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class EnvironmentManager : MonoBehaviour
{
    public Environment environment;
    public bool showEnvironment = true;

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
        if (environment == null || environment.EnvironmentMap == null || environment.IrradianceMap == null || environment.ReflectionMap == null)
        {
            Debug.LogWarning("Environent missing!");
            return;
        }
        UpdateShaderParams();
    }

    private void OnValidate()
    {
        UpdateShaderParams();
        hasChanged = true;
    }

    private void UpdateShaderParams()
    {
        if(environment == null)
        {
            return;
        }

        Shader.SetGlobalTexture("_EnvironmentMap", environment.EnvironmentMap);
        Shader.SetGlobalTexture("_IrradianceMap", environment.IrradianceMap);
        Shader.SetGlobalTexture("_ReflectionMap", environment.ReflectionMap);
        Shader.SetGlobalInteger("_ShowEnvironment", showEnvironment ? 1 : 0);
    }

    public void GenerateIrradianceTexture()
    {

    }
}
