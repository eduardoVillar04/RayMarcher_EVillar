using NUnit.Framework;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class RayMarcherObjManager : MonoBehaviour
{
    public static RayMarcherObjManager Instance;

    [SerializeField] private List<RayMarcherObject> m_DefaultObjs = new List<RayMarcherObject>();
    [SerializeField] private List<RayMarcherObject> m_BlendObjs = new List<RayMarcherObject>();

    // Control bool to stop bad behaviour in editor mode
    private bool isDirty = false;

    private void Awake()
    {
        if (Instance != null)
        {
            Destroy(gameObject);
        }
        else
        {
            Instance = this;
#if !UNITY_EDITOR
            DontDestroyOnLoad(gameObject);
#endif
        }
    }


    public void AddObjToList(RayMarcherObject obj, OperationType opType)
    {
        switch (opType)
        {
            case OperationType.NONE:
                m_DefaultObjs.Add(obj);
                break;
            case OperationType.BLEND:
                m_BlendObjs.Add(obj);
                break;
            default:
                break;
        }
    }

    public void RemoveObjFromList(RayMarcherObject obj, OperationType opType)
    {
        switch (opType)
        {
            case OperationType.NONE:
                m_DefaultObjs.Remove(obj);
                break;
            case OperationType.BLEND:
                m_BlendObjs.Remove(obj);
                break;
            default:
                break;
        }
    }
}
