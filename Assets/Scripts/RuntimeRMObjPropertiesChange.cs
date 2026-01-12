using UnityEngine;

public class RuntimeRMObjPropertiesChange : MonoBehaviour
{
    public PrimitiveType PrimitiveType;
    public OperationType OperationType;

    public RayMarcherObject rmObj;

    public bool change = false;

    private void Update()
    {
        ChangeOperationType();
    }

    public void ChangeOperationType()
    {
        if (change)
        {
            change = false;
            rmObj.operationType = OperationType;
            rmObj.primType = PrimitiveType;
        }
    }
}
