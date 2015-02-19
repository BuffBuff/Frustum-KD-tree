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

//float RayVSTriangle(TriangleMat p_tri,Ray p_ray,float _dist)
//{
//	float l_t;
//	float distanceDelta = 0.001f;
//
//	float4 e1 = p_tri.pos1 - p_tri.pos0;
//	float4 e2 = p_tri.pos2 - p_tri.pos0;
//	float3 q = cross(p_ray.dir.xyz, e2.xyz);
//	float a = dot(e1.xyz, q);
//	if(a > -0.00001f && a < 0.00001f)
//	{
//		//miss
//		return -1;
//	}
//
//	float f = 1/a;
//	float4 s = float4(p_ray.origin.xyz - p_tri.pos0.xyz,0);
//	float u = f *(dot(s.xyz, q));
//	if(u < 0.0f)
//	{
//		//miss
//		return -1;
//	}
//	float3 r = cross(s.xyz, e1.xyz);
//	float v = f * (dot(p_ray.dir.xyz, r));
//	if(v < 0.0f || (u + v) > 1.0f)
//	{
//		//miss
//		return -1;
//	}
//	l_t = f * (dot(e2.xyz, r));
//	if ((l_t < _dist && l_t > distanceDelta) || (_dist < 0.0f && l_t > distanceDelta))
//	{
//		return l_t;
//	}
//	else return -1;
//}

float3 RayVSTriangleMat(TriangleMat p_tri, Ray p_ray, float _dist)
{
	float l_t;
	float distanceDelta = 0.001f;

	float4 e1 = p_tri.pos1 - p_tri.pos0;
		float4 e2 = p_tri.pos2 - p_tri.pos0;
		float3 q = cross(p_ray.dir.xyz, e2.xyz);
		float a = dot(e1.xyz, q);
	if (a > -0.00001f && a < 0.00001f)
	{
		//miss
		return -1;
	}

	float f = 1 / a;
	float4 s = float4(p_ray.origin.xyz - p_tri.pos0.xyz, 0);
		float u = f *(dot(s.xyz, q));
	if (u < 0.0f)
	{
		//miss
		return -1;
	}
	float3 r = cross(s.xyz, e1.xyz);
		float v = f * (dot(p_ray.dir.xyz, r));
	if (v < 0.0f || (u + v) > 1.0f)
	{
		//miss
		return -1;
	}
	l_t = f * (dot(e2.xyz, r));
	if ((l_t < _dist && l_t > distanceDelta) || (_dist < 0.0f && l_t > distanceDelta))
	{
		float2 index = ((1 - u - v) * p_tri.tex0) + (u * p_tri.tex1) + (v * p_tri.tex2);
			return float3(l_t, index);
	}
	
	return float3(-1,0,0);
}


// Implements support for dist later
int RayVSAABB(Ray _ray, NodeAABB _aabb)
{
	float maxT[NUMDIM];
	int inside = 1;
	int quadrant[NUMDIM];
	float candidatePlane[NUMDIM];

	// Find candidate planes
	for (int i = 0; i < NUMDIM; i++)
	{
		quadrant[i] = MIDDLE;
		if (_ray.origin[i] < _aabb.minPoint[i])
		{
			quadrant[i] = LEFT;
			candidatePlane[i] = _aabb.minPoint[i];
			inside = 0;
		}
		else if (_ray.origin[i] > _aabb.maxPoint[i])
		{
			quadrant[i] = RIGHT;
			candidatePlane[i] = _aabb.maxPoint[i];
			inside = 0;
		}
	}

	// if origin inside AABB
	if (inside == 1)
	{
		return 0;
	}

	// check to see if the ray intersects the AABB

	// calculate t distance to candidate planes
	for (int i = 0; i < NUMDIM; i++)
	{
		maxT[i] = -1;
		if (quadrant[i] != MIDDLE && _ray.dir[i] != 0)
		{
			maxT[i] = (candidatePlane[i] - _ray.origin[i]) / _ray.dir[i];
		}
	}

	// get the largest of the maxT
	int whichPlane = 0;
	whichPlane = maxT[whichPlane] < maxT[1] ? 1 : whichPlane;
	whichPlane = maxT[whichPlane] < maxT[2] ? 2 : whichPlane;

	// Check if the final candidate is inside the box
	if (maxT[whichPlane] < 0)
	{
		return MAXDIST;
	}
	for (int i = 0; i < NUMDIM; i++)
	{
		if (whichPlane != i && (_ray.origin[i] + (maxT[whichPlane] * _ray.dir[i])) < _aabb.minPoint[i] ||
			whichPlane != i && (_ray.origin[i] + (maxT[whichPlane] * _ray.dir[i])) > _aabb.maxPoint[i])
		{
			return MAXDIST;
		}
	}
	return maxT[whichPlane];
}