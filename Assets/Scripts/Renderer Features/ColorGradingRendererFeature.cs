using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

public class ColorGradingRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public float postExposure;

        [Range(-1f, 1f)]
        public float contrast;

        public Color colorFilter = Color.white;

        [Range(-0.5f, 0.5f)]
        public float hueShift;

        [Range(-1f, 1f)]
        public float saturation;
    }

    public Shader shader = default;
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
    public Settings settings = new Settings(); 

    // Private variables
    private RenderPass m_RenderPass;

    public override void Create()
    {
        if (shader == null) return;

        m_RenderPass = new RenderPass(name, shader, settings);
        m_RenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (shader == null) return;

        m_RenderPass.SetSource(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_RenderPass);
    }

    private class RenderPass : ScriptableRenderPass
    {
        private string name;
        private Material material;

        private RenderTargetIdentifier sourceID;
        private RenderTargetHandle tempTextureHandle;

        enum Pass
        {
            ColorGrading
        }

        public RenderPass(string name, Shader shader, Settings settings) : base()
        {
            Debug.Log("Create render pass: " + name);
            this.name = name;
            material = new Material(shader);
            material.hideFlags = HideFlags.HideAndDontSave;
            material.SetColor("_Color", settings.colorFilter.linear);
            material.SetFloat("_PostExposure", Mathf.Pow(2f, settings.postExposure));
            material.SetFloat("_Contrast", settings.contrast + 1.0f);
            material.SetFloat("_HueShift", settings.hueShift);
            material.SetFloat("_Saturation", settings.saturation + 1.0f);

            tempTextureHandle.Init("_TempColorGradingTexture");
        }

        public void SetSource(RenderTargetIdentifier sourceID)
        {
            this.sourceID = sourceID;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (!material)
            {
                return;
            }

            CommandBuffer cmd = CommandBufferPool.Get(name);

            RenderTextureDescriptor cameraTextureDesc = renderingData.cameraData.cameraTargetDescriptor;
            cameraTextureDesc.depthBufferBits = 0;

            cmd.GetTemporaryRT(tempTextureHandle.id, cameraTextureDesc, FilterMode.Bilinear);

            Blit(cmd, sourceID, tempTextureHandle.Identifier(), material, (int)Pass.ColorGrading);
            Blit(cmd, tempTextureHandle.Identifier(), sourceID);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(tempTextureHandle.id);
        }
    }
}
