using UnityEngine;

[RequireComponent(typeof(Camera))]
public class RotateCamera : MonoBehaviour
{
    public Transform Target;

    public float Offset;
    public float Distance;
    public float Speed;
    public float Angle;
    public float StartTime;

    float time;

    // Start is called before the first frame update
    void Start()
    {
        time = StartTime;// + 11 * Speed;
    }

    // Update is called once per frame
    void Update()
    {
        Vector3 targetPosition = Target.position + new Vector3(0, Offset, 0);

        time += Time.deltaTime * Speed;
        Vector3 cameraDir = new Vector3(Mathf.Sin(time), Angle, Mathf.Cos(time)).normalized;

        transform.position = targetPosition + cameraDir * Distance;

        transform.LookAt(targetPosition);
    }
}
