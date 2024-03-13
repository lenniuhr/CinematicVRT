using UnityEngine;

[RequireComponent(typeof(Camera))]
public class CameraUpdateChecker : MonoBehaviour
{
    public float width;
    public float height;

    private Camera cam;

    void OnEnable()
    {
        cam = GetComponent<Camera>();
        width = cam.pixelWidth; 
        height = cam.pixelHeight;
    }

    public bool HasChanged()
    {
        if(cam == null)
        {
            return true;
        }

        bool changed = false;
        if (width != cam.pixelWidth)
        {
            width = cam.pixelWidth;
            changed = true;
        }
        if (height != cam.pixelHeight)
        {
            height = cam.pixelHeight;
            changed = true;
        }
        if(transform.hasChanged)
        {
            transform.hasChanged = false;
            changed = true;
        }

        return changed;
    }
}
