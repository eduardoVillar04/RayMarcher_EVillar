Shader "Custom/VolumetricRayMarchShader"
{   
    SubShader
    {
        HLSLINCLUDE
        #define NUM_STEPS 64
        #define LIGHT_NUM_STEPS 16
        #define MAX_DIST 500
        #define MAX_CLOUD_HITS 10

        struct CloudHit
        {
            float tEnter;
            float tExit;
            float3 pos;
            float3 size;
            float3 cloudMin;
            float3 cloudMax;
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


            float3 VolumetricRayMarch(float3 rO, float3 rD, float numSteps, float stepSize,float densityScale, float numLightSteps, float lightStepSize,
                                    float lightAbsorb, float darknessThreshold, float transmittance)
            {
                CloudHit hits[MAX_CLOUD_HITS];
                int hitCount = 0;

                // Gather all cloud intersections
                for (int i = 0; i < _CloudObjsCount && hitCount < MAX_CLOUD_HITS; i++)
                {
                    RM_Obj cloud = _CloudObjsBuffer[i];

                    float3 cloudMin = cloud.pos - cloud.size * 0.5;
                    float3 cloudMax = cloud.pos + cloud.size * 0.5;

                    float tEnter, tExit;
                    if (RayBoxSlabIntersection(rO, rD, cloudMin, cloudMax, tEnter, tExit))
                    {
                        // Ignore intersections behind camera
                        if (tExit > 0.0)
                        {
                            hits[hitCount].tEnter = max(tEnter, 0.0);
                            hits[hitCount].tExit  = tExit;
                            hits[hitCount].pos    = cloud.pos;
                            hits[hitCount].size   = cloud.size;
                            hitCount++;
                        }
                    }
                }

                if (hitCount == 0) return float3(0,1,1);

                // Sort hits front to back
                for (int i = 0; i < hitCount - 1; i++)
                {
                    for (int j = i + 1; j < hitCount; j++)
                    {
                        if (hits[j].tEnter < hits[i].tEnter)
                        {
                            CloudHit tmp = hits[i];
                            hits[i] = hits[j];
                            hits[j] = tmp;
                        }
                    }
                }

                // Raymarch each cloud segment
                float finalLight = 0.0;
                float totalDensity = 0.0;

                for (int c = 0; c < hitCount; c++)
                {
                    CloudHit h = hits[c];

                    float3 cloudMin = h.pos - h.size * 0.5;
                    float3 cloudMax = h.pos + h.size * 0.5;

                    float rayLength = h.tExit - h.tEnter;
                    float3 marchOrigin = rO + rD * h.tEnter;
                    float3 lightDir = normalize(h.pos - _LightPos);

                    for (int i = 0; i < numSteps; i++)
                    {
                        float dist = stepSize * i;
                        if (dist > rayLength)
                            break;

                        float3 samplePos = marchOrigin + rD * dist;
                        float3 uvw = (samplePos - cloudMin) / h.size;

                        // Sample density
                        float3 ddx = float3(stepSize / h.size.x, 0, 0);
                        float3 ddy = float3(0, stepSize / h.size.y, 0);
                        float densitySample = _CloudTex.SampleGrad(sampler_CloudTex, uvw, ddx, ddy).r * densityScale;

                        // If the density is too low ignore the point
                        if (densitySample <= 0.0001) continue;

                        totalDensity += densitySample;

                        // Light marching
                        float lightAccum = 0.0;
                        float3 lightPos = samplePos;

                        for (int j = 0; j < numLightSteps; j++)
                        {
                            lightPos -= lightDir * lightStepSize;
                            float3 lightUVW = (lightPos - cloudMin) / h.size;

                            float3 lddx = float3(lightStepSize / h.size.x, 0, 0);
                            float3 lddy = float3(0, lightStepSize / h.size.y, 0);
                            lightAccum += _CloudTex.SampleGrad(sampler_CloudTex, lightUVW, lddx, lddy).r;
                        }

                        float lightTransmission = exp(-lightAccum);
                        float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);

                        finalLight += densitySample * transmittance * shadow;
                        transmittance *= exp(-densitySample * lightAbsorb);

                        // If the trasmittance is already low stop (its already opaque enough)
                        if (transmittance < 0.01) break;
                    }

                    if (transmittance < 0.01) break;
                }

                float transmission = exp(-totalDensity);
                return float3(finalLight, transmission, transmittance);
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
