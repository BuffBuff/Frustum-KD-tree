#ifndef _BUFFERS_FX_
#define _BUFFERS_FX_

#include "Structs.fx"
#include "Constants.h"


cbuffer consts : register(c0)
{
	float4 cameraPos;
	float4x4 IP;
	float4x4 IV;
	int	nrOfTriangles;
	float3 pad;
};

cbuffer lights : register(c1)
{
	Light lightList[NROFLIGHTS];
};

cbuffer spheres : register(c2)
{
	Sphere sphereList[NROFLIGHTS];
};

#endif