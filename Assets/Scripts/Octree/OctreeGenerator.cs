using UnityEngine;

[ExecuteAlways]
[RequireComponent(typeof(VolumeBoundingBox))]
public class OctreeGenerator : MonoBehaviour
{
    public ComputeShader computeShader;

    private VolumeBoundingBox m_VolumeBoundingBox;
    private ComputeBuffer m_OctreeBuffer;
    private int m_BaseKernel;
    private int m_MainKernel;
    private int m_DispatchSize;
    private bool m_Initialized;

    private const int OCTREE_STRIDE = 1 * sizeof(float);
    private const int OCTREE_DEPTH = 7; // The same as in shader files

    private void OnEnable()
    {
        m_VolumeBoundingBox = GetComponent<VolumeBoundingBox>();

        if (m_VolumeBoundingBox.GetDataTexture() == null)
        {
            return;
        }

        Initialize();

        GenerateOctree();
    }

    public void OnDisable()
    {
        m_OctreeBuffer?.Release();
    }

    private void OnValidate()
    {
        if (!enabled) return;

        GenerateOctree();
    }

    public void RegenerateOctree()
    {
        Initialize();

        GenerateOctree();
    }

    private void Initialize()
    {
        if (!m_VolumeBoundingBox.IsInitialized()) return;

        m_BaseKernel = computeShader.FindKernel("GenerateBase");
        m_MainKernel = computeShader.FindKernel("GenerateLevel");

        computeShader.SetTextureFromGlobal(m_BaseKernel, "_VolumeTex", "_VolumeTex");
        //computeShader.SetVector("_VolumeTexelSize", new Vector3(1.0f / dataTexture.width, 1.0f / dataTexture.height, 1.0f / dataTexture.depth));

        m_Initialized = true;

        //Debug.Log($"Volume Texture Texelsize: ({1 / dataTexture.width}, {1 / dataTexture.height}, {1 / dataTexture.depth})...");

        //TestSampleCell(OctreeLevel, new Vector3(63, 63, 63), new Vector3(1.0f / dataTexture.width, 1.0f / dataTexture.height, 1.0f / dataTexture.depth), 
        //    new Vector3Int(dataTexture.width, dataTexture.height, dataTexture.depth));
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
        for(int i = 0; i <= OCTREE_DEPTH; i++)
        {
            size += Mathf.RoundToInt(Mathf.Pow(2, (i + 1) * 3));
        }
        return size;
    }

    private void GenerateOctreeLevel(int level)
    {
        computeShader.SetInt("_GenerateLevel", level);

        int dim = Mathf.CeilToInt(Mathf.Pow(2, level + 1));

        //Debug.Log($"Generate Octree Level {level} ({dim}, {dim}, {dim})...");

        ShaderHelper.Dispatch(computeShader, m_MainKernel, dim, dim, dim);
    }

    private void GenerateOctree()
    {
        if (!m_Initialized) return;

        int dim = Mathf.CeilToInt(Mathf.Pow(2, OCTREE_DEPTH + 1));
        
        int bufferSize = GetOctreeBufferSize();
        Debug.Log($"Octree Buffer Size: {bufferSize}");
        ShaderHelper.CreateStructuredBuffer<float>(ref m_OctreeBuffer, bufferSize);

        // Generate base level
        Debug.Log($"Generate Octree Base {OCTREE_DEPTH} ({dim}, {dim}, {dim})...");
        computeShader.SetBuffer(m_BaseKernel, "_OctreeBuffer", m_OctreeBuffer);
        computeShader.SetInt("_GenerateLevel", OCTREE_DEPTH);

        ShaderHelper.Dispatch(computeShader, m_BaseKernel, dim, dim, dim);

        // Generate other levels
        computeShader.SetBuffer(m_MainKernel, "_OctreeBuffer", m_OctreeBuffer);

        for (int level = OCTREE_DEPTH - 1; level >= 0; level--)
        {
            GenerateOctreeLevel(level);
        }

        // Set to global
        Debug.Log($"Set global shader variables");
        Shader.SetGlobalBuffer("_OctreeBuffer", m_OctreeBuffer);
        Shader.SetGlobalInt("_OctreeDepth", OCTREE_DEPTH);
    }
}
