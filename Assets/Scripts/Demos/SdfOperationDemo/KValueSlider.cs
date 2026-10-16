using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class KValueSlider : MonoBehaviour
{
    public RayMarcherObjManager m_RmManager;
    public Slider m_Slider;
    public TextMeshProUGUI m_ValueText;

    void Start()
    {
        if (m_RmManager == null) m_RmManager = FindAnyObjectByType<RayMarcherObjManager>();
        m_Slider = GetComponent<Slider>();
        m_Slider.onValueChanged.AddListener(delegate { ChangeKValue(); });
        m_Slider.value = m_RmManager.m_KValue;
        m_ValueText.text = m_RmManager.m_KValue.ToString("n1");
    }
    
    private void ChangeKValue()
    {
        m_RmManager.m_KValue = m_Slider.value;
        m_ValueText.text = m_Slider.value.ToString("n1");
    }
}
