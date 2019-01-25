Shader "Custom/Volume"
{
    Properties
    {
        _Color ("Main Color", Color) = (1.0,.0,.0,1)
        _Radius ("Radius", float) = 1
        _MinDistance("Min Distance", float) = 0.01
        _DiffuseColor("Diffuse Color", COLOR) = (1,1,1,1)
        _SpecularColor("Specular Color", COLOR) = (1,1,1,1)
        _DiffuseVal("DiffuseVal", Range(0,10)) = 0.5
        _SpecVal("SpecVal", Range(0,10)) = 0.5
        _Shininess("Shininess", Range(0,100)) = 1.0
    }
    SubShader {

        Tags 
        { 
            "RenderType"="Opaque" 
        }

        Pass
        {
            CGPROGRAM
            #define RAY_STEPS 64
            #define matRotateX(rad) float3x3(1,0,0,0,cos(rad),-sin(rad),0,sin(rad),cos(rad))
            #define matRotateY(rad) float3x3(cos(rad),0,-sin(rad),0,1,0,sin(rad),0,cos(rad))

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;// Clip space
                float3 wpos : TEXCOORD0; // World position
            };

            float4 _Color;
            float _Radius;
            float _MinDistance;
            float4 _DiffuseColor;
            float4 _SpecularColor;
            float _DiffuseVal;
            float _SpecVal;
            float _Shininess;

            float3 mod(float3 a, float3 b)
            {
                return frac(abs(a / b)) * abs(b);
            }

            float sdBox( float3 p, float3 b )
            {
              float3 d = abs(p) - b;
              return length(max(d,0.0)) + min(max(d.x,max(d.y,d.z)),0.0); 
            }

            float field(float3 p) {
                float time = _Time.y;
                float s = 0.2+sin(p.y+time*2.0)*0.15+cos(p.x+time*1.5)*0.15;
                p.y -= time*1.2;
                p.x += sin(p.y+time*2.0);
                p = mul(p,matRotateY(radians(-time*10.0)));
                p = mod(p-0.4,0.8)-0.4;
                return length(p)-(s*0.5);
            }
            
            float map (float3 p)
            {
                float speed = _Time.w*3.0;
                float s = 1.5+sin(p.y+_Time.y*1.2)*0.5;
                return field(p);
                //float r = 0.3;
                //return max(length(p)-r,field(p));
                /*
                p = mod(p,0.3)-0.15;
                return length(p) - _Radius;
                */
            }

            float3 normalMap (float3 p) {
                const float eps = 0.01;
                return normalize (
                    float3 (
                        map(p + float3(eps, 0, 0)   ) - map(p - float3(eps, 0, 0)),
                        map(p + float3(0, eps, 0)   ) - map(p - float3(0, eps, 0)),
                        map(p + float3(0, 0, eps)   ) - map(p - float3(0, 0, eps))
                    )
                );
            }

            fixed4 raymarching (float3 position, float3 direction)
            {
                for (int i = 0; i < RAY_STEPS; i++)
                {
                    float dist = map(position);
                    if (dist < _MinDistance)
                    {
                        float3 n = normalMap(position);

                        fixed3 lightDir = _WorldSpaceLightPos0.xyz; // directional light direction
                        fixed3 lightCol = _LightColor0.rgb;     // directional light color
                        float3 L = lightDir-direction;

                        float3 R = normalize(-reflect(L, n));

                        fixed lambert = max(0,dot(n, lightDir));
                        fixed4 c = fixed4(0.0,0.0,0.0,0.0);
                        c.rgb = _Color * lightCol * lambert;
                        c.a = 1;

                        // specular
                        float specVal = _SpecVal;
                        float shininess = _Shininess;
                        float spec = specVal * pow(max(dot(R, n), 0.0), 0.3*shininess);
                        spec = clamp(spec, 0.0, 1.0);

                        float diffuse = clamp(_DiffuseVal*dot(lightDir, n), 1.0, 1.0);

                        return _Color+c+(_DiffuseColor*diffuse)+ (_SpecularColor*spec);
                    }

                    position += dist * direction;
                }
                return fixed4(1,1,1,-1.0);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 worldPos = i.wpos;
                float3 viewDir = normalize(i.wpos - _WorldSpaceCameraPos);

                // Calculate the ray from Unity Main Camera.
                fixed4 res = raymarching (worldPos, viewDir);

                // discard bg
                if(res.a == -1.0){
                    discard;
                }

                return res;
            }


            ENDCG
        }

    }
}
