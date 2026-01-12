using UnityEngine;

public class MengerSpongeIncreaseInput : MonoBehaviour
{
    public RayMarcherObject mengerSponge;

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyDown(KeyCode.UpArrow))
        {
            mengerSponge.size.y++;
        }

        if (Input.GetKeyDown(KeyCode.DownArrow))
        {
            if(mengerSponge.size.y > 0) mengerSponge.size.y--;
        }
    }
}
