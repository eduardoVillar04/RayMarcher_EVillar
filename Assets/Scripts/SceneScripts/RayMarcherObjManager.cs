using NUnit.Framework;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class RayMarcherObjManager : MonoBehaviour
{
    public static RayMarcherObjManager Instance;
    
    [SerializeField] private List<RayMarcherObject> m_RayMarcherObjs = new List<RayMarcherObject>();

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

    public void AddObjToList(RayMarcherObject obj)
    {
        m_RayMarcherObjs.Add(obj);
    }

    public void RemoveObjFromList(RayMarcherObject obj)
    {
        m_RayMarcherObjs.Remove(obj);
    }
}
