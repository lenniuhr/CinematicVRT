using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SetDepthFeature : ScriptableRendererFeature
{
    public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingSkybox;
    private ScriptableRenderPass m_RenderPass;

    public override void Create()
    {
        m_RenderPass = new SetDepthRenderPass();
        m_RenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_RenderPass);
    }

    private class SetDepthRenderPass : ScriptableRenderPass
    {
        private string name = "Set Depth";
        private Material material;
        private RenderTargetIdentifier depthID;

        enum Pass
        {
            Depth
        }

        public SetDepthRenderPass()
        {
            this.material = CoreUtils.CreateEngineMaterial("Hidden/OctreeRendering");
            material.hideFlags = HideFlags.HideAndDontSave;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            depthID = renderingData.cameraData.renderer.cameraDepthTarget;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(name);

            using (new ProfilingScope(cmd, new ProfilingSampler(name)))
            {
                cmd.BeginSample(name);

                cmd.SetRenderTarget(depthID);
                cmd.DrawProcedural(Matrix4x4.identity, material, (int)Pass.Depth, MeshTopology.Triangles, 3);

                cmd.EndSample(name);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
