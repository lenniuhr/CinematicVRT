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
    }

    [Serializable]
    public class OctreeSettings
    {
        public int OctreeLevel = 7;
        public float Threshold = 0.5f;
    }

    [Serializable]
    public class DeltaTrackingSettings
    {
        public int SamplesPerPixel = 1;
        public int MaxSamples = 100;
        public bool Accumulate = false;
        public float GPhaseFunction = 0.0f;
        public float IncreaseThreshold = 0.5f;
        public float SD = 1;
        public float DefocusStrength = 0f;
        public float FocusDistance = 1f;
        public float PTerminate = 0.3f;
    }

    public RenderMode renderMode = RenderMode.VOLUME;
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    private ScriptableRenderPass m_RenderPass;

    public Settings settings = new Settings();
    public OctreeSettings octreeSettings = new OctreeSettings();
    public DeltaTrackingSettings deltaTrackingSettings = new DeltaTrackingSettings();

    public enum RenderMode
    {
        VOLUME,
        OCTREE,
        CINEMATIC
    }

    public void CleanUp()
    {
        if(m_RenderPass != null && m_RenderPass is CinematicRenderPass)
        {
            ((CinematicRenderPass)m_RenderPass).CleanUp();
        }
        if (m_RenderPass != null && m_RenderPass is CinematicRenderPass)
        {
            ((CinematicRenderPass)m_RenderPass).CleanUp();
        }
    }

    public void ResetFrameId()
    {
        if (m_RenderPass != null && m_RenderPass is CinematicRenderPass)
        {
            ((CinematicRenderPass)m_RenderPass).ResetFrameId();
        }
    }

    public int GetFrameId()
    {
        if (m_RenderPass != null && m_RenderPass is CinematicRenderPass)
        {
            return ((CinematicRenderPass)m_RenderPass).GetFrameId();
        }
        return -1;
    }

    public override void Create()
    {
        CleanUp();

        switch (renderMode)
        {
            case RenderMode.VOLUME:
                m_RenderPass = new VolumeRenderPass(settings);
                break;
            case RenderMode.OCTREE:
                m_RenderPass = new OctreeRenderPass(octreeSettings);
                break;
            case RenderMode.CINEMATIC:
                m_RenderPass = new CinematicRenderPass(deltaTrackingSettings);
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
        if(renderingData.cameraData.camera.name == "SceneCamera" || renderingData.cameraData.camera.name == "Main Camera")
        {
            renderer.EnqueuePass(m_RenderPass);
        }
    }

    public void UpdateRenderMode(RenderMode mode)
    {
        this.renderMode = mode;
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
        private RenderTargetIdentifier depthID;

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
            depthID = renderingData.cameraData.renderer.cameraDepthTarget;
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

    private class CinematicRenderPass : ScriptableRenderPass
    {
        private string name = "Cinematic Rendering";
        private Material material;
        private RenderTargetIdentifier sourceID;

        private RenderTargetHandle prevFrame;
        private RenderTargetHandle currentFrame;
        private RenderTexture resultTexture;

        private bool accumulate;
        int frameID = 0;

        int samplesPerPixel = 1;
        int maxSamples = 1;

        float focusDistance;

        enum Pass
        {
            Accumulate,
            Copy,
            DeltaTracking
        }

        public int GetFrameId()
        {
            return frameID;
        }

        public void ResetFrameId()
        {
            frameID = 0;
        }

        public CinematicRenderPass(DeltaTrackingSettings settings)
        {
            this.material = CoreUtils.CreateEngineMaterial("Hidden/CinematicRendering");
            material.hideFlags = HideFlags.HideAndDontSave;
            material.SetFloat("_GPhaseFunction", settings.GPhaseFunction);
            material.SetFloat("_IncreaseThreshold", settings.IncreaseThreshold);
            material.SetFloat("_SD", settings.SD);
            material.SetFloat("_DivergeStrength", settings.DefocusStrength);
            material.SetFloat("_PTerminate", settings.PTerminate); 

            accumulate = settings.Accumulate;
            samplesPerPixel = settings.SamplesPerPixel;
            maxSamples = settings.MaxSamples;
            focusDistance = settings.FocusDistance;
            frameID = 0;
        }

        private bool ResetFrame(Camera cam)
        {
            TransferFunctionManager tf = FindObjectOfType<TransferFunctionManager>();
            if (tf != null && tf.HasChanged())
            {
                return true;
            }

            EnvironmentManager em = FindObjectOfType<EnvironmentManager>();
            if (em != null && em.HasChanged())
            {
                return true;
            }

            VolumeBoundingBox vbb = FindObjectOfType<VolumeBoundingBox>();
            if (vbb != null && vbb.HasChanged())
            {
                return true;
            }

#if UNITY_EDITOR
            // For scene view
            if (cam.transform.hasChanged)
            {
                cam.transform.hasChanged = false;
                return true;
            }
#else
            CameraUpdateChecker camUpdateChecker = FindObjectOfType<CameraUpdateChecker>();
            if (camUpdateChecker != null && camUpdateChecker.HasChanged())
            {
                return true;
            }
#endif

            return false;
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

            if(ResetFrame(renderingData.cameraData.camera))
            {
                resultTexture.Release();
                resultTexture = new RenderTexture(desc);
                resultTexture.Create();
                frameID = 0;
            }

            cmd.GetTemporaryRT(currentFrame.id, desc, FilterMode.Point);
            cmd.GetTemporaryRT(prevFrame.id, desc, FilterMode.Point);
        }
        
        public void CleanUp()
        {
            if(resultTexture != null)
            {
                resultTexture.Release();
            }
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(currentFrame.id);
            cmd.ReleaseTemporaryRT(prevFrame.id);
        }

        void UpdateCameraParams(Camera cam)
        {
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

            using (new ProfilingScope(cmd, new ProfilingSampler(name)))
            {
                cmd.BeginSample(name);

                if (!accumulate)
                {
                    cmd.SetRenderTarget(resultTexture);
                    cmd.ClearRenderTarget(RTClearFlags.All, Color.clear, 0, 255);
                    frameID = 0;
                }
                
                if(frameID < maxSamples)
                {
                    for (int i = 0; i < samplesPerPixel; i++)
                    {
                        cmd.SetGlobalInteger("_FrameID", frameID);

                        // Copy "resultTexture" to "prevFrame"
                        cmd.SetRenderTarget(prevFrame.id);
                        cmd.SetGlobalTexture("_CopyTex", resultTexture);
                        Draw(cmd, Pass.Copy);

                        // Render RayTracing Pass to "currentFrame"
                        cmd.SetRenderTarget(currentFrame.id);
                        cmd.ClearRenderTarget(RTClearFlags.All, Color.clear, 0, 255);
                        Draw(cmd, Pass.DeltaTracking);

                        // Accumulate "currentFrame" and "prevFrame" together to "resultTexture"
                        cmd.SetRenderTarget(resultTexture);
                        cmd.SetGlobalTexture("_PrevFrame", prevFrame.id);
                        cmd.SetGlobalTexture("_CurrentFrame", currentFrame.id);
                        Draw(cmd, Pass.Accumulate);

                        frameID++;

                        if (frameID % 100 == 0)
                        {
                            Debug.Log("Rendered " + frameID + " frames");
                        }
                    }
                }
                // Copy "resultTexture" to source
                cmd.SetRenderTarget(sourceID);
                cmd.SetGlobalTexture("_CopyTex", resultTexture);
                Draw(cmd, Pass.Copy);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
