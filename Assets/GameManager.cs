using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GameManager : MonoBehaviour
{
    private void Awake()
    {
        CheckCommandLine();
    }

    private void CheckCommandLine()
    {
        Dictionary<string, string> args = GetCommandLineArgs();
        if (args.TryGetValue("-myflag", out var myflag))
        {
            if (myflag == "bert")
            {
            }
        }

        foreach (string arg in args.Keys) 
        {
            Debug.Log("Argument: " + arg);
        }
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

}
