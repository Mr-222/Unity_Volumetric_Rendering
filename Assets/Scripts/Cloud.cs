using UnityEngine;

[ExecuteAlways]
public class Cloud : MonoBehaviour
{
    private Vector3 lastPosition;
    private Vector3 lastScale;
    
    void Update()
    {
        Vector3 position = transform.position;
        Vector3 scale = transform.localScale;
        
        Shader.SetGlobalVector("_CloudBoundsMin", position - scale / 2);
        Shader.SetGlobalVector("_CloudBoundsMax", position + scale / 2);
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.green * new Color(0.1f, 0.1f, 0.1f, 0.1f);
        Gizmos.DrawWireCube(transform.position, transform.localScale);
    }

    private void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.green;
        Gizmos.DrawWireCube(transform.position, transform.localScale);
    }
}
