using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static UnityEngine.Rendering.DebugUI;

public class GameManager : MonoBehaviour
{
    public ScriptableRendererData renderData;

    public List<VolumeDataset> volumeDatasets;
    public List<TransferFunction> transferFunctions;
    public List<Environment> environments;

    private RenderModeRendererFeature renderModeFeature;

    private Dictionary<string, string> args;

    private int index;

    // Configuration
    private int width = 1200;
    private int height = 900;
    private int frameSize = 1000;
    private int fov = 45;
    private string saveFolder;
    private List<CameraConfig> cameraConfigs;
    private Vector3 rotation;
    private Vector3 cutPosition;
    private Vector3 cutNormal;
    private bool cuttingPlane = false;
    private bool tricubic;

    private string filePath = null; //"C:/Users/lenna/Desktop/Projects/CinematicVRT/Data/Cine/Herz/10000116/10000117/10000118";
    private int volume = 0;
    private int transferFunction = 0;
    private int environment = 0;
    private bool showEnvironment = false;

    private struct CameraConfig
    {
        public string name;
        public Vector3 position;
        public Quaternion rotation;
    }

    private async void Awake()
    {
        foreach (ScriptableRendererFeature feature in renderData.rendererFeatures)
        {
            if (feature is RenderModeRendererFeature)
            {
                renderModeFeature = (RenderModeRendererFeature)feature;
                renderModeFeature.deltaTrackingSettings.MaxSamples = frameSize + 1;
                renderModeFeature.SetActive(false);
            }
        }

#if !UNITY_EDITOR
        Init();
        Screen.SetResolution(width, height, false);
        Debug.Log("Set screen resolution to " + width + ", " + height);
        Camera.main.fieldOfView = fov;

        if (transferFunction >= transferFunctions.Count)
            transferFunction = 0;
        FindObjectOfType<TransferFunctionManager>().transferFunction = transferFunctions[transferFunction];

        if (environment >= environments.Count)
            environment = 0;
        FindObjectOfType<EnvironmentManager>().environment = environments[environment];
        FindObjectOfType<EnvironmentManager>().showEnvironment = showEnvironment;

        // Set cutting plane variables
        if(cuttingPlane)
        {
            Shader.EnableKeyword("CUTTING_PLANE");
            Shader.SetGlobalVector("_CutPosition", cutPosition);
            Shader.SetGlobalVector("_CutNormal", cutNormal);
        }
        else
        {
            Shader.DisableKeyword("CUTTING_PLANE");
        } 

        if(tricubic)
        {
            Shader.EnableKeyword("TRICUBIC_SAMPLING");
        }
        else
        {
            Shader.DisableKeyword("TRICUBIC_SAMPLING");
        }
        
        // Set volume, transfer function and environment
        VolumeBoundingBox volumeBB = FindObjectOfType<VolumeBoundingBox>();

        if(filePath != null)
        {
            DicomImporter importer = new DicomImporter(filePath);
            VolumeDataset dataset = await importer.ImportAsync();
            volumeBB.dataset = dataset;

            if (dataset == null)
            {
                Debug.LogError("Error importing dataset for file path '" + filePath + "'");
                Application.Quit();
            }
        }
        else
        {
            if (volume >= volumeDatasets.Count)
                volume = 0;

            volumeBB.dataset = volumeDatasets[volume];
        }

        volumeBB.transform.rotation = Quaternion.Euler(rotation);
        volumeBB.Initialize();
        volumeBB.GetComponent<OctreeGenerator>().RegenerateOctree();    
#endif


        Debug.Log("Start rendering...");
        renderModeFeature.SetActive(true);
        renderModeFeature.Create();
    }

    private void OnValidate()
    {
        /*if(tricubicSampling)
        {
            Shader.EnableKeyword("TRICUBIC_SAMPLING");
            Shader.EnableKeyword("CUTTING_PLANE");
        }
        else
        {
            Shader.DisableKeyword("TRICUBIC_SAMPLING");
            Shader.DisableKeyword("CUTTING_PLANE");
        }*/
    }

    private void Start()
    {
        index = 0;

        if(cameraConfigs != null)
        {
            Camera.main.transform.position = cameraConfigs[index].position;
            Camera.main.transform.rotation = cameraConfigs[index].rotation;
        }
    }

    private void Update()
    {
        if(cameraConfigs == null || index >= cameraConfigs.Count)
        {
            return;
        }

#if !UNITY_EDITOR
        if (renderModeFeature.GetFrameId() == frameSize)
        {
            ScreenCapture.CaptureScreenshot(saveFolder + "/" + cameraConfigs[index].name + ".png");
            Debug.Log("Save index " + index + " at frame " + renderModeFeature.GetFrameId());
        }
#endif

        if (renderModeFeature.GetFrameId() > frameSize)
        {
            renderModeFeature.ResetFrameId();

            index++;
            if(index < cameraConfigs.Count)
            {
                Camera.main.transform.position = cameraConfigs[index].position;
                Camera.main.transform.rotation = cameraConfigs[index].rotation;
            }
            else
            {
                Application.Quit();
            }
        }
    }

#region Initialization

    private void Init()
    {
        Dictionary<string, string> args = GetCommandLineArgs();

        try
        {
            string value;
            if (args.TryGetValue("-savefolder", out value))
            {
                saveFolder = value;
                if (!Directory.Exists(saveFolder))
                {
                    Directory.CreateDirectory(saveFolder);
                }
            }

            if (args.TryGetValue("-dicom", out value))
            {
                filePath = value;
            }

            if (args.TryGetValue("-config", out value))
            {
                InitConfig(value);
            }
            else
            {
                Debug.LogError("Config file missing.");
                Application.Quit();
            }

            if (args.TryGetValue("-cameraconfig", out value))
            {
                InitCameraConfig(value);
            }
            else
            {
                Debug.LogError("Camera config file missing.");
                Application.Quit();
            }

        }
        catch (FormatException e)
        {
            Debug.LogError(e.Message);
            Application.Quit();
        }
    }

    private void CheckParameterLength(string[] line, int length)
    {
        if(line.Length - 1 != length)
        {
            Debug.LogError("Invalid length for parameter '" + line[0] + "': " + line.Length + " instead of " + length);
            Application.Quit();
        }
    }

    private async void InitVolumeDataset(string filePath)
    {
        DicomImporter importer = new DicomImporter(filePath);

        VolumeDataset dataset = await importer.ImportAsync();

        if (dataset == null)
        {
            Debug.LogError("Error importing dataset for file path '" + filePath + "'");
        }
    }

    private void InitConfig(string path)
    {
        try
        {
            StreamReader reader = new StreamReader(path);
            while (!reader.EndOfStream)
            {
                string readLine = reader.ReadLine();
                if (readLine == null || readLine.Length == 0)
                {
                    Debug.LogError("Invalid line in config file");
                    Application.Quit();
                }
                if (readLine.StartsWith('#'))
                {
                    continue;
                }

                string[] line = readLine.Split(' ');

                switch(line[0])
                {
                    case "width":
                        CheckParameterLength(line, 1);
                        width = int.Parse(line[1], CultureInfo.InvariantCulture);
                        break;
                    case "height":
                        CheckParameterLength(line, 1);
                        height = int.Parse(line[1], CultureInfo.InvariantCulture);
                        break;
                    case "fov":
                        CheckParameterLength(line, 1);
                        fov = int.Parse(line[1], CultureInfo.InvariantCulture);
                        break;
                    case "frameSize":
                        CheckParameterLength(line, 1);
                        frameSize = int.Parse(line[1], CultureInfo.InvariantCulture);
                        break;
                    case "volume":
                        CheckParameterLength(line, 1);
                        volume = int.Parse(line[1], CultureInfo.InvariantCulture);
                        break;
                    case "transferFunction":
                        CheckParameterLength(line, 1);
                        transferFunction = int.Parse(line[1], CultureInfo.InvariantCulture);
                        break;
                    case "environment":
                        CheckParameterLength(line, 1);
                        environment = int.Parse(line[1], CultureInfo.InvariantCulture);
                        break;
                    case "showEnvironment":
                        CheckParameterLength(line, 0);
                        showEnvironment = true;
                        break;
                    case "rotation":
                        CheckParameterLength(line, 3);
                        rotation = new Vector3(float.Parse(line[1], CultureInfo.InvariantCulture), float.Parse(line[2], CultureInfo.InvariantCulture), float.Parse(line[3], CultureInfo.InvariantCulture));
                        break;
                    case "cutPosition":
                        CheckParameterLength(line, 3);
                        cutPosition = new Vector3(float.Parse(line[1], CultureInfo.InvariantCulture), float.Parse(line[2], CultureInfo.InvariantCulture), float.Parse(line[3], CultureInfo.InvariantCulture));
                        cuttingPlane = true;
                        break;
                    case "cutNormal":
                        CheckParameterLength(line, 3);
                        cutNormal = new Vector3(float.Parse(line[1], CultureInfo.InvariantCulture), float.Parse(line[2], CultureInfo.InvariantCulture), float.Parse(line[3], CultureInfo.InvariantCulture));
                        cuttingPlane = true;
                        break;
                    case "tricubic":
                        CheckParameterLength(line, 0);
                        tricubic = true;
                        break;
                    default:
                        Debug.Log("Unknown parameter: " + line[0]);
                        break;
                }
            }
            reader.Close();
        }
        catch (FileNotFoundException e)
        {
            Debug.LogError(e.Message);
            Application.Quit();
        }
    }

    private void InitCameraConfig(string path)
    {
        cameraConfigs = new List<CameraConfig>();

        try
        {
            StreamReader reader = new StreamReader(path);
            while (!reader.EndOfStream)
            {
                string readLine = reader.ReadLine();
                if (readLine.StartsWith('#'))
                {
                    continue;
                }
                string[] line = readLine.Split(' ');

                if (line.Length != 10)
                {
                    Debug.LogError("Invalid line length in config file");
                    Application.Quit();
                }

                // Create camera config from line
                CameraConfig cameraConfig = new CameraConfig();
                cameraConfig.name = line[0];

                Vector3 cameraPos = Vector3.zero;
                cameraPos.x = float.Parse(line[1], CultureInfo.InvariantCulture);
                cameraPos.y = float.Parse(line[2], CultureInfo.InvariantCulture);
                cameraPos.z = float.Parse(line[3], CultureInfo.InvariantCulture);

                Vector3 cameraRot = Vector3.zero;
                cameraRot.x = float.Parse(line[4], CultureInfo.InvariantCulture);
                cameraRot.y = float.Parse(line[5], CultureInfo.InvariantCulture);
                cameraRot.z = float.Parse(line[6], CultureInfo.InvariantCulture);

                Vector3 cameraUp = Vector3.zero;
                cameraUp.x = float.Parse(line[7], CultureInfo.InvariantCulture);
                cameraUp.y = float.Parse(line[8], CultureInfo.InvariantCulture);
                cameraUp.z = float.Parse(line[9], CultureInfo.InvariantCulture);

                cameraConfig.position = cameraPos;
                //cameraConfig.rotation = Quaternion.Euler(cameraRot);
                cameraConfig.rotation = Quaternion.LookRotation(cameraRot, cameraUp);
                cameraConfigs.Add(cameraConfig);
            }
            reader.Close();
        }
        catch (FileNotFoundException e)
        {
            Debug.LogError(e.Message);
            Application.Quit();
        }
    }

    private Vector3 ReadVector3(string value)
    {
        string[] config = value.Split(',');

        if (config.Length != 3)
        {
            Debug.LogError("Invalid amount of params in vector parameter");
            Application.Quit();
        }

        Vector3 vec = Vector3.zero;
        vec.x = float.Parse(config[0], CultureInfo.InvariantCulture);
        vec.y = float.Parse(config[1], CultureInfo.InvariantCulture);
        vec.z = float.Parse(config[2], CultureInfo.InvariantCulture);

        return vec;
    }

    // Original code from https://docs-multiplayer.unity3d.com/docs/tutorials/goldenpath
    private Dictionary<string, string> GetCommandLineArgs()
    {
        Dictionary<string, string> argumentDictionary = new Dictionary<string, string>();

        var commandLineArgs = System.Environment.GetCommandLineArgs();

        for (int argumentIndex = 0; argumentIndex < commandLineArgs.Length; ++argumentIndex)
        {
            var arg = commandLineArgs[argumentIndex].ToLower();
            if (arg.StartsWith("-"))
            {
                var value = argumentIndex < commandLineArgs.Length - 1 ?
                            commandLineArgs[argumentIndex + 1].ToLower() : null;
                value = (value?.StartsWith("-") ?? false) ? null : value;

                argumentDictionary.Add(arg, value);
            }
        }
        return argumentDictionary;
    }

#endregion
}
