using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(NoiseGenerator))]
public class NoiseGeneratorEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        NoiseGenerator myScript = (NoiseGenerator)target;
        if (GUILayout.Button("Generate Worley 2D"))
            myScript.GenerateWorley2D();
        if (GUILayout.Button("Generate Worley 3D"))
            myScript.GenerateWorley3D();
        if (GUILayout.Button("Generate Worley 3D FBM"))
            myScript.GenerateWorley3DFBM();
        if (GUILayout.Button("Generate Perlin 2D"))
            myScript.GeneratePerlin2D();
    }
}
