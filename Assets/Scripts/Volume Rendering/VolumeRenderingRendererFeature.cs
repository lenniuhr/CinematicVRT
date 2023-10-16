using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static UnityEngine.GraphicsBuffer;
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

    [Serializable]
    public class OctreeSettings
    {
        public int OctreeLevel = 7;
        public float Threshold = 0.5f;
    }

    public RenderMode renderMode = RenderMode.VOLUME;
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRendering;
    private ScriptableRenderPass m_RenderPass;

    public Settings settings = new Settings();
    public OctreeSettings octreeSettings = new OctreeSettings();

    public enum RenderMode
    {
        VOLUME,
        OCTREE,
        RAYTRACE
    }

    public override void Create()
    {
        switch (renderMode)
        {
            case RenderMode.VOLUME:
                m_RenderPass = new VolumeRenderPass(settings);
                Debug.Log($"Created Volume Render Pass");
                break;
            case RenderMode.OCTREE:
                m_RenderPass = new OctreeRenderPass(octreeSettings);
                Debug.Log($"Created Octree Render Pass");
                break;
            case RenderMode.RAYTRACE:
                m_RenderPass = new CinematicRenderPass(settings);
                Debug.Log($"Created Cinematic Render Pass");
                break;
        }
        m_RenderPass.renderPassEvent = renderPassEvent;
    }

    private void OnValidate()
    {
        Debug.Log("Value change");
        Create();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_RenderPass);
    }

    public void UpdateRenderMode(RenderMode mode)
    {
        this.renderMode = mode;
    }

    private class CinematicRenderPass : ScriptableRenderPass
    {
        private string name = "Cinematic Rendering";
        private Material material;
        private RenderTargetIdentifier sourceID;

        int frameID = 0;
        
        enum Pass
        {
            RayTracing
        }

        public CinematicRenderPass(Settings settings)
        {
            this.material = CoreUtils.CreateEngineMaterial("Hidden/CinematicRendering");
            material.hideFlags = HideFlags.HideAndDontSave;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;

            UpdateCameraParams(renderingData.cameraData.camera);

            sourceID = renderingData.cameraData.renderer.cameraColorTarget;

            frameID = 0;
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

        void Draw(CommandBuffer cmd, RenderTargetIdentifier depthSource, RenderTargetIdentifier destination, Pass pass)
        {
            cmd.SetRenderTarget(destination, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, depthSource, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            cmd.DrawProcedural(Matrix4x4.identity, material, (int)pass, MeshTopology.Triangles, 3);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(name);

            using (new ProfilingScope(cmd, new ProfilingSampler(name)))
            {
                cmd.BeginSample(name);

                /*
                // Create copy of previous frame
                cmd.SetGlobalTexture(copyTex, currentFrame.id);
                Draw(cmd, sourceID, prevFrame.id, Pass.Copy);

                // Clear result texture
                cmd.SetRenderTarget(result.id, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cmd.ClearRenderTarget(RTClearFlags.All, Color.clear, 0, 255);

                // Ray trace to result texture
                Draw(cmd, sourceID, result.id, Pass.RayTracing);

                // Accumulate
                Draw(cmd, sourceID, currentFrame.id, Pass.Accumulate);

                // Copy from current frame texture to camera source
                cmd.SetGlobalTexture(copyTex, currentFrame.id);
                Draw(cmd, sourceID, sourceID, Pass.Copy);
                frameID++;
                */

                Draw(cmd, sourceID, sourceID, Pass.RayTracing);

                cmd.EndSample(name);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    private class VolumeRenderPass : ScriptableRenderPass
    {
        private string name = "Volume Rendering";
        private Material material;
        private RenderTargetIdentifier sourceID;

        enum Pass
        {
            VolumeRendering,
            Octree,
            Raytrace
        }

        public VolumeRenderPass(Settings settings)
        {
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

            using (new ProfilingScope(cmd, new ProfilingSampler(name)))
            {
                cmd.BeginSample(name);

                Draw(cmd, sourceID, sourceID, Pass.VolumeRendering);
                    
                cmd.EndSample(name);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    private class OctreeRenderPass : ScriptableRenderPass
    {
        private string name = "Octree Rendering";
        private Material material;
        private RenderTargetIdentifier sourceID;

        enum Pass
        {
            Octree
        }

        public OctreeRenderPass(OctreeSettings octreeSettings)
        {
            this.material = CoreUtils.CreateEngineMaterial("Hidden/OctreeRendering");
            material.hideFlags = HideFlags.HideAndDontSave;
            material.SetFloat("_Threshold", octreeSettings.Threshold);
            material.SetInt("_OctreeLevel", octreeSettings.OctreeLevel);
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

        void Draw(CommandBuffer cmd, RenderTargetIdentifier depthSource, RenderTargetIdentifier destination, Pass pass)
        {
            cmd.SetRenderTarget(destination, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, depthSource, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            cmd.DrawProcedural(Matrix4x4.identity, material, (int)pass, MeshTopology.Triangles, 3);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(name);

            using (new ProfilingScope(cmd, new ProfilingSampler(name)))
            {
                cmd.BeginSample(name);

                Draw(cmd, sourceID, sourceID, Pass.Octree);

                cmd.EndSample(name);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
