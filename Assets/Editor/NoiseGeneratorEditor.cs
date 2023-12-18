using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(NoiseGenerator))]
public class NoiseGeneratorEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        NoiseGenerator myScript = (NoiseGenerator)target;
        if (GUILayout.Button("Generate 2D"))
            myScript.Generate2D();
        if (GUILayout.Button("Generate 3D"))
            myScript.Generate3D();
        if (GUILayout.Button("Generate 3D FBM"))
            myScript.Generate3DFBM();
    }
}
