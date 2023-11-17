Shader "Hidden/SetDepth"
{
    Properties
    {

    }
    SubShader
    {
        ZTest Off 
		ZWrite Off
        Cull Off

        Pass
        {
            Name "Depth"

            HLSLPROGRAM
            #pragma vertex DefaultVertex
            #pragma fragment DepthFragment
            #include "Assets/Shaders/Library/DefaultVertex.hlsl"

            half4 DepthFragment(Varyings IN) : SV_Target
            {
                return 0;
            }

            ENDHLSL
        }
    }
}