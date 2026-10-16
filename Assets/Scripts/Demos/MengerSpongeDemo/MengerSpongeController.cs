using TMPro;
using UnityEngine;

public class MengerSpongeController : MonoBehaviour
{
    public RayMarcherObject m_MengerObj;
    public TextMeshProUGUI m_DivisionsText;
    private string m_OriginalText;

    private void Start()
    {
        m_OriginalText = m_DivisionsText.text;
        m_DivisionsText.text = $"{m_OriginalText} {m_MengerObj.size.y.ToString()}";
    }

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.DownArrow) && m_MengerObj.size.y > 0)
        {
            m_MengerObj.size.y--;
            m_DivisionsText.text = $"{m_OriginalText} {m_MengerObj.size.y.ToString()}";
        }

        if (Input.GetKeyDown(KeyCode.UpArrow))
        {
            m_MengerObj.size.y++;
            m_DivisionsText.text = $"{m_OriginalText} {m_MengerObj.size.y.ToString()}";
        }
    }
}
