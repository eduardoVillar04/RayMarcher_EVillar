using UnityEngine;

public class SceneButton : MonoBehaviour
{
    public SceneManagerController.SceneType m_Scene;

    public void LoadScene()
    {
        SceneManagerController.Instance.LoadScene(m_Scene);
    }

    public void Quit()
    {
        SceneManagerController.Instance.Quit();
    }
}