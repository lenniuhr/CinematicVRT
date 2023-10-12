using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
[RequireComponent(typeof(VolumeBoundingBox))]
public class OctreeGenerator : MonoBehaviour
{
    [Range(1, 8)]
    public int OctreeDepth = 1;
    [Range(1, 8)]
    public int OctreeLevel = 1;

    public ComputeShader computeShader;

    private VolumeBoundingBox m_VolumeBoundingBox;
    private ComputeBuffer m_OctreeBuffer;
    private int m_BaseKernel;
    private int m_MainKernel;
    private int m_DispatchSize;

    private const int OCTREE_STRIDE = 1 * sizeof(float);

    private void OnEnable()
    {
        m_VolumeBoundingBox = GetComponent<VolumeBoundingBox>();

        Initialize();

        GenerateOctree();
    }

    public void OnDisable()
    {
        m_OctreeBuffer?.Release();
    }

    private void OnValidate()
    {
        Shader.SetGlobalInt("_OctreeLevel", OctreeLevel);
    }

    private void Initialize()
    {
        m_BaseKernel = computeShader.FindKernel("GenerateBase");
        m_MainKernel = computeShader.FindKernel("GenerateLevel");

        Texture3D dataTexture = m_VolumeBoundingBox.GetDataTexture();
        computeShader.SetTexture(m_BaseKernel, "_VolumeTex", dataTexture);
        computeShader.SetVector("_VolumeTexelSize", new Vector3(1.0f / dataTexture.width, 1.0f / dataTexture.height, 1.0f / dataTexture.depth));
        Debug.Log($"Volume Texture Texelsize: ({1 / dataTexture.width}, {1 / dataTexture.height}, {1 / dataTexture.depth})...");

        TestSampleCell(OctreeLevel, new Vector3(63, 63, 63), new Vector3(1.0f / dataTexture.width, 1.0f / dataTexture.height, 1.0f / dataTexture.depth), 
            new Vector3Int(dataTexture.width, dataTexture.height, dataTexture.depth));
    }

    private void TestSampleCell(int level, Vector3 id, Vector3 texelSize, Vector3Int pixelSize)
    {
        int dim = Mathf.CeilToInt(Mathf.Pow(2, level));

        Vector3 cellMin = id / dim;
        Vector3 cellMax = (id + Vector3.one) / dim;

        Debug.Log("Cell min:" + cellMin);
        Debug.Log("Pixel min: " + Mathf.FloorToInt(cellMin.x / texelSize.x) + ", " + Mathf.FloorToInt(cellMin.y / texelSize.y) + ", " + Mathf.FloorToInt(cellMin.z / texelSize.z));
        Debug.Log("Pixel max: " + Mathf.FloorToInt(cellMax.x / texelSize.x) + ", " + Mathf.FloorToInt(cellMax.y / texelSize.y) + ", " + Mathf.FloorToInt(cellMax.z / texelSize.z));

        int stepsX = Mathf.CeilToInt((cellMax.x - cellMin.x) / texelSize.x);
        int stepsY = Mathf.CeilToInt((cellMax.y - cellMin.y) / texelSize.y);
        int stepsZ = Mathf.CeilToInt((cellMax.z - cellMin.z) / texelSize.z);

        Debug.Log($"Sample steps: ({stepsX}, {stepsY}, {stepsZ})");

        for (int x = 0; x < stepsX; x++)
        {
            for (int y = 0; y < stepsY; y++)
            {
                for (int z = 0; z < stepsZ; z++)
                {
                    //Debug.Log("Sample at " + (cellMin + new Vector3(texelSize.x * x, texelSize.y * y, texelSize.z * z)));
                }
            }
        }
    }

    private int GetOctreeBufferSize()
    {
        int size = 0;
        for(int i = 1; i <= OctreeDepth; i++)
        {
            size += Mathf.RoundToInt(Mathf.Pow(2, i * 3));
        }
        return size;
    }

    private void GenerateOctreeLevel(int level)
    {
        computeShader.SetInt("_GenerateLevel", level);

        int dim = Mathf.CeilToInt(Mathf.Pow(2, level));

        Debug.Log($"Generate Octree Level {level} ({dim}, {dim}, {dim})...");

        computeShader.GetKernelThreadGroupSizes(m_MainKernel, out uint threadGroupSizeX, out uint threadGroupSizeY, out uint threadGroupSizeZ);
        int threadGroupsX = Mathf.CeilToInt(dim / (float)threadGroupSizeX);
        int threadGroupsY = Mathf.CeilToInt(dim / (float)threadGroupSizeY);
        int threadGroupsZ = Mathf.CeilToInt(dim / (float)threadGroupSizeZ);

        Debug.Log($"Dispatch Size: ({threadGroupsX}, {threadGroupsY}, {threadGroupsZ})");
        computeShader.Dispatch(m_MainKernel, threadGroupsX, threadGroupsY, threadGroupsZ);
    }

    private void GenerateOctree()
    {
        int dim = Mathf.CeilToInt(Mathf.Pow(2, OctreeDepth));

        int bufferSize = GetOctreeBufferSize();
        Debug.Log($"Octree Buffer Size: {bufferSize}");

        // Generate base level
        Debug.Log($"Generate Octree Base {OctreeDepth} ({dim}, {dim}, {dim})...");
        m_OctreeBuffer = new ComputeBuffer(bufferSize, OCTREE_STRIDE, ComputeBufferType.Structured);

        computeShader.SetBuffer(m_BaseKernel, "_OctreeBuffer", m_OctreeBuffer);
        computeShader.SetInt("_GenerateLevel", OctreeDepth);

        computeShader.GetKernelThreadGroupSizes(m_BaseKernel, out uint threadGroupSizeX, out uint threadGroupSizeY, out uint threadGroupSizeZ);
        int threadGroupsX = Mathf.CeilToInt(dim / (float)threadGroupSizeX);
        int threadGroupsY = Mathf.CeilToInt(dim / (float)threadGroupSizeY);
        int threadGroupsZ = Mathf.CeilToInt(dim / (float)threadGroupSizeZ);

        Debug.Log($"Dispatch Size: ({threadGroupsX}, {threadGroupsY}, {threadGroupsZ})");
        computeShader.Dispatch(m_BaseKernel, threadGroupsX, threadGroupsY, threadGroupsZ);

        // Generate other levels
        computeShader.SetBuffer(m_MainKernel, "_OctreeBuffer", m_OctreeBuffer);

        for (int level = OctreeDepth - 1; level > 0; level--)
        {
            GenerateOctreeLevel(level);
        }

        // Set to global
        Debug.Log($"Set global shader variables");
        Shader.SetGlobalBuffer("_OctreeBuffer", m_OctreeBuffer);
        Shader.SetGlobalInt("_OctreeLevel", OctreeLevel);
    }
}
