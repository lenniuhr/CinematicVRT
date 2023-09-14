using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static UnityEngine.Mathf;

public class VolumeRenderingRendererFeature : ScriptableRendererFeature
{
    [Serializable]
    public class Settings
    {
        [Range(0.00001f, 0.01f)]
        public float StepSize = 0.004f;
        [Range(0, 2)]
        public float NormalOffset = 1f;
        [Range(0, 1)]
        public float Threshold = 0.2f;
    }
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRendering;
    public Settings settings = new Settings();

    private VolumeRenderingPass m_RenderPass;

    public override void Create()
    {
        m_RenderPass = new VolumeRenderingPass(name, settings);
        m_RenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_RenderPass);
    }

    private class VolumeRenderingPass : ScriptableRenderPass
    {
        private string name;
        private Material material;

        private RenderTargetIdentifier sourceID;

        enum Pass
        {
            VolumeRendering
        }

        public VolumeRenderingPass(string name, Settings settings)
        {
            this.name = name;
            this.material = CoreUtils.CreateEngineMaterial("Hidden/VolumeRendering");
            material.hideFlags = HideFlags.HideAndDontSave;

            material.SetFloat("_StepSize", settings.StepSize);
            material.SetFloat("_NormalOffset", settings.NormalOffset);
            material.SetFloat("_Threshold", settings.Threshold);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;

            UpdateCameraParams(renderingData.cameraData.camera);

            sourceID = renderingData.cameraData.renderer.cameraColorTarget;
        }

        void UpdateCameraParams(Camera cam)
        {
            float focusDistance = 1;

            float planeHeight = focusDistance * Tan(cam.fieldOfView * 0.5f * Deg2Rad) * 2;
            float planeWidth = planeHeight * cam.aspect;

            // Send data to shader
            material.SetVector("_ViewParams", new Vector3(planeWidth, planeHeight, focusDistance));
            material.SetMatrix("_CamLocalToWorldMatrix", cam.transform.localToWorldMatrix);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {

        }

        void Draw(CommandBuffer cmd, RenderTargetIdentifier depthSource, RenderTargetIdentifier destination, Pass pass)
        {
            cmd.SetRenderTarget(destination, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, depthSource, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            cmd.DrawProcedural(Matrix4x4.identity, material, (int)pass, MeshTopology.Triangles, 3);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(name);

            using (new ProfilingScope(cmd, new ProfilingSampler("Volume Rendering Pass")))
            {
                cmd.BeginSample("Volume Rendering");

                Draw(cmd, sourceID, sourceID, Pass.VolumeRendering);
                
                cmd.EndSample("Volume Rendering");
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
