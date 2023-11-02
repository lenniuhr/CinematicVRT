using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static UnityEngine.Mathf;

public class RenderModeRendererFeature : ScriptableRendererFeature
{
    [Serializable]
    public class Settings
    {
        public float StepSize = 0.001f;
        public float Threshold = 0.5f;
        public Color Color = Color.white;
    }

    [Serializable]
    public class OctreeSettings
    {
        public int OctreeLevel = 7;
        public float Threshold = 0.5f;
    }

    [Serializable]
    public class CinematicSettings
    {
        public float Threshold = 0.5f;
        public Color Color = Color.white;
    }

    public RenderMode renderMode = RenderMode.VOLUME;
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    private ScriptableRenderPass m_RenderPass;

    public Settings settings = new Settings();
    public OctreeSettings octreeSettings = new OctreeSettings();
    public CinematicSettings cinematicSettings = new CinematicSettings();

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
                break;
            case RenderMode.OCTREE:
                m_RenderPass = new OctreeRenderPass(octreeSettings);
                break;
            case RenderMode.RAYTRACE:
                m_RenderPass = new CinematicRenderPass(cinematicSettings);
                break;
        }
        m_RenderPass.renderPassEvent = renderPassEvent;
    }

    private void OnValidate()
    {
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

        private int copyTexShaderId = Shader.PropertyToID("_CopyTex");

        private RenderTargetHandle prevFrame;
        private RenderTargetHandle currentFrame;

        private RenderTexture resultTexture;

        int frameID = 0;
        
        enum Pass
        {
            Accumulate,
            Copy,
            RayTracing
        }

        public CinematicRenderPass(CinematicSettings settings)
        {
            this.material = CoreUtils.CreateEngineMaterial("Hidden/CinematicRendering");
            material.hideFlags = HideFlags.HideAndDontSave;
            material.SetFloat("_Threshold", settings.Threshold);
            material.SetColor("_Color", settings.Color.linear);

            frameID = 0;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;

            UpdateCameraParams(renderingData.cameraData.camera);

            sourceID = renderingData.cameraData.renderer.cameraColorTarget;

            desc.colorFormat = RenderTextureFormat.ARGBFloat;

            // Accumulation texture
            if (resultTexture == null)
            {
                resultTexture = new RenderTexture(desc);
                resultTexture.Create();
            }

            currentFrame.Init("_CurrentFrame");
            prevFrame.Init("_PrevFrame");

            cmd.GetTemporaryRT(currentFrame.id, desc, FilterMode.Point);
            cmd.GetTemporaryRT(prevFrame.id, desc, FilterMode.Point);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(currentFrame.id);
            cmd.ReleaseTemporaryRT(prevFrame.id);
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

        private void Draw(CommandBuffer cmd, Pass pass)
        {
            cmd.DrawProcedural(Matrix4x4.identity, material, (int)pass, MeshTopology.Triangles, 3);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(name);

            material.SetInt("_FrameID", frameID);

            using (new ProfilingScope(cmd, new ProfilingSampler(name)))
            {
                cmd.BeginSample(name);

                
                // Copy "resultTexture" to "prevFrame"
                cmd.SetGlobalTexture("_CopyTex", resultTexture);
                cmd.SetRenderTarget(prevFrame.id);
                Draw(cmd, Pass.Copy);

                // Render RayTracing Pass to "currentFrame"
                cmd.SetRenderTarget(currentFrame.id);
                cmd.ClearRenderTarget(RTClearFlags.All, Color.clear, 0, 255);
                Draw(cmd, Pass.RayTracing);

                // Accumulate "currentFrame" and "prevFrame" together to "resultTexture"
                //cmd.SetGlobalTexture("_PrevFrame", prevFrame.id);
                //cmd.SetGlobalTexture("_CurrentFrame", currentFrame.id);
                cmd.SetRenderTarget(resultTexture);
                Draw(cmd, Pass.Accumulate);

                // Copy current frame to result texture
                //cmd.SetGlobalTexture("_CopyTex", currentFrame.id);
                //cmd.SetRenderTarget(resultTexture);
                //cmd.DrawProcedural(Matrix4x4.identity, material, (int)Pass.Copy, MeshTopology.Triangles, 3);

                // Copy "resultTexture" to source
                cmd.SetGlobalTexture("_CopyTex", prevFrame.id);
                cmd.SetRenderTarget(sourceID);
                Draw(cmd, Pass.Copy);
                
                /*
                cmd.SetRenderTarget(sourceID);
                cmd.ClearRenderTarget(RTClearFlags.All, Color.clear, 0, 255);
                Draw(cmd, Pass.RayTracing);
                */

                /*
                // Clear result texture
                cmd.SetRenderTarget(result.id, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cmd.ClearRenderTarget(RTClearFlags.All, Color.clear, 0, 255);

                // Ray trace to result texture
                Draw(cmd, sourceID, result.id, Pass.RayTracing);

                // Accumulate
                cmd.SetGlobalTexture(prevFrameShaderId, prevRT);
                Draw(cmd, sourceID, currentFrame.id, Pass.Accumulate);

                // Copy to previous frame RT
                cmd.SetGlobalTexture(copyTexShaderId, currentFrame.id);
                cmd.SetRenderTarget(prevRT, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cmd.DrawProcedural(Matrix4x4.identity, material, (int)Pass.Copy, MeshTopology.Triangles, 3);

                // Copy from current frame texture to camera source
                cmd.SetGlobalTexture(copyTexShaderId, currentFrame.id);
                Draw(cmd, sourceID, sourceID, Pass.Copy);

                // Make sure that the render target is reset to the source
                cmd.SetRenderTarget(sourceID);
                */

                cmd.EndSample(name);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);

            frameID++;
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
            material.SetFloat("_Threshold", settings.Threshold);
            material.SetColor("_Color", settings.Color);
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
