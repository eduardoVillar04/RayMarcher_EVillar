using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class SpeedSlider : MonoBehaviour
{
    private MoveObjForward m_Cam;
    public Slider m_Slider;
    public TextMeshProUGUI m_ValueText;

    void Start()
    {
        m_Cam = Camera.main.GetComponent<MoveObjForward>();
        m_Slider = GetComponent<Slider>();
        m_Slider.onValueChanged.AddListener(delegate { ChangeSpeed(); });
        m_Slider.value = m_Cam.m_Speed;
        m_ValueText.text = m_Cam.m_Speed.ToString("n0");
    }
    
    private void ChangeSpeed()
    {
        m_Cam.m_Speed = m_Slider.value;
        m_ValueText.text = m_Slider.value.ToString("n0");
    }
}
