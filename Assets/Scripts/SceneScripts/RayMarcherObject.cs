using UnityEngine;

[ExecuteAlways]
public class RayMarcherObject : MonoBehaviour
{
    public PrimitiveType type = PrimitiveType.SPHERE;

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

    // Control variable to update the obj in the manager when it changes through the menu
    private OperationType lastOperationType;

    public Vector3 size = Vector3.one;

    private void OnValidate()
    {
        // If the op type was changed in the inspector update the obj in the manager
        if (lastOperationType != operationType)
        {
            RayMarcherObjManager.Instance.RemoveObjFromList(this, lastOperationType);
            RayMarcherObjManager.Instance.AddObjToList(this, operationType);
            lastOperationType = operationType;
        }
    }


    private void Awake()
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
    }

    private void OnDisable()
    {
        RayMarcherObjManager.Instance?.RemoveObjFromList(this, operationType);
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