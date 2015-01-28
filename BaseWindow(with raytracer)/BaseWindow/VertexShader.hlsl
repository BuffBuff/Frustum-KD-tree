#include "resources.hlsl"

struct VS_INPUT
{
	float3 pos		: POSITION;
	float3 normal	: NORMAL;
	float2 tex		: TEXCOORD0;
};

struct PS_INPUT
{
	float4 pos		: SV_POSITION;
	float4 normal	: NORMAL;
	float2 tex		: TEXCOORD0;
};


PS_INPUT main(VS_INPUT _input)
{
	PS_INPUT output = (PS_INPUT)0;

	output.pos = float4(_input.pos, 1);
	//output.pos = mul(float4(_input.pos, 1), world);
	output.pos = mul(output.pos, view);

	output.pos = mul(output.pos, projection);

	//output.pos.w = 1;

	output.normal = mul(float4(_input.normal,1), world);
	output.normal = mul(output.normal, view);
	output.normal = mul(output.normal, projection);


	//output.normal = float4(_input.pos,1);

	output.tex = _input.tex;

	return output;
}
