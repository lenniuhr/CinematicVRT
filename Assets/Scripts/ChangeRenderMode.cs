using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

public class ChangeRenderMode : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        ScriptableRenderer renderer = (GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset).GetRenderer(0);
        var property = typeof(ScriptableRenderer).GetProperty("rendererFeatures", BindingFlags.NonPublic | BindingFlags.Instance);
        List<ScriptableRendererFeature> features = property.GetValue(renderer) as List<ScriptableRendererFeature>;

        foreach (var feature in features)
        {
            if (feature.GetType() == typeof(RenderModeRendererFeature))
            {
                (feature as RenderModeRendererFeature).UpdateRenderMode(RenderModeRendererFeature.RenderMode.OCTREE);
            }
        }
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
