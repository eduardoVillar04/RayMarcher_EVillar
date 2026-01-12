using UnityEngine;

public class RayMarcherObject : MonoBehaviour
{
    [SerializeField] private PrimitiveType _primType = PrimitiveType.SPHERE;
    public PrimitiveType primType
    {
        get => _primType;
        set
        {
            if (_primType == value) return;

            // Refresh the entry to account for new primtype
            RayMarcherObjManager.Instance.RemoveObjFromList(this, operationType);
            _primType = value;
            RayMarcherObjManager.Instance.AddObjToList(this, operationType);
        }
    }

    // We need to update the list the obj is whenever the operation type changes
    [SerializeField] private OperationType _operationType;
    public OperationType operationType
    {
        get => _operationType;
        set
        {
            if (_operationType == value) return;
            RayMarcherObjManager.Instance.RemoveObjFromList(this, operationType);
            _operationType = value;
            RayMarcherObjManager.Instance.AddObjToList(this, operationType);
        }
    }

    public Vector3 size = Vector3.one;

    public bool drawGizmos = true;

    private OperationType lastOperationType;
    private PrimitiveType lastPrimeType;

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

        lastOperationType = operationType;
        lastPrimeType = primType;
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
            case PrimitiveType.CLOUD:
                Gizmos.color = Color.white;
                Gizmos.DrawWireCube(transform.position, size);
                break;
            default:
                break;
        }
    }


#if UNITY_EDITOR
    private void OnValidate()
    {
        if (!Application.isPlaying) return;

        var rmManager = RayMarcherObjManager.Instance;
        if (rmManager == null) return;

        // OPERATION TYPE
        if (lastOperationType != operationType)
        {
            rmManager.RemoveObjFromList(this, lastOperationType);
            lastOperationType = operationType;
            rmManager.AddObjToList(this, operationType);
        }

        // PRIMITIVE TYPE
        if (lastPrimeType != primType)
        {
            // Force the last primType onto the object so it is removed properly from the manager
            PrimitiveType current = _primType;
            _primType = lastPrimeType;

            rmManager.RemoveObjFromList(this, operationType);

            _primType = current;
            lastPrimeType = current;

            rmManager.AddObjToList(this, operationType);
        }
    }
#endif
}

public enum PrimitiveType
{
    SPHERE = 0,
    BOX,
    MENGER_SPONGE,
    CLOUD
}

public enum OperationType
{
    NONE = -1,
    SMOOTH_UNION,
    SMOOTH_SUBTRACTION,
    SMOOTH_INTERSECTION
}