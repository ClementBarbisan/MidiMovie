Shader "Pixelate" {
    Properties {
        _CellSize ("Cell Size", Vector) = (0.02, 0.02, 0, 0)
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 200
       
        GrabPass { "_PixelationGrabTexture"}
       
        Pass {
            CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #include "UnityCG.cginc"
           
                struct v2f {
                    float4 pos : SV_POSITION;
                    float4 grabUV : TEXCOORD0;
                };
               
                float4 _CellSize;
               
                v2f vert(appdata_base v) {
                    v2f o;
                    o.pos = UnityObjectToClipPos(v.vertex);
                    o.grabUV = ComputeGrabScreenPos(o.pos);
                    return o;
                }
                StructuredBuffer<float3> _NotesData;
                uint _currentNote;
                sampler2D _PixelationGrabTexture;
           
                float4 frag(v2f IN) : COLOR {
                    float2 steppedUV = IN.grabUV.xy/IN.grabUV.w;
                    steppedUV /= _CellSize.xy * _NotesData[_currentNote].xy;
                    steppedUV = round(steppedUV);
                    steppedUV *= _CellSize.xy * _NotesData[_currentNote].xy;
                    return tex2D(_PixelationGrabTexture, steppedUV);
                }
            ENDCG
        }
    }
}