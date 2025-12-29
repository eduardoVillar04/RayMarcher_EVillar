using UnityEngine;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule.Util;
using System.Collections.Generic;

public class RayMarcherFeature : ScriptableRendererFeature
{    
    [Tooltip("The material used when making the blit operation.")]
    public Material material;

    [Tooltip("The event where to inject the pass.")]
    public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingPostProcessing;

    public class RayMarcherPass : ScriptableRenderPass
    {
        const string m_PassName = "RayMarcherPass";

        // Material used in the blit operation.
        Material m_RayMarchMat;

        // Function used to transfer the material from the renderer feature to the render pass.
        public void Setup(Material mat)
        {
            m_RayMarchMat = mat;

            Camera cam = Camera.current;
            if(cam == null) cam = Camera.main;

            float planeHeight = cam.nearClipPlane * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2;
            float planeWidth = planeHeight * cam.aspect;

            List<RayMarcherObject> defaultObjs = RayMarcherObjManager.Instance?.m_DefaultObjs;
            ComputeBuffer defaultBuffer = RayMarcherObjManager.Instance?.m_DefaultObjsBuffer;

            List<RayMarcherObject> smoothUnionObjs = RayMarcherObjManager.Instance?.m_SmoothUnionObjs;
            ComputeBuffer smoothUnionBuffer = RayMarcherObjManager.Instance?.m_SmoothUnionObjsBuffer;

            List<RayMarcherObject> smoothSubtractionObjs = RayMarcherObjManager.Instance?.m_SmoothSubtractionObjs;
            ComputeBuffer smoothSubtractionBuffer = RayMarcherObjManager.Instance?.m_SmoothSubtractionObjsBuffer;

            List<RayMarcherObject> smoothIntersectionObjs = RayMarcherObjManager.Instance?.m_SmoothIntersectionObjs;
            ComputeBuffer smoothIntersectionBuffer= RayMarcherObjManager.Instance?.m_SmoothIntersectionObjsBuffer;


            m_RayMarchMat.SetVector("_ViewParams", new Vector3(planeWidth, planeHeight, cam.nearClipPlane));
            m_RayMarchMat.SetMatrix("_CamLocalToWorldMatrix", cam.transform.localToWorldMatrix);

            // Set compute buffers
            RayMarcherObjManager.Instance?.SetRayMarcherShaderComputeBuffer(m_RayMarchMat, defaultObjs, defaultBuffer, "_DefaultRMObjsBuffer", "_DefaultRMObjsCount");
            RayMarcherObjManager.Instance?.SetRayMarcherShaderComputeBuffer(m_RayMarchMat, smoothUnionObjs, smoothUnionBuffer, "_SmoothUnionObjsBuffer", "_SmoothUnionObjsCount");
            RayMarcherObjManager.Instance?.SetRayMarcherShaderComputeBuffer(m_RayMarchMat, smoothSubtractionObjs, smoothSubtractionBuffer, "_SmoothSubtractionObjsBuffer", "_SmoothSubtractionObjsCount");
            RayMarcherObjManager.Instance?.SetRayMarcherShaderComputeBuffer(m_RayMarchMat, smoothIntersectionObjs, smoothIntersectionBuffer, "_SmoothIntersectionObjsBuffer", "_SmoothIntersectionObjsCount");

            RayMarcherObjManager.Instance?.SetExtraParameters(m_RayMarchMat);

            //The pass will read the current color texture. That needs to be an intermediate texture. It's not supported to use the BackBuffer as input texture. 
            //By setting this property, URP will automatically create an intermediate texture. 
            //It's good practice to set it here and not from the RenderFeature. This way, the pass is selfcontaining and you can use it to directly enqueue the pass from a monobehaviour without a RenderFeature.
            requiresIntermediateTexture = true;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {

            // UniversalResourceData contains all the texture handles used by the renderer, including the active color and depth textures
            // The active color and depth textures are the main color and depth buffers that the camera renders into
            var resourceData = frameData.Get<UniversalResourceData>();
            //This should never happen since we set m_Pass.requiresIntermediateTexture = true;
            //Unless you set the render event to AfterRendering, where we only have the BackBuffer. 
            if (resourceData.isActiveTargetBackBuffer)
            {
                Debug.LogError($"Skipping render pass. RayMarcherPass requires an intermediate ColorTexture, we can't use the BackBuffer as a texture input.");
                return;
            }

            // The destination texture is created here, 
            // the texture is created with the same dimensions as the active color texture
            var source = resourceData.activeColorTexture;

            var destinationDesc = renderGraph.GetTextureDesc(source);
            destinationDesc.name = $"CameraColor-{m_PassName}";
            destinationDesc.clearBuffer = false;

            TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

            RenderGraphUtils.BlitMaterialParameters para = new(source, destination, m_RayMarchMat, 0);
            renderGraph.AddBlitPass(para, passName: m_PassName);

            //FrameData allows to get and set internal pipeline buffers. Here we update the CameraColorBuffer to the texture that we just wrote to in this pass. 
            //Because RenderGraph manages the pipeline resources and dependencies, following up passes will correctly use the right color buffer.
            //This optimization has some caveats. You have to be careful when the color buffer is persistent across frames and between different cameras, such as in camera stacking.
            //In those cases you need to make sure your texture is an RTHandle and that you properly manage the lifecycle of it.
            resourceData.cameraColor = destination;
        }
    }

    RayMarcherPass m_Pass;

    // Here you can create passes and do the initialization of them. This is called everytime serialization happens.
    public override void Create()
    {
        m_Pass = new RayMarcherPass();

        // Configures where the render pass should be injected.
        m_Pass.renderPassEvent = injectionPoint;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Early exit if there are no materials.
        if (material == null)
        {
            Debug.LogWarning("DitherEffectRendererFeature material is null and will be skipped.");
            return;
        }

        m_Pass.Setup(material);
        renderer.EnqueuePass(m_Pass);        
    }
}