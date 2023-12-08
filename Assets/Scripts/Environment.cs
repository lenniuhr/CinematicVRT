using UnityEngine;

[CreateAssetMenu]
public class Environment : ScriptableObject
{
    public Cubemap EnvironmentMap;
    public Cubemap IrradianceMap;
    public Cubemap ReflectionMap;
}
