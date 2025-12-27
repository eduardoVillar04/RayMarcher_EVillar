using NUnit.Framework;
using System;
using System.Collections.Generic;
using UnityEngine;

public class RayMarcherObjManager : MonoBehaviour
{
    public static RayMarcherObjManager Instance;

    public List<RayMarcherObject> m_DefaultObjs = new List<RayMarcherObject>();
    public List<RayMarcherObject> m_BlendObjs = new List<RayMarcherObject>();

    public ComputeBuffer m_DefaultObjsBuffer;
    public ComputeBuffer m_BlendObjsBuffer;

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

    public void SetRayMarcherShaderComputeBuffer(Material rmMat, List<RayMarcherObject> objs, ComputeBuffer buffer, string structuredBufferName, string intCountName)
    {
        // If there are no objects, update just the count
        if (objs.Count == 0)
        {
            rmMat.SetInt(intCountName, 0);
            return;
        }

        var defaultObjsData = new RMObj[objs.Count];

        buffer?.Release();

        for (int i = 0; i < objs.Count; i++)
        {
            RayMarcherObject currentObj = objs[i];
            defaultObjsData[i] = new RMObj
            {
                primType = (int)currentObj.primType,
                opType = (int)currentObj.operationType,
                pos = currentObj.transform.position,
                size = currentObj.size
            };
        }

        buffer = new ComputeBuffer(objs.Count, sizeof(int) * 2 + sizeof(float) * 6);
        buffer.SetData(defaultObjsData);

        rmMat.SetBuffer(structuredBufferName, buffer);
        rmMat.SetInt(intCountName, objs.Count);
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
