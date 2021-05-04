Shader "Custom/RayMarching"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SizeTex("Size Texture", int) = 256
        _Index("Index", int) = 0
        _nbNote ("Number note", int) = 0
        _currentNote ("Current note", int) = 0
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                
                o.uv = v.uv;
                return o;
            }
            
            StructuredBuffer<float3> _Notes;
            StructuredBuffer<float3> _NotesData;
            sampler2D _MainTex;
            uint _Index;
            uint _SizeTex;
            uint _nbNote;
            uint _currentNote;
            fixed4x4 rotateY(float theta) 
            {
                float c = cos(theta);
                float s = sin(theta);
                return fixed4x4(
                    fixed4(c, 0, s, 0),
                    fixed4(0, 1, 0, 0),
                    fixed4(-s, 0, c, 0),
                    fixed4(0, 0, 0, 1)
                );
            }
            
            fixed4x4 rotateZ(float theta) 
            {
                float c = cos(theta);
                float s = sin(theta);
            
                return fixed4x4(
                    fixed4(c, -s, 0, 0),
                    fixed4(s, c, 0, 0),
                    fixed4(0, 0, 1, 0),
                    fixed4(0, 0, 0, 1)
                );
            }
            
            fixed4x4 rotateX(float theta) 
            {
                float c = cos(theta);
                float s = sin(theta);
            
                return fixed4x4(
                    fixed4(1, 0, 0, 0),
                    fixed4(0, c, -s, 0),
                    fixed4(0, s, c, 0),
                    fixed4(0, 0, 0, 1)
                );
            }
            fixed3 Displace(fixed3 pt, int index)
            {
                return fixed3(sin(pt.x), sin(pt.y),sin(pt.z));
//                return fixed3(sin(pt.x * _Notes[index].x), cos(pt.y * _Notes[index].y),sin(pt.z * _Notes[index].z));
            }
            fixed2 sdBoxFrame( fixed3 p, fixed3 b, float e, float i)
            {
              //p = abs(mul(transpose(rotateX(_Time.z)), mul(transpose(rotateZ(_Time.z)), mul(transpose(rotateY(_Time.y)), p))))-b;
              p = abs(mul(transpose(rotateX(_Time.z + _NotesData[i].y)), mul(transpose(rotateZ(_Time.z + _NotesData[i].x)), mul(transpose(rotateY(_Time.y + _NotesData[i].z)), p))))-b;
              fixed3 q = abs(p+e)-e;
              return fixed2(min(min(
                  length(max(fixed3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
                  length(max(fixed3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
                  length(max(fixed3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0)), i);
            }

            float dot2( in fixed3 v ) { return dot(v,v); }
            
            fixed2 udQuad( fixed3 p, fixed3 a, fixed3 b, fixed3 c, fixed3 d, int i )
            {
               p = mul(transpose(rotateX(_Time.z)), p);
               p = mul(transpose(rotateZ(_Time.z)), p);

              fixed3 ba = b - a; fixed3 pa = p - a;
              fixed3 cb = c - b; fixed3 pb = p - b;
              fixed3 dc = d - c; fixed3 pc = p - c;
              fixed3 ad = a - d; fixed3 pd = p - d;
              fixed3 nor = cross( ba, ad );

              return fixed2( sqrt(
                (sign(dot(cross(ba,nor),pa)) +
                 sign(dot(cross(cb,nor),pb)) +
                 sign(dot(cross(dc,nor),pc)) +
                 sign(dot(cross(ad,nor),pd))<3.0)
                 ?
                 min( min( min(
                 dot2(ba*clamp(dot(ba,pa)/dot2(ba),0.0,1.0)-pa),
                 dot2(cb*clamp(dot(cb,pb)/dot2(cb),0.0,1.0)-pb) ),
                 dot2(dc*clamp(dot(dc,pc)/dot2(dc),0.0,1.0)-pc) ),
                 dot2(ad*clamp(dot(ad,pd)/dot2(ad),0.0,1.0)-pd) )
                 :
                 dot(nor,pa)*dot(nor,pa)/dot2(nor) ), i);
            }
          
            fixed2 sdPlane( fixed3 p, fixed3 n, float h, int i )
            {
                // n must be normalized
                return fixed2(dot(p,n) + h, i);
            }
            
            fixed2 sdBox( fixed3 p, fixed3 b, int i )
            {
                fixed3 q = abs(mul(transpose(rotateX(_Time.x)), mul(transpose(rotateZ(_Time.z)), p))) - b;
                return fixed2(length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) + length(Displace(p, i) / 5), i);
            }
            
            fixed2 sphereSDF(fixed3 samplePoint, int i, float radius) 
            {
                return fixed2(length(samplePoint) + length(Displace(samplePoint, i)) - radius, i);
            }
          
          
          
           fixed2 opTwist(fixed3 p, fixed3 b, float r, int i)
            {
                float k =_NotesData[i].x; // or some other amount
                float c = cos(k*float(p.y));
                float s = sin(k*float(p.y));
                float2x2  m = float2x2(c,-s,s,c);
                fixed3 q = fixed3(mul(m,p.xz),p.y);
                //fixed3 v1 = 1.5*cos(_Time.x*1.1 + fixed3(0.0,1.0,1.0) + 0.0 );
	            //fixed3 v2 = 1.0*cos( _Time.x*1.2 + fixed3(0.0,2.0,3.0) + 2.0 );
	            //fixed3 v3 = 1.0*cos( _Time*1.3 + fixed3(0.0,3.0,5.0) + 4.0 );
                //fixed3 v4 = v1 + ( v3 - v2);
	            //return udQuad( v1, v2, v3, v4, q, i );
                //return udQuad(q, fixed3(5, -5, 1), fixed3(5, 5, 1), fixed3(-5, 5, 1),fixed3(-5, -5, 1),i);
                //return udQuad(q, q + fixed3(1, 0, -0), q + fixed3(1, 1, -0),q + fixed3(0, 1, -0),q + fixed3(0, 0, -0),i);
                return sdBoxFrame(q, b,r, i);
            } 
            
            fixed2 opU( fixed2 d1, fixed2 d2 )
            {
                return (d1.x<d2.x) ? d1 : d2;
            }

            fixed2 sceneSDF(fixed3 samplePoint) 
            {
                fixed2 res = fixed2(10000000.0, 0.0);
                for (int i = 0; i < _nbNote; i++)
                {
                   //res = opU(res, opTwist(samplePoint, 0, 0, _currentNote + i));
                   //res = opU(res, udQuad(samplePoint, fixed3(5, -5, -0), fixed3(5, 5, -0), fixed3(-5, 5, -0),fixed3(-5, -5, -0),_currentNote + i));
                   // res = opU(res, sphereSDF(samplePoint + fixed3(_NotesData[_currentNote + i].x, _Notes[_currentNote + i].y, _NotesData[_currentNote + i].z) / 200, _currentNote + i, _NotesData[_currentNote + i].y / 20));
                  // res = opU(res, sdBox(samplePoint + fixed3(_NotesData[_currentNote + i].x, _Notes[_currentNote + i].y, _NotesData[_currentNote + i].z) / 200, fixed3(1, 1, 1), _currentNote + i));
                  // res = opU(res, opTwist(samplePoint + fixed3(_NotesData[_currentNote + i].x, _NotesData[_currentNote + i].y, _NotesData[_currentNote + i].z), fixed3(_NotesData[_currentNote + i].x * 5, _NotesData[_currentNote + i].x * 5, _NotesData[_currentNote + i].x * 5), 0.3,_currentNote + i));
                   res = opU(res, opTwist(samplePoint + fixed3(_NotesData[_currentNote + i].x, _NotesData[_currentNote + i].y, _NotesData[_currentNote + i].z), fixed3(_NotesData[_currentNote + i].x * 5, _NotesData[_currentNote + i].x * 5, _NotesData[_currentNote + i].x * 5), _NotesData[_currentNote + i].y,_currentNote + i));
                }
                return res;
            }
            
            fixed2 shortestDistanceToSurface(fixed3 eye, fixed3 marchingDirection, float start, float end) 
            {
                float depth = start;
                for (int i = 0; i < 255; i++) {
                    fixed2 dist = sceneSDF(eye + depth * marchingDirection);
                    if (dist.x < 0.0001) {
                        return fixed2(depth, dist.y);
                    }
                    depth += dist.x;
                    if (depth >= end) {
                        return fixed2(end, 0);
                    }
                }
                return fixed2(end, 0);
            }
                        
            float3 rayDirection(float fieldOfView, fixed2 fragCoord) 
            {
                fixed2 xy = fragCoord - 0.5;
                float z = 1.0 / tan(radians(fieldOfView));
                return fixed3(xy, z);
            }
            /**
             * Using the gradient of the SDF, estimate the normal on the surface at point p.
             */
            fixed3 estimateNormal(fixed3 p) {
                return normalize(fixed3(
                    sceneSDF(fixed3(p.x + 0.0001, p.y, p.z)).x - sceneSDF(fixed3(p.x - 0.0001, p.y, p.z)).x,
                    sceneSDF(fixed3(p.x, p.y + 0.0001, p.z)).x - sceneSDF(fixed3(p.x, p.y - 0.0001, p.z)).x,
                    sceneSDF(fixed3(p.x, p.y, p.z  + 0.0001)).x - sceneSDF(fixed3(p.x, p.y, p.z - 0.0001)).x
                ));
            }

            /**
             * Lighting contribution of a single point light source via Phong illumination.
             * 
             * The fixed3 returned is the RGB color of the light's contribution.
             *
             * k_a: Ambient color
             * k_d: Diffuse color
             * k_s: Specular color
             * alpha: Shininess coefficient
             * p: position of point being lit
             * eye: the position of the camera
             * lightPos: the position of the light
             * lightIntensity: color/intensity of the light
             *
             * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
             */
            fixed3 phongContribForLight(fixed3 k_d, fixed3 k_s, float alpha, fixed3 p, fixed3 eye,
                                      fixed3 lightPos, fixed3 lightIntensity) {
                fixed3 N = estimateNormal(p);
                fixed3 L = normalize(lightPos - p);
                fixed3 V = normalize(eye - p);
                fixed3 R = normalize(reflect(-L, N));
                
                float dotLN = dot(L, N);
                float dotRV = dot(R, V);
                
                if (dotLN < 0.0) {
                    // Light not visible from this point on the surface
                    return fixed3(0.0, 0.0, 0.0);
                } 
                
                if (dotRV < 0.0) {
                    // Light reflection in opposite direction as viewer, apply only diffuse
                    // component
                    return lightIntensity * (k_d * dotLN);
                }
                return lightIntensity * (k_d * dotLN + k_s * pow(dotRV, alpha));
            }

            /**
             * Lighting via Phong illumination.
             * 
             * The fixed3 returned is the RGB color of that point after lighting is applied.
             * k_a: Ambient color
             * k_d: Diffuse color
             * k_s: Specular color
             * alpha: Shininess coefficient
             * p: position of point being lit
             * eye: the position of the camera
             *
             * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
             */
            fixed3 phongIllumination(fixed3 k_a, fixed3 k_d, fixed3 k_s, float alpha, fixed3 p, fixed3 eye) {
                const fixed3 ambientLight = 0.5 * fixed3(1.0, 1.0, 1.0);
                fixed3 color = ambientLight * k_a;
                
                fixed3 light1Pos = fixed3(4.0 * sin(_Time.x),
                                      2.0,
                                      4.0 * cos(_Time.x));
                fixed3 light1Intensity = fixed3(0.4, 0.4, 0.4);
                
                color += phongContribForLight(k_d, k_s, alpha, p, eye,
                                              light1Pos,
                                              light1Intensity);
                
                fixed3 light2Pos = fixed3(2.0 * sin(0.37 * _Time.x),
                                      2.0 * cos(0.37 * _Time.x),
                                      2.0);
                fixed3 light2Intensity = fixed3(0.4, 0.4, 0.4);
                
                color += phongContribForLight(k_d, k_s, alpha, p, eye,
                                              light2Pos,
                                              light2Intensity);    
                return color;
            }

            
             fixed4 frag (v2f i) : SV_Target
             {
                
                fixed2 curUv = fixed2(i.uv.x - 0.5, i.uv.y - 0.5);
                
                fixed3 dir = rayDirection(45.0, i.uv);
                fixed3 eye = fixed3(0.0, 0.0, -25.0);
                fixed2 dist = shortestDistanceToSurface(eye, dir, 0, 100);
                
                if (dist.x > 100 - 0.0001) {
                    // Didn't hit anything
                    return fixed4(0.0, 0.0, 0.0, 0.0);
                }
                fixed3 K_a = tex2D(_MainTex, fixed2(_Notes[dist.y].x % _SizeTex, _Notes[dist.y].x / _SizeTex));
                  if (int((curUv.x) * _SizeTex) % (int(distance(curUv, fixed2(0, 0)) * _SinTime.w * _NotesData[dist.y].z * 30) + 1)||  int((curUv.y) * _SizeTex) % (int(distance(curUv, fixed2(0, 0))*_SinTime.w * _NotesData[dist.y].z * 30) + 1))
                  {
                      if((curUv.x * curUv.x + curUv.y * curUv.y > 0.001 * _NotesData[dist.y].x / 2)
                        &&(curUv.y * curUv.y + curUv.x * curUv.x < 0.005 *_NotesData[dist.y].x / 2) ||
                      (curUv.x * curUv.x + curUv.y * curUv.y > 0.001 * _NotesData[dist.y].z * 10)
                      &&(curUv.y * curUv.y + curUv.x * curUv.x < 0.005 * _NotesData[dist.y].z * 10) ||
                         (curUv.x * curUv.x + curUv.y * curUv.y > 0.001 * _NotesData[dist.y].x * 70)
                         &&(curUv.y * curUv.y + curUv.x * curUv.x < 0.005 *_NotesData[dist.y].x * 70))
                      {
                          return (fixed4(K_a.xyz * 0.1,0));
                      }
                  }
                // return fixed4(1,1,1,1);
                fixed3 K_d = fixed3(0.2, 0.2, 0.2);
                fixed3 K_s = fixed3(1.0, 1.0, 1.0);
                float shininess = 10.0;
                
                fixed3 color = phongIllumination(K_a, K_d, K_s, shininess, eye + dist.x * dir, eye);
                return fixed4(color.xyz, 0);
               
              
            }
            ENDCG
        }
    }
}
