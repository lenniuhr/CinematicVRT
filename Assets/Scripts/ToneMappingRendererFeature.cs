using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using System.Data.Common;
using System.Security.Cryptography;

public class ToneMappingRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        [Range(0, 1)]
        public float ShoulderStrength = 0.22f;
        [Range(0, 1)]
        public float LinearStrength = 0.3f;
        [Range(0, 1)]
        public float LinearAngle = 0.1f;
        [Range(0, 1)]
        public float ToeStrength = 0.2f;
        [Range(0, 1)]
        public float ToeNumerator = 0.01f;
        [Range(0, 1)]
        public float ToeDenominator = 0.3f;
        [Range(0, 20)]
        public float LinearWhite = 11.2f;
        [Range(0.9f, 1.0f)]
        public float WhiteThreshold = 0.98f;
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

        renderer.EnqueuePass(m_RenderPass);
    }

    private class RenderPass : ScriptableRenderPass
    {
        private string name;
        private Material material;

        private RenderTargetIdentifier sourceID;
        private RenderTargetHandle tempRT;

        enum Pass
        {
            Copy,
            ToneMapping
        }

        public RenderPass(string name, Shader shader, Settings settings) : base()
        {
            Debug.Log("Create render pass: " + name);
            this.name = name;
            material = new Material(shader);
            material.hideFlags = HideFlags.HideAndDontSave;
            material.SetFloat("_ShoulderStrength", settings.ShoulderStrength);
            material.SetFloat("_LinearStrength", settings.LinearStrength);
            material.SetFloat("_LinearAngle", settings.LinearAngle);
            material.SetFloat("_ToeStrength", settings.ToeStrength);
            material.SetFloat("_ToeNumerator", settings.ToeNumerator);
            material.SetFloat("_ToeDenominator", settings.ToeDenominator);
            material.SetFloat("_LinearWhite", settings.LinearWhite);

            material.SetFloat("_WhiteThreshold", settings.WhiteThreshold);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.colorFormat = RenderTextureFormat.ARGBFloat;

            sourceID = renderingData.cameraData.renderer.cameraColorTarget;

            tempRT.Init("_TempRT");
            cmd.GetTemporaryRT(tempRT.id, desc, FilterMode.Point);
        }

        private void Draw(CommandBuffer cmd, Pass pass)
        {
            cmd.DrawProcedural(Matrix4x4.identity, material, (int)pass, MeshTopology.Triangles, 3);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(name);

            cmd.SetGlobalTexture("_SourceTex", sourceID);
            cmd.SetRenderTarget(tempRT.id);
            Draw(cmd, Pass.ToneMapping);

            cmd.SetGlobalTexture("_CopyTex", tempRT.id);
            cmd.SetRenderTarget(sourceID);
            Draw(cmd, Pass.Copy);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(tempRT.id);
        }
    }
}
