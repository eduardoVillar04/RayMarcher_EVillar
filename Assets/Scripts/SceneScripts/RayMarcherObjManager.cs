using NUnit.Framework;
using System;
using System.Collections.Generic;
using UnityEngine;

public class RayMarcherObjManager : MonoBehaviour
{
    public static RayMarcherObjManager Instance;

    [Header("Blend params")]
    public float m_KValue = 1.0f;

    [Header("Repetition cell")]
    public bool m_RepetitionActive = false;
    public Vector3 _RepetitionCellSize = Vector3.one;

    [Header("Cloud params")]
    //public float m_NumSteps = 32f;
    public float m_StepSize = 0.16f;
    public float m_DensityScale = 0.41f;
    //public float m_NumLightSteps = 16;
    public float m_LightStepSize = 0.33f;
    public float m_LightAbsorb = 2f;
    public float m_DarknessThreshold = 0f;
    public float m_Transmittance = 0.68f;



    [Header("Lists")]
    public List<RayMarcherObject> m_DefaultObjs = new List<RayMarcherObject>();
    public List<RayMarcherObject> m_SmoothUnionObjs = new List<RayMarcherObject>();
    public List<RayMarcherObject> m_SmoothSubtractionObjs = new List<RayMarcherObject>();
    public List<RayMarcherObject> m_SmoothIntersectionObjs = new List<RayMarcherObject>();

    public List<RayMarcherObject> m_CloudsObjs = new List<RayMarcherObject>();

    public ComputeBuffer m_DefaultObjsBuffer;
    public ComputeBuffer m_SmoothUnionObjsBuffer;
    public ComputeBuffer m_SmoothSubtractionObjsBuffer;
    public ComputeBuffer m_SmoothIntersectionObjsBuffer;

    public ComputeBuffer m_CloudsObjsBuffer;

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
            case OperationType.SMOOTH_UNION:
                m_SmoothUnionObjs.Add(obj);
                break;
            case OperationType.SMOOTH_SUBTRACTION:
                m_SmoothSubtractionObjs.Add(obj);
                break;
            case OperationType.SMOOTH_INTERSECTION:
                m_SmoothIntersectionObjs.Add(obj);
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
            case OperationType.SMOOTH_UNION:
                m_SmoothUnionObjs.Remove(obj);
                break;
            case OperationType.SMOOTH_SUBTRACTION:
                m_SmoothSubtractionObjs.Remove(obj);
                break;
            case OperationType.SMOOTH_INTERSECTION:
                m_SmoothIntersectionObjs.Remove(obj);
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

    public void SetRayMarcherExtraParameters(Material rmMat)
    {
        rmMat.SetFloat("_SmoothKValue", m_KValue);
        rmMat.SetInt("_RepetitionActive", m_RepetitionActive == true ? 1 : 0);
        rmMat.SetVector("_RepetitionCellSize", _RepetitionCellSize);
    }

    public void SetVolumetricRayMarcherExtraParameters(Material vrmMat)
    {
        //vrmMat.SetFloat("_NumSteps", m_NumSteps);
        vrmMat.SetFloat("_StepSize", m_StepSize);
        vrmMat.SetFloat("_DensityScale", m_DensityScale);
        //vrmMat.SetFloat("_NumLightSteps", m_NumLightSteps);
        vrmMat.SetFloat("_LightStepSize", m_LightStepSize);
        vrmMat.SetFloat("_LightAbsorb", m_LightAbsorb);
        vrmMat.SetFloat("_DarknessThreshold", m_DarknessThreshold);
        vrmMat.SetFloat("_Transmittance", m_Transmittance);
    }

    private void OnDestroy()
    {
        m_DefaultObjsBuffer?.Release();
        m_SmoothUnionObjsBuffer?.Release();
        m_SmoothSubtractionObjsBuffer?.Release();
        m_SmoothIntersectionObjsBuffer?.Release();

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
