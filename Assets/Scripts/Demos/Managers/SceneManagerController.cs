
using UnityEngine;
using UnityEngine.SceneManagement;

public class SceneManagerController : MonoBehaviour
{
    public static SceneManagerController Instance;

    public enum SceneType
    {
        MainMenu = 0,
        Sdf,
        SpaceRepetition,
        MengerSponge,
        Cloud,
        NumScenes
    }

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }

        Instance = this;
        DontDestroyOnLoad(gameObject);
    }

    public void LoadScene(SceneType scene)
    {
        SceneManager.LoadScene(((int)scene));
    }

    public void LoadMainMenu()
    {
        SceneManager.LoadScene(((int)SceneType.MainMenu));
    }

    public void Quit()
    {
        Debug.Log("hola");
        Application.Quit();
    }

}
