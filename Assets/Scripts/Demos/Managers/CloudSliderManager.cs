
using UnityEngine;

public class CloudSliderManager : MonoBehaviour
{
    public RayMarcherObjManager m_RmManager;

    [Header("Cloud params")]
    public ValueSlider m_StepSizeSlider;
    public ValueSlider m_DensityScaleSlider;
    public ValueSlider m_LightStepSizeSlider;
    public ValueSlider m_LightAbsorbSlider;
    public ValueSlider m_DarknessThresholdSlider;
    public ValueSlider m_TransmittanceSlider;

    private float m_DefaultKValue;
    private float m_DefaultStepSize;
    private float m_DefaultDensityScale;
    private float m_DefaultLightStepSize;
    private float m_DefaultLightAbsorb;
    private float m_DefaultDarknessThreshold;
    private float m_DefaultTransmittance;

    private void Start()
    {
        if (m_RmManager == null) m_RmManager = RayMarcherObjManager.Instance;

        m_DefaultKValue = m_RmManager.m_KValue;
        m_DefaultStepSize = m_RmManager.m_StepSize;
        m_DefaultDensityScale = m_RmManager.m_DensityScale;
        m_DefaultLightStepSize = m_RmManager.m_LightStepSize;
        m_DefaultLightAbsorb = m_RmManager.m_LightAbsorb;
        m_DefaultDarknessThreshold = m_RmManager.m_DarknessThreshold;
        m_DefaultTransmittance = m_RmManager.m_Transmittance;

        InitializeSliders();
    }

    private void InitializeSliders()
    {
        m_StepSizeSlider.Initialize(
            () => m_RmManager.m_StepSize,
            value => m_RmManager.m_StepSize = value
        );

        m_DensityScaleSlider.Initialize(
            () => m_RmManager.m_DensityScale,
            value => m_RmManager.m_DensityScale = value
        );

        m_LightStepSizeSlider.Initialize(
            () => m_RmManager.m_LightStepSize,
            value => m_RmManager.m_LightStepSize = value
        );

        m_LightAbsorbSlider.Initialize(
            () => m_RmManager.m_LightAbsorb,
            value => m_RmManager.m_LightAbsorb = value
        );

        m_DarknessThresholdSlider.Initialize(
            () => m_RmManager.m_DarknessThreshold,
            value => m_RmManager.m_DarknessThreshold = value
        );

        m_TransmittanceSlider.Initialize(
            () => m_RmManager.m_Transmittance,
            value => m_RmManager.m_Transmittance = value
        );
    }

    public void ResetValues()
    {
        m_RmManager.m_KValue = m_DefaultKValue;
        m_RmManager.m_StepSize = m_DefaultStepSize;
        m_RmManager.m_DensityScale = m_DefaultDensityScale;
        m_RmManager.m_LightStepSize = m_DefaultLightStepSize;
        m_RmManager.m_LightAbsorb = m_DefaultLightAbsorb;
        m_RmManager.m_DarknessThreshold = m_DefaultDarknessThreshold;
        m_RmManager.m_Transmittance = m_DefaultTransmittance;

        RefreshSliders();
    }

    private void RefreshSliders()
    {
        m_StepSizeSlider.RefreshValue();
        m_DensityScaleSlider.RefreshValue();
        m_LightStepSizeSlider.RefreshValue();
        m_LightAbsorbSlider.RefreshValue();
        m_DarknessThresholdSlider.RefreshValue();
        m_TransmittanceSlider.RefreshValue();
    }
}
