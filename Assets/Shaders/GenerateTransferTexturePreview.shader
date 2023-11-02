Shader "Hidden/TransferTexture"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "white" {}
    }
    SubShader
    {
        ZTest Off 
		ZWrite Off
        Cull Off

        Pass
        {
            Name "GenerateTransferTexturePreview"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment GenerateTransferTexturePreviewFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"
            #include "Assets/Shaders/Library/DefaultInput.hlsl"

            struct Line
            {
                float x1;
                float x2;
                float y;
            };

            struct Box
            {
                half4 color;
                Line top;
                Line bottom;
                float minAlpha;
                float maxAlpha;
                int falloffType;
                float falloffStrength;
            };
            
            StructuredBuffer<Box> _BoxBuffer;
            int _NumBoxes;

            bool IntersectBox(float2 uv, Box box, out float contribution)
            {
                contribution = 0;

                if(uv.y < box.top.y && uv.y > box.bottom.y)
                {
                    

                    float height01 = (uv.y - box.bottom.y) / (box.top.y - box.bottom.y);
                    float leftX = box.bottom.x1 + (box.top.x1 - box.bottom.x1) * height01;
                    float rightX = box.bottom.x2 + (box.top.x2 - box.bottom.x2) * height01;

                    if (uv.x > leftX && uv.x < rightX)
                    {
                        float width01 = (uv.x - leftX) / (rightX - leftX);
                        float2 barys = float2(width01, height01);
                        
                        float x = pow(2 * abs(0.5 - barys.y), box.falloffStrength);
                        float y = pow(2 * abs(0.5 - barys.x), box.falloffStrength);

                        if(box.falloffType == 0)
                        {
                            contribution = (1 - y);
                            return 1;
                        }
                        else if(box.falloffType == 1)
                        {
                            float radius = 1 - sqrt(x * x + y * y);
                            contribution = radius;
                            return 1;
                        }
                    }
                }

                return 0;
            }

            half4 GenerateTransferTexturePreviewFragment(Varyings IN) : SV_TARGET
            {
                half4 color = 0;

                for(int i = 0; i < _NumBoxes; i++)
                {
                    Box box = _BoxBuffer[i];
                    float contribution;
                    if(IntersectBox(IN.uv, box, contribution))
                    {
                        color.rgb += box.color.rgb;

                        float alpha = lerp(box.minAlpha, box.maxAlpha, contribution);
                        color.a += alpha;
                    }
                }

                return color;
            }
            ENDHLSL
        }
    }
}