using UnityEditor;

[CustomEditor(typeof(VolumeRenderingRendererFeature))]
public class RenderFeatureEditor : Editor
{
    public override void OnInspectorGUI()
    {
        VolumeRenderingRendererFeature rendererFeature = (VolumeRenderingRendererFeature)target;
        
        switch(rendererFeature.renderMode)
        {

        }
    }
}
