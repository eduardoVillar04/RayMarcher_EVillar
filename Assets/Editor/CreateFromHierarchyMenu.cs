using UnityEditor;
using UnityEngine;

public class CreateFromHierarchyMenu
{
    [MenuItem("GameObject/Ray Marching/RM Obj Manager", false, 0)]
    public static void CreateRayMarcherObjManager(MenuCommand menuCommand)
    {
        CreateUtils.CreatePrefab("RayMarching/Managers/RM_Manager");
    }

    [MenuItem("GameObject/Ray Marching/RM Sphere", false, 1)]
    public static void CreateRM_Sphere(MenuCommand menuCommand)
    {
        CreateUtils.CreatePrefab("RayMarching/RM_Objs/RM_Sphere");
    }

    [MenuItem("GameObject/Ray Marching/RM Box", false, 2)]
    public static void CreateRM_Box(MenuCommand menuCommand)
    {
        CreateUtils.CreatePrefab("RayMarching/RM_Objs/RM_Box");
    }

    [MenuItem("GameObject/Ray Marching/RM Menger Sponge", false, 2)]
    public static void CreateRM_MengerSponge(MenuCommand menuCommand)
    {
        CreateUtils.CreatePrefab("RayMarching/RM_Objs/RM_Menger_Sponge");
    }
}