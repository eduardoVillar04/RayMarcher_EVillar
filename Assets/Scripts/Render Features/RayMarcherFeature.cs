using UnityEngine;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule.Util;
using System.Collections.Generic;

public class RayMarcherFeature : ScriptableRendererFeature
{    
    [Tooltip("The material used when making the blit operation.")]
    public Material m_RayMarcherMat;
    public Material m_VolumetricRayMarchMat;

    [Tooltip("The event where to inject the pass.")]
    public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingPostProcessing;

    public Texture3D m_CloudText3D;

    private RTHandle m_RayMarchColorRT;

    public class RayMarcherPass : ScriptableRenderPass
    {
        const string m_PassName = "RayMarcherPass";

        // Material used in the blit operation.
        Material m_RayMarchMat;

        RTHandle m_TargetRT;

        // Function used to transfer the material from the renderer feature to the render pass.
        public void Setup(Material mat, RTHandle targetRT)
        {
            m_RayMarchMat = mat;
            m_TargetRT = targetRT;

            Camera cam = Camera.current;
            if(cam == null) cam = Camera.main;

            float planeHeight = cam.nearClipPlane * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2;
            float planeWidth = planeHeight * cam.aspect;

            m_RayMarchMat.SetVector("_ViewParams", new Vector3(planeWidth, planeHeight, cam.nearClipPlane));
            m_RayMarchMat.SetMatrix("_CamLocalToWorldMatrix", cam.transform.localToWorldMatrix);

            // Set compute buffers
            RayMarcherObjManager.Instance?.SetRayMarcherShaderComputeBuffer(m_RayMarchMat, RayMarcherObjManager.Instance.m_DefaultObjs, ref RayMarcherObjManager.Instance.m_DefaultObjsBuffer, 
                                                                            "_DefaultRMObjsBuffer", "_DefaultRMObjsCount");

            RayMarcherObjManager.Instance?.SetRayMarcherShaderComputeBuffer(m_RayMarchMat, RayMarcherObjManager.Instance.m_SmoothUnionObjs, ref RayMarcherObjManager.Instance.m_SmoothUnionObjsBuffer, 
                                                                            "_SmoothUnionObjsBuffer", "_SmoothUnionObjsCount");

            RayMarcherObjManager.Instance?.SetRayMarcherShaderComputeBuffer(m_RayMarchMat, RayMarcherObjManager.Instance.m_SmoothSubtractionObjs, ref RayMarcherObjManager.Instance.m_SmoothSubtractionObjsBuffer, 
                                                                            "_SmoothSubtractionObjsBuffer", "_SmoothSubtractionObjsCount");

            RayMarcherObjManager.Instance?.SetRayMarcherShaderComputeBuffer(m_RayMarchMat, RayMarcherObjManager.Instance.m_SmoothIntersectionObjs, ref RayMarcherObjManager.Instance.m_SmoothIntersectionObjsBuffer, 
                                                                            "_SmoothIntersectionObjsBuffer", "_SmoothIntersectionObjsCount");

            RayMarcherObjManager.Instance?.SetRayMarcherExtraParameters(m_RayMarchMat);

            // Set light
            RayMarcherObjManager.Instance?.SetLightPos(m_RayMarchMat);

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

            TextureHandle destination = renderGraph.ImportTexture(m_TargetRT);


            RenderGraphUtils.BlitMaterialParameters para = new(source, destination, m_RayMarchMat, 0);
            renderGraph.AddBlitPass(para, passName: m_PassName);

            //FrameData allows to get and set internal pipeline buffers. Here we update the CameraColorBuffer to the texture that we just wrote to in this pass. 
            //Because RenderGraph manages the pipeline resources and dependencies, following up passes will correctly use the right color buffer.
            //This optimization has some caveats. You have to be careful when the color buffer is persistent across frames and between different cameras, such as in camera stacking.
            //In those cases you need to make sure your texture is an RTHandle and that you properly manage the lifecycle of it.
            resourceData.cameraColor = destination;
        }
    }

    public class VolumetricRayMarcherPass : ScriptableRenderPass
    {
        const string m_PassName = "VolumetricRayMarcherPass";

        // Material used in the blit operation.
        Material m_VolumetricRayMarchMat;
        RTHandle m_RayMarchInputRT;

        // Function used to transfer the material from the renderer feature to the render pass.
        public void Setup(Material mat, Texture3D cloudTex, RTHandle rayMarchRT)
        {
            m_VolumetricRayMarchMat = mat;
            m_RayMarchInputRT = rayMarchRT;

            Camera cam = Camera.current;
            if(cam == null) cam = Camera.main;

            float planeHeight = cam.nearClipPlane * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2;
            float planeWidth = planeHeight * cam.aspect;

            m_VolumetricRayMarchMat.SetVector("_ViewParams", new Vector3(planeWidth, planeHeight, cam.nearClipPlane));
            m_VolumetricRayMarchMat.SetMatrix("_CamLocalToWorldMatrix", cam.transform.localToWorldMatrix);

            // Set light
            RayMarcherObjManager.Instance?.SetLightPos(m_VolumetricRayMarchMat);

            // Set cloud texture
            m_VolumetricRayMarchMat.SetTexture("_CloudTex", cloudTex);

            // Set cloud params
            RayMarcherObjManager.Instance?.SetVolumetricRayMarcherExtraParameters(m_VolumetricRayMarchMat);

            // Set clouds buffer
            RayMarcherObjManager.Instance?.SetRayMarcherShaderComputeBuffer(m_VolumetricRayMarchMat, RayMarcherObjManager.Instance.m_CloudsObjs, ref RayMarcherObjManager.Instance.m_CloudsObjsBuffer,
                                                                "_CloudObjsBuffer", "_CloudObjsCount");

            // We will also need the depth texture of the normal raymarcher
            m_VolumetricRayMarchMat.SetTexture("_RayMarchTex", m_RayMarchInputRT);


            requiresIntermediateTexture = true;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var resourceData = frameData.Get<UniversalResourceData>();
            if(resourceData.isActiveTargetBackBuffer)
            {
                Debug.LogError($"Skipping render pass. Volumetric RayMarcherPass requires an intermediate ColorTexture, we can't use the BackBuffer as a texture input.");
                return;
            }

            var source = renderGraph.ImportTexture(m_RayMarchInputRT);

            var destinationDesc = renderGraph.GetTextureDesc(source);
            destinationDesc.name = $"CameraColor-{m_PassName}";
            destinationDesc.clearBuffer = false;

            TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

            RenderGraphUtils.BlitMaterialParameters para = new(source, destination, m_VolumetricRayMarchMat, 0);
            renderGraph.AddBlitPass(para, passName: m_PassName);

            resourceData.cameraColor = destination;
        }
    }

    RayMarcherPass m_RayMarcherPass;
    VolumetricRayMarcherPass m_VolumetricRayMarcherPass;

    // Here you can create passes and do the initialization of them. This is called everytime serialization happens.
    public override void Create()
    {
        m_RayMarcherPass = new RayMarcherPass();
        m_VolumetricRayMarcherPass = new VolumetricRayMarcherPass();

        // Configures where the render pass should be injected.
        m_RayMarcherPass.renderPassEvent = injectionPoint;
        m_VolumetricRayMarcherPass.renderPassEvent = injectionPoint;

        // Init RTHandle for dest texture ray march pass
        var desc = new RenderTextureDescriptor(Screen.width, Screen.height, RenderTextureFormat.ARGBFloat, 0);
        desc.msaaSamples = 1;
        desc.enableRandomWrite = true; 
        m_RayMarchColorRT = RTHandles.Alloc(desc, name: "RayMarcherColorRT");
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(RayMarcherObjManager.Instance == null) return;

        if (m_RayMarcherMat == null) Debug.LogWarning("RayMarcher material is null and will be skipped.");
        else
        {
            m_RayMarcherPass.Setup(m_RayMarcherMat, m_RayMarchColorRT);
            renderer.EnqueuePass(m_RayMarcherPass);        
        }

        if(m_VolumetricRayMarchMat == null) Debug.LogWarning("VolumetricRayMarcher material is null and will be skipped.");
        else
        {
            m_VolumetricRayMarcherPass.Setup(m_VolumetricRayMarchMat, m_CloudText3D, m_RayMarchColorRT);
            renderer.EnqueuePass(m_VolumetricRayMarcherPass);
        }         

    }
    
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (m_RayMarchColorRT != null)
        {
            RTHandles.Release(m_RayMarchColorRT);
            m_RayMarchColorRT = null;
        }
    }

}