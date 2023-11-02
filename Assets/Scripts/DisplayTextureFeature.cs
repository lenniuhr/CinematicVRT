using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DisplayTextureFeature : ScriptableRendererFeature
{
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRendering;
    private ScriptableRenderPass m_RenderPass;


    public override void Create()
    {
        m_RenderPass = new DisplayTextureRenderPass();
        m_RenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_RenderPass);
    }

    private class DisplayTextureRenderPass : ScriptableRenderPass
    {
        private string name = "Display Texture";

        private RenderTargetIdentifier sourceID;

        public DisplayTextureRenderPass()
        {

        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            sourceID = renderingData.cameraData.renderer.cameraColorTarget;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(name);

            using (new ProfilingScope(cmd, new ProfilingSampler(name)))
            {
                cmd.BeginSample(name);

                RenderTexture display = FindObjectOfType<VolumeClassifier>().displayImage;
                cmd.Blit(display, sourceID);
                cmd.Blit(display, sourceID);

                cmd.EndSample(name);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
