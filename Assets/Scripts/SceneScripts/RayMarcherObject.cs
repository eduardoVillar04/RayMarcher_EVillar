using UnityEngine;

[ExecuteAlways]
public class RayMarcherObject : MonoBehaviour
{
    [SerializeField] protected PrimitiveType type = PrimitiveType.SPHERE;
    [SerializeField] protected OperationType operationType = OperationType.NONE;
    [SerializeField] protected Vector3 pos = Vector3.zero;
    [SerializeField] protected Vector3 size = Vector3.one;

    private void Awake()
    {
        RayMarcherObjManager.Instance.AddObjToList(this);
    }

    private void OnDisable()
    {
        RayMarcherObjManager.Instance.RemoveObjFromList(this);
    }

    private void OnDrawGizmos()
    {
        switch (type)
        {
            case PrimitiveType.SPHERE:
                Gizmos.color = Color.red;
                Gizmos.DrawWireSphere(pos, size.x);
                break;
            case PrimitiveType.BOX:
                Gizmos.color = Color.blue;
                Gizmos.DrawWireCube(pos, size*2);
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