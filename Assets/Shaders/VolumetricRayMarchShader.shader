Shader "Custom/VolumetricRayMarchShader"
{   
    SubShader
    {
        HLSLINCLUDE
        #define NUM_STEPS 64
        #define LIGHT_NUM_STEPS 16
        #define MAX_DIST 500

        struct CloudHit
        {
            float tEnter;
            float tExit;
            float3 pos;
            float3 size;
        };

        float4x4 _CamLocalToWorldMatrix; // cam.transform.localToWorldMatrix 
        float3 _ViewParams; // planeHeight, planeWidth, cam.nearClipPlane

        struct RM_Obj
        {
            int primType;
            int opType;
            float3 pos;
            float3 size;
        };

        // Texture
        Texture3D<float> _CloudTex;
        SamplerState sampler_CloudTex;

        // Cloud objs
        StructuredBuffer<RM_Obj> _CloudObjsBuffer; 
        int _CloudObjsCount;

        // Light
        float3 _LightPos;

        // Params
        float _StepSize;
        float _DensityScale;
        float _LightStepSize;
        float _LightAbsorb;
        float _DarknessThreshold;
        float _Transmittance;

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl" // _CameraDepthTexture

        ENDHLSL

        Tags { "RenderType"="Opaque" }
        LOD 100
        ZWrite Off Cull Off
        Pass
        {
            Name "VolumetricRayMarchShader"

            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment Frag

            // From UnityCG.cginc
            inline float LinearEyeDepth (float z)
            {
	            return 1.0 / (_ZBufferParams . z * z + _ZBufferParams . w);
            }
            
            void CheckForDepth(float3 p, float2 uv)
            {
                // Hit pos from WS -> VS
                float3 pView = mul(UNITY_MATRIX_V, float4(p, 1)).xyz;
                // Unity cam looks in -z direction
                float rayDepth = -pView.z;

                // Sample depth texture
                float rawDepth = SampleSceneDepth(uv);
                // Denormalize it
                float eyeDepth = LinearEyeDepth(rawDepth);
                 
                if(rayDepth > eyeDepth) discard;
            }

            // Slab ray intersection algorithm for AABB boxes
            // tEnter / tExit are distances to the point of intersection with the box from the origin
            bool RayBoxSlabIntersection(float3 rayOrigin, float3 rayDir, float3 boxMin, float3 boxMax, out float tEnter, out float tExit)
            {
                float3 invDir = 1.0 / rayDir;

                float3 t0 = (boxMin - rayOrigin) * invDir;
                float3 t1 = (boxMax - rayOrigin) * invDir;

                float3 tMin = min(t0, t1);
                float3 tMax = max(t0, t1);

                tEnter = max(max(tMin.x, tMin.y), tMin.z);
                tExit  = min(min(tMax.x, tMax.y), tMax.z);

                return tExit > max(tEnter, 0.0);
            }


            float3 VolumetricRayMarch(float3 rO, float3 rD, float numSteps, float stepSize, float densityScale, float numLightSteps, 
                                     float lightStepSize, float lightAbsorb,  float darknessThreshold, float transmittance)
            {            
                float3 cloudPos, cloudSize, lightDir, cloudMin, cloudMax, minCloudMin, minCloudMax;
                
                float tEnter, tExit;

                float minTEnter = MAX_DIST;
                float minTExit;

                RM_Obj currentCloud;
                bool hit;

                // Check for the closest cloud to the camera in this pixel
                for(float i = 0; i < _CloudObjsCount; i++)
                {
                    currentCloud = _CloudObjsBuffer[i];
                    
                    cloudMin = currentCloud.pos - currentCloud.size * 0.5;
                    cloudMax = currentCloud.pos + currentCloud.size * 0.5;
                
                    hit = RayBoxSlabIntersection(rO, rD, cloudMin, cloudMax, tEnter, tExit);

                    // If the hit with the cloud has the least distance, save its params
                    if(hit && tEnter < minTEnter)
                    {
                        minTEnter = tEnter;
                        minTExit = tExit;
                        minCloudMin = cloudMin;
                        minCloudMax = cloudMax;
                        cloudPos = currentCloud.pos;
                        cloudSize = currentCloud.size;
                    }
                }

                // If there is no intersection return a result with transmission 1 to make the alpha 0
                if(minTEnter >= MAX_DIST)
                {
                    return float3(1,1,1);
                }

                // Make sure the params correspond to the corrent cloud
                tEnter = minTEnter;
                tExit = minTExit;
                cloudMin = minCloudMin;
                cloudMax = minCloudMax;

                lightDir = normalize(cloudPos - _LightPos);
                float rayDistInBox = tExit - tEnter;
                
                // The origin of the ray to march the cloud is the intersection with the ray from the camera 
                rO += rD * tEnter;

                float density = 0;
                float transmission = 0;
                float lightAccumulation = 0;
                float finalLight = 0;

                for(float i=0; i < numSteps; i++)
                {
                    float3 samplePos = rO + rD * (stepSize * i);
                    
                    // If the ray leaves the box it wont enter again
                    if((stepSize * i) > rayDistInBox) break;

                    float3 uvw = (samplePos - cloudMin) / cloudSize;

                    // Aprox derivatives for samplegrad
                    float3 ddx = float3(stepSize / cloudSize.x, 0, 0);
                    float3 ddy = float3(0, stepSize / cloudSize.y, 0);
                    float sampledDensity = _CloudTex.SampleGrad(sampler_CloudTex, uvw, ddx, ddy).r;
                    
                    density += sampledDensity * densityScale;

                    float3 lightRayOrigin = samplePos;

                    for(float j=0; j < numLightSteps; j++)
                    {
                        lightRayOrigin += -lightDir * lightStepSize;
                        float3 lightUVW = (lightRayOrigin - cloudMin) / cloudSize;
                        float lightDensity = 0;

                        // If the point is inside the cloud calculate light density, if not it is 0 (all light passes)
                        float3 light_ddx = float3(lightStepSize / cloudSize.x, 0, 0);
                        float3 light_ddy = float3(0, lightStepSize / cloudSize.y, 0);
                        lightDensity = _CloudTex.SampleGrad(sampler_CloudTex, lightUVW, light_ddx, light_ddy).r;


                        lightAccumulation += lightDensity;
                    }

                    float lightTransmission = exp(-lightAccumulation);
                    float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);
                    finalLight += density * transmittance * shadow;
                    transmittance *= exp(-density * lightAbsorb);
                }

                transmission = exp(-density);

                float3 result = float3(finalLight, transmission, transmittance);
                return result;
            }


            float4 Frag (Varyings input) : SV_Target
            {
                float4 color = 0;
                float3 camPos = _WorldSpaceCameraPos;

                // Calculate the local pos of the point in the near plane
                float3 viewPointLocal = float3(input.texcoord - 0.5, 1) * _ViewParams;
                // local to world
                float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1));

                float3 rD = normalize(viewPoint - camPos);

                // float3 cloudPos = float3(0,0,0);
                // float3 cloudSize = float3(5,5,5);
                // float3 cloudMin = cloudPos - cloudSize * 0.5;
                // float3 cloudMax = cloudPos + cloudSize * 0.5;

                // float3 lightDir = normalize(cloudPos - _LightPos);

                float3 result = VolumetricRayMarch(camPos, rD, NUM_STEPS, 
                                                  _StepSize, _DensityScale, LIGHT_NUM_STEPS, _LightStepSize, _LightAbsorb, _DarknessThreshold, _Transmittance);

                float3 lightCloudColor = float4(1,1,1,1);
                float3 darkCloudColor = float4(0.2,0.2,0.2,1);

                float3 finalCloudColor = lerp(darkCloudColor, lightCloudColor, result.r);
                float finalAlpha = 1 - result.g;

                // BlitTex is scene color texture
                float4 sceneCol = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord);
                float3 outRGB = lerp(sceneCol.rgb, finalCloudColor, finalAlpha);
                
                return float4(outRGB, 1.0);
            }
            
            ENDHLSL
        }
    }
}
