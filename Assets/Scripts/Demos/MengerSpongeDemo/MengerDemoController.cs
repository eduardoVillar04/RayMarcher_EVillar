using UnityEngine;

public class MengerDemoController : MonoBehaviour
{
    public Transform spline;
    private int count = 0;
    public RayMarcherObject m_menger;
    private bool goingup = true;
    private float m_TimeBetweenChanges = 1;
    private float m_TimeNextChange = 0;

    private void Start()
    {
        m_TimeNextChange = Time.time + m_TimeBetweenChanges;
    }

    private void Update()
    {
        transform.LookAt(Vector3.zero);

        if(m_TimeNextChange < Time.time)
        {
            m_TimeNextChange = Time.time + m_TimeBetweenChanges;
            if(goingup) m_menger.size.y++;
            else m_menger.size.y--;
            if(m_menger.size.y == 5) goingup = false;
        }
    }
}
