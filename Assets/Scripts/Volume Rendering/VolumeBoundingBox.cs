using UnityEngine;

[ExecuteAlways]
public class VolumeBoundingBox : MonoBehaviour
{
    public VolumeDataset dataset;

    [Range(0, 1)]
    public float ClampRadius = 0.45f;

    private bool _initalized = false;

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

    private void Update()
    {
        if(transform.hasChanged)
        {
            transform.hasChanged = false;
            hasChanged = true;
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
}
