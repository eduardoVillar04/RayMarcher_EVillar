using UnityEngine;

public class RayMarcherObject : MonoBehaviour
{
    public PrimitiveType primType = PrimitiveType.SPHERE;

    // We need to update the list the obj is whenever the operation type changes
    [SerializeField] private OperationType _operationType;
    public OperationType operationType
    {
        get => _operationType;
        set
        {
            if (_operationType == value)
                return;
            Debug.Log("changing");
            RayMarcherObjManager.Instance.RemoveObjFromList(this, operationType);
            _operationType = value;
            RayMarcherObjManager.Instance.AddObjToList(this, operationType);
        }
    }

    public Vector3 size = Vector3.one;

    public bool drawGizmos = true;

    private void Start()
    {
        if (RayMarcherObjManager.Instance == null)
        {
            Debug.LogError("RM Obj Manager not in scene. Make sure to add it before adding RM Objs");
        }
        else
        {
            RayMarcherObjManager.Instance.AddObjToList(this, operationType);
        }
    }

    private void OnDisable()
    {
        RayMarcherObjManager.Instance?.RemoveObjFromList(this, operationType);
    }

    private void OnDrawGizmos()
    {
        if (!drawGizmos) return;

        switch (primType)
        {
            case PrimitiveType.SPHERE:
                Gizmos.color = Color.red;
                Gizmos.DrawWireSphere(transform.position, size.x);
                break;
            case PrimitiveType.BOX:
                Gizmos.color = Color.blue;
                Gizmos.DrawWireCube(transform.position, size * 2);
                break;
            case PrimitiveType.MENGER_SPONGE:
                Gizmos.color = Color.purple;
                Gizmos.DrawWireCube(transform.position, Vector3.one * size.x);
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
    BOX,
    MENGER_SPONGE
}

public enum OperationType
{
    NONE = -1,
    SMOOTH_UNION,
    SMOOTH_SUBTRACTION,
    SMOOTH_INTERSECTION
}