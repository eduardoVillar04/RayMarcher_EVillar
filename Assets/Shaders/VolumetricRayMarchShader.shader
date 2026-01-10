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
        };

        float4x4 _CamLocalToWorldMatrix;
        float3 _ViewParams;

        struct RM_Obj
        {
            int primType;
            int opType;
            float3 pos;
            float3 size;
        };

        Texture3D<float> _CloudTex;
        SamplerState sampler_CloudTex;

        Texture2D<float4> _RayMarchTex;
        SamplerState sampler_RayMarchTex;

        StructuredBuffer<RM_Obj> _CloudObjsBuffer;
        int _CloudObjsCount;

        float3 _LightPos;

        float _StepSize;
        float _DensityScale;
        float _LightStepSize;
        float _LightAbsorb;
        float _DarknessThreshold;
        float _Transmittance;

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        ENDHLSL

        Tags { "RenderType"="Opaque" }
        LOD 100
        ZWrite Off
        Cull Off

        Pass
        {
            Name "VolumetricRayMarchShader"
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag

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

            float3 VolumetricRayMarch(float3 rO, float3 rD, float2 uv, float stepSize, float densityScale, float numLightSteps, float lightStepSize,
                                      float lightAbsorb, float darknessThreshold, float transmittance)
            {
                CloudHit hits[MAX_CLOUD_HITS];
                int hitCount = 0;

                // Get ray intersections with clouds
                for(int i = 0; i < _CloudObjsCount && hitCount < MAX_CLOUD_HITS; i++)
                {
                    RM_Obj cloud = _CloudObjsBuffer[i];
                    float3 cloudMin = cloud.pos - cloud.size * 0.5;
                    float3 cloudMax = cloud.pos + cloud.size * 0.5;

                    float tEnter, tExit;
                    if(RayBoxSlabIntersection(rO, rD, cloudMin, cloudMax, tEnter, tExit) && tExit > 0.0)
                    {
                        hits[hitCount].tEnter = max(tEnter, 0.0);
                        hits[hitCount].tExit  = tExit;
                        hits[hitCount].pos    = cloud.pos;
                        hits[hitCount].size   = cloud.size;
                        hitCount++;
                    }
                }

                if(hitCount == 0) return float3(0,1,1);

                // Order by dist tEnter
                for(int i = 0; i < hitCount - 1; i++)
                {
                    for(int j = i + 1; j < hitCount; j++)
                    {
                        if(hits[j].tEnter < hits[i].tEnter)
                        {
                            CloudHit tmp = hits[i];
                            hits[i] = hits[j];
                            hits[j] = tmp;
                        }
                    }
                }

                float finalLight = 0.0;
                float totalDensity = 0.0;

                // Depth Ray marching objects
                float rmdepth = SAMPLE_TEXTURE2D_X(_RayMarchTex, sampler_RayMarchTex, uv).a * MAX_DIST;

                for(int c = 0; c < hitCount; c++)
                {
                    CloudHit h = hits[c];

                    // When clouds start being behind the object stop raymarching
                    if(h.tEnter > rmdepth) break;

                    float3 cloudMin = h.pos - h.size * 0.5;
                    float3 rayOrigin = rO + rD * h.tEnter;
                    float rayLength = h.tExit - h.tEnter;
                    float3 lightDir = normalize(h.pos - _LightPos);

                    for(int i = 0; i < NUM_STEPS; i++)
                    {
                        float dist = stepSize * i;
                        if(dist > rayLength) break;

                        float3 samplePos = rayOrigin + rD * dist;
                        float3 uvw = (samplePos - cloudMin) / h.size;

                        float3 ddx = float3(stepSize / h.size.x, 0, 0);
                        float3 ddy = float3(0, stepSize / h.size.y, 0);
                        float densitySample = _CloudTex.SampleGrad(sampler_CloudTex, uvw, ddx, ddy).r * densityScale;
                        if(densitySample <= 0.0001) continue;

                        totalDensity += densitySample;

                        // Light ray march
                        float lightAccum = 0.0;
                        float3 lightPos = samplePos;
                        for(int j = 0; j < numLightSteps; j++)
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
                        if(transmittance < 0.01) break;
                    }

                    if(transmittance < 0.01) break;
                }

                float transmission = exp(-totalDensity);
                return float3(finalLight, transmission, transmittance);
            }

            float4 Frag(Varyings input) : SV_Target
            {
                float3 camPos = _WorldSpaceCameraPos;
                float3 viewPointLocal = float3(input.texcoord - 0.5, 1) * _ViewParams;
                float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1));
                float3 rD = normalize(viewPoint - camPos);

                float3 result = VolumetricRayMarch(camPos, rD, input.texcoord,
                                                   _StepSize, _DensityScale, LIGHT_NUM_STEPS, _LightStepSize,
                                                   _LightAbsorb, _DarknessThreshold, _Transmittance);

                float3 lightCloudColor = float3(1,1,1);
                float3 darkCloudColor = float3(0.2,0.2,0.2);
                float3 finalCloudColor = lerp(darkCloudColor, lightCloudColor, result.r);
                float finalAlpha = 1 - result.g;

                float4 rayCol = SAMPLE_TEXTURE2D_X(_RayMarchTex, sampler_RayMarchTex, input.texcoord);
                float rmdepth = rayCol.a * MAX_DIST;

                // If the cloud is behind the object dont blend
                float3 outRGB;
                if(result.g > 0.99)
                    outRGB = rayCol.rgb;
                else
                    outRGB = lerp(rayCol.rgb, finalCloudColor, finalAlpha);

                return float4(outRGB, 1.0);
            }

            ENDHLSL
        }
    }
}
