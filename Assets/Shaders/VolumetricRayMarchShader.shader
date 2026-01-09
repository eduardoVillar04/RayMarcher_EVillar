Shader "Custom/VolumetricRayMarchShader"
{   
    SubShader
    {
        HLSLINCLUDE

        #define NUM_STEPS 32

        float4x4 _CamLocalToWorldMatrix; // cam.transform.localToWorldMatrix 
        float3 _ViewParams; // planeHeight, planeWidth, cam.nearClipPlane

        Texture3D<float> _CloudTex;
        SamplerState sampler_CloudTex;

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


            float3 VolumetricRayMarch(float3 posCloud, float3 sizeCloud, float3 rO, float3 rD, float stepSize, float densityScale, float numLightSteps, 
                                     float lightStepSize, float3 lightDir, float lightAbsorb,  float darknessThreshold, float transmittance)
            {
                float3 cloudMin = posCloud - sizeCloud * 0.5;
                float3 cloudMax = posCloud + sizeCloud * 0.5;
                
                float tEnter;
                float tExit;
                bool hit = RayBoxSlabIntersection(rO, rD, cloudMin, cloudMax, tEnter, tExit);

                // If there is no intersection return a result with transmission 1 to make the alpha 0
                if(!hit)
                {
                    float3 noHitCol = 1;
                    return noHitCol;
                }

                // The origin of the ray to march the cloud is the intersection with the ray from the camera 
                rO += rD * tEnter;

                float density = 0;
                float transmission = 0;
                float lightAccumulation = 0;
                float finalLight = 0;

                for(int i=0; i < NUM_STEPS; i++)
                {
                    rO += rD * stepSize;

                    float3 samplePos = rO;

                    // bool inside = (samplePos >= cloudMin) && (samplePos <= cloudMax);
                    bool inside = (stepSize * i) < (tExit - tEnter);
                     
                    // if (!inside) continue;
                    // If the ray leaves the box it wont enter again
                    if(!inside) break;

                    float3 uvw = (samplePos - cloudMin) / sizeCloud;
                    // float sampledDensity = _CloudTex.Sample(sampler_CloudTex, uvw).r;
                    float sampledDensity = SAMPLE_TEXTURE3D(_CloudTex, sampler_CloudTex, uvw).r;                    
                    density += sampledDensity;

                    float3 lightRayOrigin = samplePos;

                    for(int j=0; j < numLightSteps; j++)
                    {
                        lightRayOrigin += -lightDir * lightStepSize;
                        float3 lightUVW = (lightRayOrigin - cloudMin) / sizeCloud;
                        float lightDensity = 0;

                        // If the point is inside the cloud calculate light density, if not it is 0 (all light passes)
                        if(all(lightUVW >= 0) && all(lightUVW <= 1)) lightDensity = SAMPLE_TEXTURE3D(_CloudTex, sampler_CloudTex, lightUVW);

                        // float lightDensity = SAMPLE_TEXTURE3D(_CloudTex, sampler_CloudTex, lightRayOrigin);
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

            // float3 VolumetricRayMarch(float3 posCloud, float3 sizeCloud, float3 rO, float3 rD, float stepSize, float densityScale, float numLightSteps, 
            //                          float lightStepSize, float3 lightDir, float lightAbsorb,  float darknessThreshold, float transmittance)
            // {
            //     float3 cloudMin = posCloud - sizeCloud * 0.5;
            //     float3 cloudMax = posCloud + sizeCloud * 0.5;
                
            //     float density = 0;
            //     float transmission = 0;
            //     float lightAccumulation = 0;
            //     float finalLight = 0;

            //     for(int i=0; i < NUM_STEPS; i++)
            //     {
            //         rO += rD * stepSize;

            //         float3 samplePos = rO;

            //         bool inside = (samplePos >= cloudMin) && (samplePos <= cloudMax);
            //         if (!inside) continue;

            //         float3 uvw = (samplePos - cloudMin) / sizeCloud;
            //         // float sampledDensity = _CloudTex.Sample(sampler_CloudTex, uvw).r;
            //         float sampledDensity = SAMPLE_TEXTURE3D(_CloudTex, sampler_CloudTex, uvw).r;                    
            //         density += sampledDensity;

            //         float3 lightRayOrigin = uvw;

            //         for(int j=0; j < numLightSteps; j++)
            //         {
            //             lightRayOrigin += -lightDir * lightStepSize;
            //             // float lightDensity = SAMPLE_TEXTURE3D(_CloudTex, sampler_CloudTex, lightRayOrigin);
            //             float lightDensity = SAMPLE_TEXTURE3D(_CloudTex, sampler_CloudTex, lightRayOrigin);
            //             lightAccumulation += lightDensity;
            //         }

            //         float lightTransmission = exp(-lightAccumulation);
            //         float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);
            //         finalLight += density * transmittance * shadow;
            //         transmittance *= exp(-density * lightAbsorb);
            //     }

            //     transmission = exp(-density);

            //     float3 result = float3(finalLight, transmission, transmittance);
            //     return result;
            // }

            float4 Frag (Varyings input) : SV_Target
            {
                float4 color = 0;
                float3 camPos = _WorldSpaceCameraPos;

                // Calculate the local pos of the point in the near plane
                float3 viewPointLocal = float3(input.texcoord - 0.5, 1) * _ViewParams;
                // local to world
                float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1));

                float3 rD = normalize(viewPoint - camPos);

                float3 cloudPos = float3(0,0,0);
                float3 cloudSize = float3(5,5,5);
                float3 cloudMin = cloudPos - cloudSize * 0.5;
                float3 cloudMax = cloudPos + cloudSize * 0.5;

                float3 lightPos = float3(-100,-100,-100);
                float3 lightDir = normalize(cloudPos - lightPos);

                float3 result = VolumetricRayMarch(cloudPos, cloudSize, camPos, rD, 0.16, 0.41, 16, 0.33, lightDir, 2, 0, 0.68);

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
