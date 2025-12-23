Shader "Custom/RayMarchShader"
{   
    SubShader
    {
        HLSLINCLUDE
        #define MAX_STEPS 100
        #define MAX_DIST 100
        #define SURF_DIST 0.01

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
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

            
            float SphereSDF(float3 p, float4 s)
            {
                return length(p-s.xyz)-s.w;
            }

            float GetDist(float3 p) 
            {
                // For now render only a sphere

	            float4 s = float4(0, 0, 0, 1); // w -> radius
    
                float sphereDist = SphereSDF(p, s);
    
                return sphereDist;
            }

            float RayMarch(float3 rO, float3 rD)
            {
                float dO = 0;
                float dS = 0;
                float3 p = float3(0, 0, 0);

                for(int i=0; i<MAX_STEPS; i++) {
    	            p = rO + rD*dO;
        
                    dS = GetDist(p);
        
                    dO += dS;
                    if(dO>MAX_DIST || dS<SURF_DIST) break;
                }
    
                return dO;
            }

            float3 GetNormal(float3 p) 
            {
	            float d = GetDist(p);
                float2 e = float2(.01, 0);
    
                float3 n = d - float3(
                    GetDist(p-e.xyy),
                    GetDist(p-e.yxy),
                    GetDist(p-e.yyx));
    
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

            float4 Frag (Varyings input) : SV_Target
            {
                // float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord).rgba;
                float4 color = 0;
                float3 camPos = _WorldSpaceCameraPos;

                // 0,0 centered in screen and adjust for aspect ratio
                float2 uv = input.texcoord - 0.5;
                uv.x *= _ScreenParams.x / _ScreenParams.y;

                // Rays sould start in the near plane, like the real unity cameras (HARDCODED)
                // TODO : FOV
                float3 rD = normalize(float3(uv.x, uv.y, 0.3));
                // rD = normalize(mul((float3x3)UNITY_MATRIX_I_V, rD));
                // return float4(rD, 1);

                float rayMarchDist = RayMarch(camPos, rD);

                //Ignore far away points
                if(rayMarchDist >= MAX_DIST) discard;

                float3 p = camPos + rD * rayMarchDist;

                float dif = GetLight(p);
                color = float4(dif, dif, dif, 1);
                return color;

                // if(rayMarchDist <= 10) color = float4(1,1,1,1);
                // else discard;
                // return color;

            }


            
            ENDHLSL
        }
    }
}
