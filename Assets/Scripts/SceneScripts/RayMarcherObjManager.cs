using NUnit.Framework;
using System;
using System.Collections.Generic;
using UnityEngine;

public class RayMarcherObjManager : MonoBehaviour
{
    public static RayMarcherObjManager Instance;

    [SerializeField] private List<RayMarcherObject> m_DefaultObjs = new List<RayMarcherObject>();
    [SerializeField] private List<RayMarcherObject> m_BlendObjs = new List<RayMarcherObject>();

    private ComputeBuffer m_DefaultObjsBuffer;

    private void Awake()
    {
        if (Instance != null)
        {
            Destroy(gameObject);
        }
        else
        {
            Instance = this;
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

    public void SetShaderComputeBuffer(Material rmMat)
    {
        // If there are no objects, update just the count
        if (m_DefaultObjs.Count == 0)
        {
            rmMat.SetInt("_DefaultRMObjsCount", 0);
            return;
        }

        var defaultObjsData = new RMObj[m_DefaultObjs.Count];

        m_DefaultObjsBuffer?.Release();

        for (int i = 0; i < m_DefaultObjs.Count; i++)
        {
            RayMarcherObject currentObj = m_DefaultObjs[i];
            defaultObjsData[i] = new RMObj
            {
                primType = (int)currentObj.primType,
                opType = (int)currentObj.operationType,
                pos = currentObj.transform.position,
                size = currentObj.size
            };
        }

        m_DefaultObjsBuffer = new ComputeBuffer(m_DefaultObjs.Count, sizeof(int)*2 + sizeof(float)*6);
        m_DefaultObjsBuffer.SetData(defaultObjsData);

        rmMat.SetBuffer("_DefaultRMObjsBuffer", m_DefaultObjsBuffer);
        rmMat.SetInt("_DefaultRMObjsCount", m_DefaultObjs.Count);
    }

    private void OnDestroy()
    {
        m_DefaultObjsBuffer?.Release();
        Instance = null;
    }

    public struct RMObj
    {
        public int primType;
        public int opType;
        public Vector3 pos;
        public Vector3 size;
    }
}
