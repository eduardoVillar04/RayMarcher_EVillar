Shader "Custom/RayMarchShader"
{   

    SubShader
    {
        HLSLINCLUDE
        #define MAX_STEPS 100
        #define MAX_DIST 500
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

        // Light
        float3 _LightPos;

        // --------------------------------------------------------------------------- OBJ BUFFERS ---------------------------------------------------------------------------
        // [Default objs]
        // Objs that will be rendered without any effects
        StructuredBuffer<RM_Obj> _DefaultRMObjsBuffer; 
        int _DefaultRMObjsCount;


        // [Smooth objs]
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

        // --------------------------------------------------------------------------- CELL REPETITION ---------------------------------------------------------------------------
        bool _RepetitionActive;
        float3 _RepetitionCellSize;

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

            float sdCube(float3 p, float3 halfSize, float3 pos)
            {
                p -= pos;
                float3 q = abs(p) - halfSize;
                return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
            }

            float sdCross(float3 p, float halfWidth, float3 pos) 
            {
                p -= pos;
                const float3 corner = float3(halfWidth, halfWidth, halfWidth);
                float3 foldedPos = abs(p);

                float3 ctp = foldedPos - corner;

                float minComp = min(min(ctp.x, ctp.y), ctp.z);
                float maxComp = max(max(ctp.x, ctp.y), ctp.z);
    
                float midComp = ctp.x + ctp.y + ctp.z - minComp - maxComp;
    
                float2 closestOutsidePoint = max(float2(minComp, midComp), 0.0);
                float2 closestInsidePoint = min(float2(midComp, maxComp), 0.0);
    
                return length(closestOutsidePoint) + -length(closestInsidePoint);
            }

            float sdMengerSponge(float3 p, float cubeWidth, int numIterations, float3 pos)
            {
                float3 localP = p - pos;

                // Base cube
                float d = sdCube(localP, cubeWidth * 0.5, float3(0,0,0));

                float scale = 1.0;

                for (int i = 0; i < numIterations; i++)
                {
                    // Scale space for subdivisions
                    float3 q = localP * scale;

                    // Centered domain repetition
                    float3 cellIndex = round(q / cubeWidth);
                    q = q - cellIndex * cubeWidth;

                    // Cross is always in the center of the cell
                    // cross width is 3 times smaller than the cube, so halfwidth = cubeWidth/6
                    float crossDist = sdCross(q, cubeWidth / 6.0, float3(0,0,0));

                    // return the crossDist to world space dividing by the scale
                    d = max(d, -crossDist / scale);

                    scale *= 3.0;
                }

                return d;
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
                        d = sdCube(p, obj.size, obj.pos);
                        break;
                    case 2: // MENGER_SPONGE
                        d = sdMengerSponge(p, obj.size.x, obj.size.y, obj.pos);
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
            float BaseSDF(float3 p)
            {
                float d;
                int i = 0;
                RM_Obj obj;
                // Default rendering
                float minDefault = MAX_DIST;
                for(i = 0; i < _DefaultRMObjsCount; i++)
                {
                    RM_Obj obj = _DefaultRMObjsBuffer[i];
                    d = primitiveSDF(p, obj);
                    minDefault = min(minDefault, d);
                }

                // Smooth union
                float minSUnion = MAX_DIST;
                for(i = 0; i < _SmoothUnionObjsCount; i++)
                {
                    RM_Obj obj = _SmoothUnionObjsBuffer[i];
                    d = primitiveSDF(p, obj);
                    minSUnion = smoothMin(minSUnion, d, _SmoothKValue);
                }
                
                // Smooth subtraction
                // Applied on top of the sUnion distance
                for(i = 0; i < _SmoothSubtractionObjsCount; i++)
                {
                    RM_Obj obj = _SmoothSubtractionObjsBuffer[i];
                    d = primitiveSDF(p, obj);
                    minSUnion = smoothMax(minSUnion, -d, _SmoothKValue);
                }

                // Smooth intersection
                float minSIntersection = MAX_DIST;
                for(i = 0; i < _SmoothIntersectionObjsCount; i++)
                {
                    RM_Obj obj = _SmoothIntersectionObjsBuffer[i];
                    d = primitiveSDF(p, obj);
                    if(i == 0) minSIntersection = d;
                    minSIntersection = smoothMax(minSIntersection, d, _SmoothKValue);
                }
                
                // The minimum distance will be the closest to the camera, the one with least depth
                float minDist = min(minDefault, minSUnion);
                minDist = min(minDist, minSIntersection);
                return minDist;
            }

            float3 RepeatedSDF(float3 p)
            {
                float3 id = round(p / _RepetitionCellSize);
                float3 o = sign(p - _RepetitionCellSize * id);

                float d = 1e20;

                for (int z = 0; z < 2; z++)
                for (int y = 0; y < 2; y++)
                for (int x = 0; x < 2; x++)
                {
                    float3 rid = id + float3(x,y,z) * o;
                    float3 r = p - _RepetitionCellSize * rid;

                    d = min(d, BaseSDF(r));
                }

                return d;
            }

            float SDF(float3 p)
            {
                float3 d = MAX_DIST;

                if(_RepetitionActive)
                {
                    d = RepeatedSDF(p);
                }
                else
                {
                    d = BaseSDF(p);
                }

                return d;
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

            float3 RepeatRelative(float3 pos, float3 ref)
            {
                float3 id = floor(ref / _RepetitionCellSize); // cell pos in cell space
                return _RepetitionCellSize * id + pos;
            }

            float GetLight(float3 p) 
            {
                float3 lightPos = _LightPos;

                if(_RepetitionActive)
                {
                    lightPos = RepeatRelative(lightPos, p);
                }

                float3 l = normalize(lightPos-p);
                float3 n = GetNormal(p);
    
                float dif = clamp(dot(n, l), 0, 1);
                float d = RayMarch(p+n*SURF_DIST*2., l);
                if(d<length(lightPos-p)) dif *= .1;
    
                return dif;
            }

            bool CheckForDepth(float3 p, float2 uv)
            {
                // Hit pos from WS -> VS
                float3 pView = mul(UNITY_MATRIX_V, float4(p, 1)).xyz;
                // Unity cam looks in -z direction
                float rayDepth = -pView.z;

                // Sample depth texture
                float rawDepth = SampleSceneDepth(uv);
                // Denormalize it
                float eyeDepth = LinearEyeDepth(rawDepth);
                 
                // if(rayDepth > eyeDepth) discard;
                return rayDepth > eyeDepth;
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
                if(d >= MAX_DIST) return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord);
                
                float3 p = camPos + rD * d;
                
                if(CheckForDepth(p, input.texcoord)) return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord);

                float dif = GetLight(p);
                float depth = d / MAX_DIST;
                color = float4(dif, dif, dif, depth);
                return color;

            }


            
            ENDHLSL
        }
    }
}
