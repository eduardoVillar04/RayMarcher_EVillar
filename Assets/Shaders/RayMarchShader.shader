Shader "Custom/RayMarchShader"
{   

    SubShader
    {
        HLSLINCLUDE
        #define MAX_STEPS 100
        #define MAX_DIST 100
        #define SURF_DIST 0.01

        float4x4 _CamLocalToWorldMatrix; // cam.transform.localToWorldMatrix 
        float3 _ViewParams; // planeHeight, planeWidth, cam.nearClipPlane

        struct RM_Obj
        {
            int primType;
            int opType;
            float3 pos;
            float3 size;
        };

        StructuredBuffer<RM_Obj> _DefaultRMObjsBuffer; // Objs that will be rendered without any effects
        int _DefaultRMObjsCount;

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl" // _CameraDepthTexture
        ENDHLSL

        Tags { "RenderType"="Opaque" }
        LOD 100
        ZWrite Off Cull Off
        Pass
        {
            Name "RayMarchShader"

            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment Frag

            // From UnityCG.cginc
            inline float LinearEyeDepth (float z)
            {
	            return 1.0 / (_ZBufferParams . z * z + _ZBufferParams . w);
            }
            
            float sdSphere(float3 p, float4 s)
            {
                return length(p-s.xyz)-s.w;
            }

            float sdBox(float3 p, float3 halfSize, float3 pos)
            {
                p -= pos;
                float3 q = abs(p) - halfSize;
                return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
            }

            // float SDF(float3 p) 
            // {
	           //  float4 s = float4(3, 0, 0, 0.5); // w -> radius
            //     float3 bB= float3(0.5,0.5,0.5);
    
            //     float sphereDist = sdSphere(p, s);
            //     float boxDist = sdBox(p, bB, float3(3,1,0));
    
            //     return min(sphereDist, boxDist);
            // }

            float primitiveSDF(float3 p, RM_Obj obj)
            {
                float d = 0;

                switch(obj.primType)
                {
                    case 0: // SPHERE
                        float4 s;
                        s.xyz = obj.pos;
                        s.w = obj.size.x;
                        d = sdSphere(p, s);
                        break;
                    case 1: // BOX
                        d = sdBox(p, obj.size, obj.pos);
                        break;
                }

                return d;
            }
            
            float SDF(float3 p)
            {
                float minD = 9999999;

                for(int i = 0; i < _DefaultRMObjsCount; i++)
                {
                    RM_Obj obj = _DefaultRMObjsBuffer[i];
                    float d = primitiveSDF(p, obj);
                    minD = min(minD, d);
                }

                return minD;
            }


            float RayMarch(float3 rO, float3 rD)
            {
                float dO = 0;
                float dS = 0;
                float3 p = float3(0, 0, 0);

                for(int i=0; i<MAX_STEPS; i++) {
    	            p = rO + rD*dO;
        
                    dS = SDF(p);
        
                    dO += dS;
                    if(dO>MAX_DIST || dS<SURF_DIST) break;
                }
    
                return dO;
            }

            float3 GetNormal(float3 p) 
            {
	            float d = SDF(p);
                float2 e = float2(.01, 0);
    
                float3 n = d - float3(
                    SDF(p-e.xyy),
                    SDF(p-e.yxy),
                    SDF(p-e.yyx));
    
                return normalize(n);
            }

            float GetLight(float3 p) 
            {
                float3 lightPos = float3(0, 5, 0);

                float3 l = normalize(lightPos-p);
                float3 n = GetNormal(p);
    
                float dif = clamp(dot(n, l), 0, 1);
                float d = RayMarch(p+n*SURF_DIST*2., l);
                if(d<length(lightPos-p)) dif *= .1;
    
                return dif;
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

            float4 Frag (Varyings input) : SV_Target
            {
                // float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord).rgba;
                float4 color = 0;
                float3 camPos = _WorldSpaceCameraPos;

                // Calculate the local pos of the point in the near plane
                float3 viewPointLocal = float3(input.texcoord - 0.5, 1) * _ViewParams;
                // local to world
                float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1));

                float3 rD = normalize(viewPoint - camPos);

                float rayMarchDist = RayMarch(camPos, rD);
                
                float3 p = camPos + rD * rayMarchDist;
                
                CheckForDepth(p, input.texcoord);

                //Ignore far away or occluded points
                if(rayMarchDist >= MAX_DIST) discard;


                float dif = GetLight(p);
                color = float4(dif, dif, dif, 1);
                return color;
            }


            
            ENDHLSL
        }
    }
}
