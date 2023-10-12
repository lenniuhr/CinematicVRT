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
        [Range(0, 8)]
        public int MaxBounces;
    }
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRendering;
    public Settings settings = new Settings();

    private RayTracingPass m_RenderPass;

    public override void Create()
    {
        m_RenderPass = new RayTracingPass(name, settings);
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
        private RenderTargetHandle result;
        private RenderTargetHandle prevFrame;
        private RenderTargetHandle currentFrame;

        private int copyTex = Shader.PropertyToID("_CopyTex");

        // Buffers
        private ComputeBuffer sphereBuffer;
        private ComputeBuffer cubeBuffer;

        private int frameID;

        enum Pass
        {
            Accumulate,
            Copy,
            RayTracing
        }

        public RayTracingPass(string name, Settings settings)
        {
            this.name = name;
            this.material = CoreUtils.CreateEngineMaterial("Hidden/RayTracing");
            material.hideFlags = HideFlags.HideAndDontSave;
            material.SetInt("_MaxBounces", settings.MaxBounces);

            frameID = 0;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;

            UpdateCameraParams(renderingData.cameraData.camera);

            sourceID = renderingData.cameraData.renderer.cameraColorTarget;

            result.Init("_ResultTex");
            currentFrame.Init("_CurrentFrame");
            prevFrame.Init("_PrevFrame");

            desc.colorFormat = RenderTextureFormat.ARGBFloat;
            cmd.GetTemporaryRT(result.id, desc, FilterMode.Point);
            cmd.GetTemporaryRT(currentFrame.id, desc, FilterMode.Point);
            cmd.GetTemporaryRT(prevFrame.id, desc, FilterMode.Point);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(result.id);
            cmd.ReleaseTemporaryRT(currentFrame.id);
            cmd.ReleaseTemporaryRT(prevFrame.id);
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

            material.SetInt("_FrameID", frameID);
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
                    material = sphereObjects[i].material
                };
            }

            // Create buffer containing all sphere data, and send it to the shader
            CreateStructuredBuffer(ref sphereBuffer, spheres);
            material.SetBuffer("_Spheres", sphereBuffer);
            material.SetInt("_NumSpheres", sphereObjects.Length);
        }

        private void CreateCubes()
        {
            // Create sphere data from the sphere objects in the scene
            RayTracedCube[] cubeObjects = FindObjectsOfType<RayTracedCube>();
            Cube[] cubes = new Cube[cubeObjects.Length];

            for (int i = 0; i < cubeObjects.Length; i++)
            {
                cubes[i] = new Cube()
                {
                    position = cubeObjects[i].transform.position,
                    scale = cubeObjects[i].transform.localScale,
                    material = cubeObjects[i].material
                };
            }

            // Create buffer containing all sphere data, and send it to the shader
            CreateStructuredBuffer(ref cubeBuffer, cubes);
            material.SetBuffer("_Cubes", cubeBuffer);
            material.SetInt("_NumCubes", cubeObjects.Length);
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

        private void ReleaseBuffers()
        {
            sphereBuffer.Release();
            cubeBuffer.Release();
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CreateSpheres();
            CreateCubes();

            CommandBuffer cmd = CommandBufferPool.Get(name);

            using (new ProfilingScope(cmd, new ProfilingSampler("Ray Tracing Pass")))
            {
                cmd.BeginSample("Ray Tracing");

                bool isSceneCam = Camera.current && Camera.current.name == "SceneCamera";

                if (isSceneCam)
                {
                    Draw(cmd, sourceID, sourceID, Pass.RayTracing);
                }
                else
                {
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
                }

                cmd.EndSample("Ray Tracing");
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);

            //ReleaseBuffers();
        }
    }
}
