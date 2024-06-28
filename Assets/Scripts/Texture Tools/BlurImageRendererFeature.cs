using System;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

public class BlurImageRendererFeature : ScriptableRendererFeature
{
    public enum FilterMode
    {
        Bilateral = 0,
        Gaussian = 1
    }

    [Serializable]
    public class Settings
    {
        public Texture2D Texture;
        public FilterMode FilterMode;
        [Range(0, 10)] 
        public int KernelRadius;
        [Range(0.001f, 50)]
        public float Sigma;
        [Range(0.001f, 10)]
        public float SigmaR;
    }
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRendering;
    public Settings settings = new Settings();

    private BlurImageRenderingPass m_RenderPass;

    public override void Create()
    {
        m_RenderPass = new BlurImageRenderingPass(name, settings);
        m_RenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_RenderPass);
    }

    private class BlurImageRenderingPass : ScriptableRenderPass
    {
        private string name;
        private Material material;

        private RenderTargetIdentifier sourceID;

        private FilterMode filterMode;

        enum Pass
        {
            BilateralBlur,
            GaussianBlur,
        }

        public BlurImageRenderingPass(string name, Settings settings)
        {
            this.name = name;
            this.filterMode = settings.FilterMode;

            this.material = CoreUtils.CreateEngineMaterial("Hidden/BlurImage");
            material.hideFlags = HideFlags.HideAndDontSave;
            material.SetTexture("_MainTex", settings.Texture);
            material.SetInt("_KernelRadius", settings.KernelRadius);
            material.SetFloat("_Sigma", settings.Sigma);
            material.SetFloat("_SigmaR", settings.SigmaR);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            sourceID = renderingData.cameraData.renderer.cameraColorTarget;
        }

        void Draw(CommandBuffer cmd, RenderTargetIdentifier destination, Pass pass)
        {
            cmd.SetRenderTarget(destination);
            cmd.DrawProcedural(Matrix4x4.identity, material, (int)pass, MeshTopology.Triangles, 3);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(name);

            using (new ProfilingScope(cmd, new ProfilingSampler("Blur Image Pass")))
            {
                cmd.BeginSample("Blur Image");

                switch (filterMode)
                {
                    case FilterMode.Bilateral:
                        Draw(cmd, sourceID, Pass.BilateralBlur);
                        break;
                    case FilterMode.Gaussian:
                        Draw(cmd, sourceID, Pass.GaussianBlur);
                        break;
                }
                

                cmd.EndSample("Blur Image");
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
