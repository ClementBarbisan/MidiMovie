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
                return fixed3(sin(20 * pt.x * _Notes[index].x), cos(20 * pt.y * _Notes[index].y),sin(20 * pt.z * _Notes[index].z));
            }
            fixed2 sdBoxFrame( fixed3 p, fixed3 b, float e, float i)
            {
              p = abs(mul(transpose(rotateX(_Time.x)), mul(transpose(rotateZ(_Time.z)), p)))-b;
              fixed3 q = abs(p+e)-e;
              return fixed2(min(min(
                  length(max(fixed3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
                  length(max(fixed3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
                  length(max(fixed3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0)), i);
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
                float k = 5.0; // or some other amount
                float c = cos(k*float(p.y));
                float s = sin(k*float(p.y));
                float2x2  m = float2x2(c,-s,s,c);
                fixed3 q = fixed3(mul(m,p.xz),p.y);
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
                   // res = opU(res, sphereSDF(samplePoint + fixed3(_NotesData[_currentNote + i].x, _Notes[_currentNote + i].y, _NotesData[_currentNote + i].z) / 200, _currentNote + i, _NotesData[_currentNote + i].y / 20));
                   //res = opU(res, sdBox(samplePoint + fixed3(_NotesData[_currentNote + i].x, _Notes[_currentNote + i].y, _NotesData[_currentNote + i].z) / 200, fixed3(1, 1, 1), _currentNote + i));
                   res = opU(res, opTwist(samplePoint + fixed3(_NotesData[_currentNote + i].x, _Notes[_currentNote + i].y/1000, _NotesData[_currentNote + i].z), fixed3(1, 1, 1), 0.3,_currentNote + i) + length(Displace(samplePoint + fixed3(_NotesData[_currentNote + i].x, _Notes[_currentNote + i].y/1000, _NotesData[_currentNote + i].z), i)/5));
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
            
            
             fixed4 frag (v2f i) : SV_Target
             {
                fixed2 fragCoord = fixed2(_Index % _SizeTex, _Index / _SizeTex);
                //fixed4 col = tex2D(_MainTex, fixed2(fragCoord.x / _SizeTex, fragCoord.y / _SizeTex));
                fixed3 dir = rayDirection(45.0, i.uv);
                //return fixed4(dir.x, dir.y, dir.z, 1);
                fixed3 eye = fixed3(0.0, 0.0, -5.0);
                fixed2 dist = shortestDistanceToSurface(eye, dir, 0, 100);
                
                if (dist.x > 100 - 0.0001) {
                    // Didn't hit anything
                    return fixed4(0.0, 0.0, 0.0, 0.0);
                }
                
                return tex2D(_MainTex, fixed2(_Notes[dist.y].x % _SizeTex, _Notes[dist.y].x / _SizeTex));
               
              
            }
            ENDCG
        }
    }
}
