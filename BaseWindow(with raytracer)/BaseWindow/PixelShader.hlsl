#include "resources.hlsl"

struct PS_INPUT
{
	float4 pos		: SV_POSITION;
	float4 normal	: NORMAL;
	float2 tex		: TEXCOORD0;
};

//Texture2D tex		: register(t0);

float4 main(PS_INPUT _input) : SV_TARGET
{


	//return tex.Sample(samLinear, _input.tex);
	return float4(_input.normal.xyz, 1.0f);
}
