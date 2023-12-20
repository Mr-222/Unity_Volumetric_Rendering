using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(NoiseGenerator))]
public class NoiseGeneratorEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        GUILayout.Space(15);

        NoiseGenerator myScript = (NoiseGenerator)target;
        if (GUILayout.Button("Generate Worley 2D"))
            myScript.GenerateWorley2D();
        if (GUILayout.Button("Generate Worley 3D"))
            myScript.GenerateWorley3D();
        if (GUILayout.Button("Generate Worley 3D FBM"))
            myScript.GenerateWorley3DFBM();
        
        GUILayout.Space(15);
        
        if (GUILayout.Button("Generate Perlin 2D"))
            myScript.GeneratePerlin2D();
        if (GUILayout.Button("Generate Perlin 3D"))
            myScript.GeneratePerlin3D();
    }
}
