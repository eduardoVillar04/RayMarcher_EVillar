using UnityEngine;

[ExecuteAlways]
public class RayMarcherObject : MonoBehaviour
{
    [SerializeField] protected PrimitiveType type = PrimitiveType.SPHERE;
    [SerializeField] protected OperationType operationType = OperationType.NONE;
    [SerializeField] protected Vector3 size = Vector3.one;

    private void Awake()
    {
        if (RayMarcherObjManager.Instance == null)
        {
            Debug.LogError("RM Obj Manager not in scene. Make sure to add it before adding RM Objs");
        }
        else
        {
            RayMarcherObjManager.Instance.AddObjToList(this);
        }
    }

    private void OnDisable()
    {
        RayMarcherObjManager.Instance?.RemoveObjFromList(this);
    }

    private void OnDrawGizmos()
    {
        switch (type)
        {
            case PrimitiveType.SPHERE:
                Gizmos.color = Color.red;
                Gizmos.DrawWireSphere(transform.position, size.x);
                break;
            case PrimitiveType.BOX:
                Gizmos.color = Color.blue;
                Gizmos.DrawWireCube(transform.position, size*2);
                break;
            default:
                break;
        }
    }

}

public enum PrimitiveType
{
    NONE = -1,
    SPHERE,
    BOX
}

public enum OperationType
{
    NONE = -1,
    BLEND
}