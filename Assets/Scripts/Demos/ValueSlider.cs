using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class ValueSlider : MonoBehaviour
{
    public Slider m_Slider;
    public TextMeshProUGUI m_ValueText;
    public int m_FloatDecimals = 1;

    private Func<float> m_GetValue;
    private Action<float> m_SetValue;

    public void Initialize(Func<float> getValue, Action<float> setValue)
    {
        m_GetValue = getValue;
        m_SetValue = setValue;

        m_Slider.onValueChanged.AddListener(ChangeValue);
        m_Slider.value = m_GetValue();
        UpdateText(m_Slider.value);
    }

    private void ChangeValue(float value)
    {
        m_SetValue(value);
        UpdateText(value);
    }

    private void UpdateText(float value)
    {
        m_ValueText.text = value.ToString($"n{m_FloatDecimals}");
    }

    private void OnDestroy()
    {
        m_Slider.onValueChanged.RemoveListener(ChangeValue);
    }
    public void RefreshValue()
    {
        float value = m_GetValue();
        m_Slider.SetValueWithoutNotify(value);
        UpdateText(value);
    }
}