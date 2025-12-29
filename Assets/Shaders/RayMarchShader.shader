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

        // Default objs
        StructuredBuffer<RM_Obj> _DefaultRMObjsBuffer; // Objs that will be rendered without any effects
        int _DefaultRMObjsCount;

        // Smooth objs
        float _SmoothKValue;

        // Smooth union
        // These objs will be blended together
        StructuredBuffer<RM_Obj> _SmoothUnionObjsBuffer; 
        int _SmoothUnionObjsCount;

        // Smooth subtraction
        // These objs will smoothly subtract from the volume of smooth union objs
        StructuredBuffer<RM_Obj> _SmoothSubtractionObjsBuffer; 
        int _SmoothSubtractionObjsCount;

        // Smooth intersection
        // Only the intersecting volume of these objs when colliding with another of the same type will be rendered
        StructuredBuffer<RM_Obj> _SmoothIntersectionObjsBuffer; 
        int _SmoothIntersectionObjsCount;

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
            
            // SDFs for primitives
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

            // Blending
            float smoothMax(float a, float b, float k)
            {
                return log(exp(a*k)+exp(b*k))/k;
            }

            float smoothMin(float a, float b, float k)
            {
                return -smoothMax(-a,-b,k);
            }


            // SDF function that varies depending on operation type
            float SDF(float3 p)
            {
                float d;

                // p = frac(p / 5) * 5; //espacio plegado en casilla 5x5

                // Default rendering
                float minDefault = 9999999;
                for(int i = 0; i < _DefaultRMObjsCount; i++)
                {
                    RM_Obj obj = _DefaultRMObjsBuffer[i];
                    d = primitiveSDF(p, obj);
                    minDefault = min(minDefault, d);
                }

                // Smooth union
                float minSUnion = 9999999;
                for(int i = 0; i < _SmoothUnionObjsCount; i++)
                {
                    RM_Obj obj = _SmoothUnionObjsBuffer[i];
                    d = primitiveSDF(p, obj);
                    minSUnion = smoothMin(minSUnion, d, _SmoothKValue);
                }
                
                // Smooth subtraction
                // Applied on top of the sUnion distance
                for(int i = 0; i < _SmoothSubtractionObjsCount; i++)
                {
                    RM_Obj obj = _SmoothSubtractionObjsBuffer[i];
                    d = primitiveSDF(p, obj);
                    minSUnion = smoothMax(minSUnion, -d, _SmoothKValue);
                }

                // Smooth intersection
                float minSIntersection = -9999999;
                for(int i = 0; i < _SmoothIntersectionObjsCount; i++)
                {
                    RM_Obj obj = _SmoothIntersectionObjsBuffer[i];
                    d = primitiveSDF(p, obj);
                    minSIntersection = smoothMax(minSIntersection, d, _SmoothKValue);
                }
                
                // The minimum distance will be the closest to the camera, the one with least depth
                float minDist = min(minDefault, minSUnion);
                minDist = min(minDist, minSIntersection);

                return minDist;
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
                float4 color = 0;
                float3 camPos = _WorldSpaceCameraPos;

                // Calculate the local pos of the point in the near plane
                float3 viewPointLocal = float3(input.texcoord - 0.5, 1) * _ViewParams;
                // local to world
                float3 viewPoint = mul(_CamLocalToWorldMatrix, float4(viewPointLocal, 1));

                float3 rD = normalize(viewPoint - camPos);

                float d = RayMarch(camPos, rD);

                //Ignore far away or occluded points
                if(d >= MAX_DIST) discard;
                
                float3 p = camPos + rD * d;
                
                CheckForDepth(p, input.texcoord);

                float dif = GetLight(p);
                color = float4(dif, dif, dif, 1);
                return color;
            }


            
            ENDHLSL
        }
    }
}
