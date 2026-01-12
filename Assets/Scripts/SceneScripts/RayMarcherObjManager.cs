using NUnit.Framework;
using System;
using System.Collections.Generic;
using UnityEngine;

public class RayMarcherObjManager : MonoBehaviour
{
    public static RayMarcherObjManager Instance;

    [Header("Light source pos")]
    public Transform m_LightTransform;

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

    public ComputeBuffer m_DefaultObjsBuffer = null;
    public ComputeBuffer m_SmoothUnionObjsBuffer = null;
    public ComputeBuffer m_SmoothSubtractionObjsBuffer = null;
    public ComputeBuffer m_SmoothIntersectionObjsBuffer = null;

    public ComputeBuffer m_CloudsObjsBuffer = null;

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
        if (obj.primType == PrimitiveType.CLOUD)
        {
            m_CloudsObjs.Add(obj);
            return;
        }

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
        if (obj.primType == PrimitiveType.CLOUD)
        {
            m_CloudsObjs.Remove(obj);
            return;
        }

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

    public void SetRayMarcherShaderComputeBuffer(Material rmMat, List<RayMarcherObject> objs, ref ComputeBuffer buffer, string structuredBufferName, string intCountName)
    {
        // If there are no objects, update just the count
        if (objs.Count == 0)
        {
            rmMat.SetInt(intCountName, 0);
            return;
        }

        int stride = sizeof(int) * 2 + sizeof(float) * 6;

        // Recreate only if needed
        if (buffer == null || buffer.count != objs.Count)
        {
            buffer?.Release();
            buffer = new ComputeBuffer(objs.Count, stride);
        }

        var data = new RMObj[objs.Count];

        for (int i = 0; i < objs.Count; i++)
        {
            RayMarcherObject currentObj = objs[i];
            data[i] = new RMObj
            {
                primType = (int)currentObj.primType,
                opType = (int)currentObj.operationType,
                pos = currentObj.transform.position,
                size = currentObj.size
            };
        }

        buffer.SetData(data);
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

    public void SetLightPos(Material mat)
    {
        if(m_LightTransform == null)
        {
            mat.SetVector("_LightPos", Vector3.zero);
        }
        else
        {
            mat.SetVector("_LightPos", m_LightTransform.position);
        }
    }

    private void OnDestroy()
    {
        m_DefaultObjsBuffer?.Release();
        m_SmoothUnionObjsBuffer?.Release();
        m_SmoothSubtractionObjsBuffer?.Release();
        m_SmoothIntersectionObjsBuffer?.Release();
        m_CloudsObjsBuffer?.Release();

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
