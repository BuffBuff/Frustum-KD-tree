#ifndef _DEBUG_FX_
#define _DEBUG_FX_

#include "Buffers.fx"
#include "Collisions.fx"

float4 debugLightSpheres(Ray _r, float _dist)
{
	float hit = -1.0f;
	for (int i = 0; i < NROFLIGHTS; i++)
	{
		hit = RayVSSpere(sphereList[i], _r, _dist);
		if (hit > -1)
		{
			return sphereList[i].color;
		}
	}

	return float4(0,0,0,0);
}


#endif