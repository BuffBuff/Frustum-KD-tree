#include "Collisions.fx"



StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);


[numthreads(CORETHREADSWIDTH, CORETHREADSHEIGHT, 1)]
void main(uint3 threadID : SV_DispatchThreadID)
{
	// index of the thread in 1D buffers
	int index = threadID.x + threadID.y * HEIGHT;
	int workID = index;


	while (workID < nrOfTriangles)
	{
		aabbList[workID].triangleID = workID;

		aabbList[workID].minPoint.x = triangles[workID].pos0.x < triangles[workID].pos1.x ? triangles[workID].pos0.x : triangles[workID].pos1.x;
		aabbList[workID].minPoint.x = aabbList[workID].minPoint.x < triangles[workID].pos2.x ? aabbList[workID].minPoint.x : triangles[workID].pos2.x;
			
		aabbList[workID].minPoint.y = triangles[workID].pos0.y < triangles[workID].pos1.y ? triangles[workID].pos0.y : triangles[workID].pos1.y;
		aabbList[workID].minPoint.y = aabbList[workID].minPoint.y < triangles[workID].pos2.y ? aabbList[workID].minPoint.y : triangles[workID].pos2.y;
				
		aabbList[workID].minPoint.z = triangles[workID].pos0.z < triangles[workID].pos1.z ? triangles[workID].pos0.z : triangles[workID].pos1.z;
		aabbList[workID].minPoint.z = aabbList[workID].minPoint.z < triangles[workID].pos2.z ? aabbList[workID].minPoint.z : triangles[workID].pos2.z;
				
		aabbList[workID].maxPoint.x = triangles[workID].pos0.x > triangles[workID].pos1.x ? triangles[workID].pos0.x : triangles[workID].pos1.x;
		aabbList[workID].maxPoint.x = aabbList[workID].maxPoint.x > triangles[workID].pos2.x ? aabbList[workID].maxPoint.x : triangles[workID].pos2.x;
				
		aabbList[workID].maxPoint.y = triangles[workID].pos0.y > triangles[workID].pos1.y ? triangles[workID].pos0.y : triangles[workID].pos1.y;
		aabbList[workID].maxPoint.y = aabbList[workID].maxPoint.y > triangles[workID].pos2.y ? aabbList[workID].maxPoint.y : triangles[workID].pos2.y;
				
		aabbList[workID].maxPoint.z = triangles[workID].pos0.z > triangles[workID].pos1.z ? triangles[workID].pos0.z : triangles[workID].pos1.z;
		aabbList[workID].maxPoint.z = aabbList[workID].maxPoint.z > triangles[workID].pos2.z ? aabbList[workID].maxPoint.z : triangles[workID].pos2.z;

		workID += NROFTHREADSWIDTH;
	}
}