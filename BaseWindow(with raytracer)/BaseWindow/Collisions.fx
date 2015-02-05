#include "Buffers.fx"




float RayVSSpere(Sphere p_sphere,Ray p_ray, float _dist)
{
	float l_t;
	l_t = -1.0f;
	float distanceDelta = 0.001f;
	float4 length = float4((p_sphere.origin.xyz - p_ray.origin.xyz),0);
	//s = Projection of length onto ray direction
	float s = dot(length, p_ray.dir);
	float lengthSquared = dot(length, length);
	float radiusSquared = p_sphere.radie * p_sphere.radie;

	if(s < 0 && lengthSquared > radiusSquared)
	{
		//miss
		return -1;
	}
	//m = Squared distance from sphere center to projection
	float m = lengthSquared - (s*s);
	
	if(m > radiusSquared)
	{
		//miss
		return -1;
	}
	//q = Squared distance
	float q = sqrt(radiusSquared - m);
	if(lengthSquared > radiusSquared)
	{
		l_t = s - q;
		if(l_t < _dist || _dist < 0.0f && l_t > distanceDelta)
		{
			return l_t;
		}
		else return -1;
	}

	return -1;
}

float RayVSTriangle(TriangleMat p_tri,Ray p_ray,float _dist)
{
	float l_t;
	float distanceDelta = 0.001f;

	float4 e1 = p_tri.pos1 - p_tri.pos0;
	float4 e2 = p_tri.pos2 - p_tri.pos0;
	float3 q = cross(p_ray.dir.xyz, e2.xyz);
	float a = dot(e1.xyz, q);
	if(a > -0.00001f && a < 0.00001f)
	{
		//miss
		return -1;
	}

	float f = 1/a;
	float4 s = float4(p_ray.origin.xyz - p_tri.pos0.xyz,0);
	float u = f *(dot(s.xyz, q));
	if(u < 0.0f)
	{
		//miss
		return -1;
	}
	float3 r = cross(s.xyz, e1.xyz);
	float v = f * (dot(p_ray.dir.xyz, r));
	if(v < 0.0f || (u + v) > 1.0f)
	{
		//miss
		return -1;
	}
	l_t = f * (dot(e2.xyz, r));
	if ((l_t < _dist && l_t > distanceDelta) || (_dist < 0.0f && l_t > distanceDelta))
	{
		return l_t;
	}
	else return -1;
}
//
//float3 RayVSTriangle(ObjTriangle p_tri, Ray p_ray, float _dist)
//{
//	float l_t;
//	float distanceDelta = 0.001f;
//
//	float4 e1 = p_tri.pos[1] - p_tri.pos[0];
//		float4 e2 = p_tri.pos[2] - p_tri.pos[0];
//		float3 q = cross(p_ray.dir.xyz, e2.xyz);
//		float a = dot(e1.xyz, q);
//	if (a > -0.00001f && a < 0.00001f)
//	{
//		//miss
//		return -1;
//	}
//
//	float f = 1 / a;
//	float4 s = float4(p_ray.origin.xyz - p_tri.pos[0].xyz, 0);
//		float u = f *(dot(s.xyz, q));
//	if (u < 0.0f)
//	{
//		//miss
//		return -1;
//	}
//	float3 r = cross(s.xyz, e1.xyz);
//		float v = f * (dot(p_ray.dir.xyz, r));
//	if (v < 0.0f || (u + v) > 1.0f)
//	{
//		//miss
//		return -1;
//	}
//	l_t = f * (dot(e2.xyz, r));
//	if ((l_t < _dist && l_t > distanceDelta) || (_dist < 0.0f && l_t > distanceDelta))
//	{
//		float2 index = ((1 - u - v) * p_tri.texCx) + (u * p_tri.texCy) + (v * p_tri.texCz);
//			return float3(l_t, index);
//	}
//	
//	return float3(-1,0,0);
//}
