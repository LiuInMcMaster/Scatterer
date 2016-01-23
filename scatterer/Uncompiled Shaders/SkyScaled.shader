﻿Shader "Proland/Atmo/Sky" 
{
	SubShader 
	{
		//Tags {"Queue" = "Background" "RenderType"="" }
		 Tags {"QUEUE"="Geometry+1" "IgnoreProjector"="True" }
	
    	Pass 
    	{
    	 Tags {"QUEUE"="Geometry+1" "IgnoreProjector"="True" }
    		ZWrite Off
    		ZTest Off
    		
    		cull Front
    
    		Blend One One  //additive blending

			CGPROGRAM
			#include "UnityCG.cginc"
			//#pragma only_renderers d3d9
			#pragma glsl
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Utility.cginc"
			#include "AtmosphereNew.cginc"
			
			
			//uniform float _Alpha_Cutoff;
			uniform float _viewdirOffset;
			uniform float _experimentalAtmoScale;
			
			uniform float _sunglareScale;
			uniform float _Alpha_Global;
			uniform float4x4 _Globals_CameraToWorld;
			uniform float4x4 _Globals_ScreenToCamera;
			uniform float3 _Globals_WorldCameraPos;
			uniform float3 _Globals_Origin;
			uniform float _Globals_ApparentDistance;
			uniform float _RimExposure;
			
			uniform float _rimQuickFixMultiplier;
			
			uniform sampler2D _Sun_Glare;
			uniform float3 _Sun_WorldSunDir;
			uniform float4x4 _Sun_WorldToLocal;
			
			struct v2f 
			{
    			float4 pos : SV_POSITION;
    			float2 uv : TEXCOORD0;
    			float3 dir : TEXCOORD1;
    			float3 relativeDir : TEXCOORD2;
			};
			

			v2f vert(appdata_base v)
			{
				v2f OUT;
			    OUT.dir = (mul(_Globals_CameraToWorld, float4((mul(_Globals_ScreenToCamera, v.vertex)).xyz, 0.0))).xyz;
			    ///OUT.dir = float3(1.0,0.0,0.0);

			   //float3x3 wtl = float3x3(_Sun_WorldToLocal);
			    float3x3 wtl = _Sun_WorldToLocal;
			    
			    // apply this rotation to view dir to get relative viewdir
			    OUT.relativeDir = mul(wtl, OUT.dir);
    
    			OUT.pos = float4(v.vertex.xy, 1.0, 1.0);
    			OUT.uv = v.texcoord.xy;
    			return OUT;
			}
			
			
			// assumes sundir=vec3(0.0, 0.0, 1.0)
			float3 OuterSunRadiance(float3 viewdir)
			{
			    float3 data = viewdir.z > 0.0 ? tex2D(_Sun_Glare, float2(0.5,0.5) + viewdir.xy * 4.0/_sunglareScale).rgb : float3(0,0,0);
			    
			    
			    return pow(max(float3(0.0,0.0,0.0),data), 2.2) * _Sun_Intensity;
			 			
			}
			
			//stole this from basic GLSL raytracing shader somewhere on the net
			//a quick google search and you'll find it
			float intersectSphere3(float3 p1, float3 d, float3 p3, float r)
			{
			// p1 starting point
			// d look direction
			// p3 is the sphere center

				float a = dot(d, d);
				float b = 2.0 * dot(d, p1 - p3);
				float c = dot(p3, p3) + dot(p1, p1) - 2.0 * dot(p3, p1) - r*r;

				float test = b*b - 4.0*a*c;

				if (test<0)
				{
					return -1.0;
				}

//#if !defined(SHADER_API_D3D9)	
  					float u = (-b - sqrt(test)) / (2.0 * a);
//#else 
//					float u = (-b - SQRT(test,1e30)) / (2.0 * a);
//#endif 					
//  					float3 hitp = p1 + u * (p2 - p1);			//we'll just do this later instead if needed
//  					return(hitp);
					return u;
			}
			
			
			float3 SkyRadiance2(float3 camera, float3 viewdir, float3 sundir, out float3 extinction)//, float shaftWidth)
			{
			extinction = float3(1,1,1);
			float3 result = float3(0,0,0);
	
			float Rt2=Rt;
			Rt=Rg+(Rt-Rg)*_experimentalAtmoScale;
	
	
			viewdir.x+=_viewdirOffset;
			viewdir=normalize(viewdir);

			//camera *= scale;
			//camera += viewdir * max(shaftWidth, 0.0);
			float r = length(camera);
			float rMu = dot(camera, viewdir);
			float mu = rMu / r;
			float r0 = r;
			float mu0 = mu;
	
#if !defined(SHADER_API_D3D9)
			float deltaSq = sqrt(rMu * rMu - r * r + Rt*Rt);
#else
    		float deltaSq = SQRT(rMu * rMu - r * r + Rt*Rt,1e30);
#endif

        
    		float din = max(-rMu - deltaSq, 0.0);
    		if (din > 0.0)
    		{
        		camera += din * viewdir;
        		rMu += din;
        		mu = rMu / Rt;
        		r = Rt;
    		}
	
			float nu = dot(viewdir, sundir);
    		float muS = dot(camera, sundir) / r;
    
    		float4 inScatter = Texture4D(_Sky_Inscatter, r, rMu / r, muS, nu);
    
    		extinction = Transmittance(r, mu);
    
    		if (r <= Rt) 
    		{
            
//        if (shaftWidth > 0.0) 
//        {
//            if (mu > 0.0) {
//                inScatter *= min(Transmittance(r0, mu0) / Transmittance(r, mu), 1.0).rgbr;
//            } else {
//                inScatter *= min(Transmittance(r, -mu) / Transmittance(r0, -mu0), 1.0).rgbr;
//            }
//        }
        

        			float3 inScatterM = GetMie(inScatter);
        			float phase = PhaseFunctionR(nu);
        			float phaseM = PhaseFunctionM(nu);
        			result = inScatter.rgb * phase + inScatterM * phaseM;
    			}
    
         		else
    			{
    				result = float3(0,0,0);
    				extinction = float3(1,1,1);
    			} 

    			return result * _Sun_Intensity;
    		}
    
			
								
			float4 frag(v2f IN) : COLOR
			{
			
			    
			    float3 WSD = _Sun_WorldSunDir;
			    float3 WCP = _Globals_WorldCameraPos;

			    float3 d = normalize(IN.dir);
			    
				float interSectPt= intersectSphere3(WCP - _Globals_Origin*_Globals_ApparentDistance,IN.dir,_Globals_Origin,Rg*_rimQuickFixMultiplier);

				bool rightDir = (interSectPt > 0) ;
				if (!rightDir)
				{
					_Exposure=_RimExposure;
				}


			    float3 sunColor = OuterSunRadiance(IN.relativeDir);

			    float3 extinction;
//			    float3 inscatter = SkyRadiance(WCP - _Globals_Origin*_Globals_ApparentDistance, d, WSD, extinction);
			    float3 inscatter = SkyRadiance2(WCP - _Globals_Origin*_Globals_ApparentDistance, d, WSD,extinction);
//			    float3 inscatter = SkyRadiance2(WCP - _Globals_Origin, d, WSD,extinction);
			    //float3 inscatter = SkyRadiance(WCP + _Globals_Origin, float3(0.0,0.0,0.0), WSD, extinction, 0.0);
			    //float3 inscatter = float3(0,0,0);

			    //float3 finalColor = sunColor;// * extinction;// + inscatter;
			    float3 finalColor = sunColor * extinction + inscatter;
			    
//			    float absValue=abs(finalColor);
//			    bool idek= absValue <= _Alpha_Cutoff;
//			    if (_Alpha_Cutoff==0.0){
//			    _Alpha_Cutoff=0.0001;
//			    }
			    
			    
//			    
//			    if (idek ){
//			    
//			    return float4 (hdr(finalColor),(_Alpha_Global);}
//			    else

				//checking for sphere intersection to apply different HDR values to the planet and the atmosphere edge
//			    float interSectPt= intersectSphere2(WCP - _Globals_Origin*_Globals_ApparentDistance,WCP - _Globals_Origin*_Globals_ApparentDistance+d,_Globals_Origin,Rg);


			    
				return float4(_Alpha_Global*hdr(finalColor),1.0);			    
			   //return float4(finalColor,1);
			//return float4(0.0,0.0,0.0,0.0);

			}
			
			ENDCG

    	}
	}
}










