using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static UnityEngine.Mathf;

public class RayTracingRendererFeature : ScriptableRendererFeature
{
    [Serializable]
    public class Settings
    {

    }
    public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    public Shader rayTracingShader;
    public Settings settings = new Settings();

    private RayTracingPass m_RenderPass;

    public override void Create()
    {
        m_RenderPass = new RayTracingPass(name);
        m_RenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_RenderPass);
    }

    private class RayTracingPass : ScriptableRenderPass
    {
        private string name;
        private Material material;

        private RenderTargetIdentifier sourceID;
        private RenderTargetHandle resultID;

        // Buffers
        ComputeBuffer sphereBuffer;

        private int sourceTexShaderId = Shader.PropertyToID("_ResultTex");

        enum Pass
        {
            Copy,
            RayTracing
        }

        public RayTracingPass(string name)
        {
            Debug.Log("Created renderer feature: " + name);
            this.name = name;
            this.material = CoreUtils.CreateEngineMaterial("Hidden/RayTracing");
            material.hideFlags = HideFlags.HideAndDontSave;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;

            UpdateCameraParams(renderingData.cameraData.camera);

            sourceID = renderingData.cameraData.renderer.cameraColorTarget;

            cmd.GetTemporaryRT(resultID.id, desc, FilterMode.Point);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(resultID.id);
        }

        void Draw(CommandBuffer cmd, RenderTargetIdentifier depthSource, RenderTargetIdentifier destination, Pass pass)
        {
            cmd.SetRenderTarget(destination, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, depthSource, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            cmd.DrawProcedural(Matrix4x4.identity, material, (int)pass, MeshTopology.Triangles, 3);
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

        void CreateSpheres()
        {
            // Create sphere data from the sphere objects in the scene
            RayTracedSphere[] sphereObjects = FindObjectsOfType<RayTracedSphere>();
            Sphere[] spheres = new Sphere[sphereObjects.Length];

            for (int i = 0; i < sphereObjects.Length; i++)
            {
                spheres[i] = new Sphere()
                {
                    position = sphereObjects[i].transform.position,
                    radius = sphereObjects[i].transform.localScale.x * 0.5f,
                };
            }

            // Create buffer containing all sphere data, and send it to the shader
            CreateStructuredBuffer(ref sphereBuffer, spheres);
            material.SetBuffer("_Spheres", sphereBuffer);
            material.SetInt("_NumSpheres", sphereObjects.Length);
        }

        // Create a compute buffer containing the given data (Note: data must be blittable)
        public void CreateStructuredBuffer<T>(ref ComputeBuffer buffer, T[] data) where T : struct
        {
            // Cannot create 0 length buffer (not sure why?)
            int length = Max(1, data.Length);
            // The size (in bytes) of the given data type
            int stride = System.Runtime.InteropServices.Marshal.SizeOf(typeof(T));

            // If buffer is null, wrong size, etc., then we'll need to create a new one
            if (buffer == null || !buffer.IsValid() || buffer.count != length || buffer.stride != stride)
            {
                if (buffer != null) { buffer.Release(); }
                buffer = new ComputeBuffer(length, stride, ComputeBufferType.Structured);
            }

            buffer.SetData(data);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CreateSpheres();

            CommandBuffer cmd = CommandBufferPool.Get(name);

            using (new ProfilingScope(cmd, new ProfilingSampler("Ray Tracing Pass")))
            {
                cmd.BeginSample("Ray Tracing");

                // Clear outline texture
                cmd.SetRenderTarget(resultID.id, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cmd.ClearRenderTarget(RTClearFlags.All, Color.clear, 0, 255);

                // Draw to result texture
                Draw(cmd, sourceID, resultID.id, Pass.RayTracing);

                cmd.SetGlobalTexture(sourceTexShaderId, resultID.id);

                //Debug.Log("Write to texture " + sourceID);

                // Copy from result texture to camera source
                Draw(cmd, sourceID, sourceID, Pass.Copy);

                cmd.EndSample("Ray Tracing");
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
