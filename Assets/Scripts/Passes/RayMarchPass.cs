using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RayMarchPass : ScriptableRenderPass
{
    const string passName = "Ray March Fullscreen Pass";
    Material rayMarchMaterial;
    RTHandle cameraColorTarget;
    RTHandle rayMarchTempTexture;

    public RayMarchPass(Material material)
    {
        rayMarchMaterial = material;
    }

    public void Setup(RTHandle cameraColorHandle)
    {
        cameraColorTarget = cameraColorHandle;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        RenderTextureDescriptor cameraDescriptor = renderingData.cameraData.cameraTargetDescriptor;

        cameraDescriptor.depthBufferBits = 0;

        RenderingUtils.ReAllocateHandleIfNeeded(ref rayMarchTempTexture, cameraDescriptor, name: "_RayMarchTempTexture");
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if(rayMarchMaterial == null) return;

        CommandBuffer cmd = CommandBufferPool.Get(passName);

        Blitter.BlitCameraTexture(cmd, cameraColorTarget, rayMarchTempTexture, rayMarchMaterial, 0);

        Blitter.BlitCameraTexture(cmd, rayMarchTempTexture, cameraColorTarget);

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        if(rayMarchTempTexture != null)
        {
            rayMarchTempTexture.Release();
            rayMarchTempTexture = null;
        }
    }
}
