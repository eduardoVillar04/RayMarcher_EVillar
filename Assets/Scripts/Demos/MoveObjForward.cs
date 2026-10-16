using UnityEngine;

public class MoveObjForward : MonoBehaviour
{
    public float m_Speed = 1.0f;

    private void Update()
    {
        transform.position += transform.forward * m_Speed * Time.deltaTime;
    }
}
