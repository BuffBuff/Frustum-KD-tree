#include "Collisions.fx"



StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);



[numthreads(CORETHREADSWIDTH, CORETHREADSHEIGHT, 1)]
void main(uint3 threadID : SV_DispatchThreadID)
{
	// index of the thread in 1D buffers
	int index = threadID.x + threadID.y * HEIGHT;
	int workID = index;


	//----------------------------------------------------------------------
	// Creating the aabbs for the triangles
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


	//----------------------------------------------------------------------
	// Creating kd-tree

	int lowIndex = 0;
	int hightIndex = nrOfTriangles - 1;

	int splitAxis = 0;

	int depth = 0;
	float split;

	while (depth < 7)
	{
		//----------------------------------------------------------------------
		// Chosing splitting plane
		int splittCandidates[5];
		splittCandidates[0] = lowIndex;
		splittCandidates[1] = lowIndex + (hightIndex - lowIndex) * 0.25f;
		splittCandidates[2] = lowIndex + (hightIndex - lowIndex) * 0.5f;
		splittCandidates[3] = lowIndex + (hightIndex - lowIndex) * 0.75f;
		splittCandidates[4] = hightIndex;

		float minPoint;
		float maxPoint;

		int index;

		// Find the largest point and sort it out
		index = aabbList[splittCandidates[0]].maxPoint[splitAxis] > aabbList[splittCandidates[1]].maxPoint[splitAxis] ? 0 : 1;
		index = aabbList[splittCandidates[index]].maxPoint[splittCandidates[index]] > aabbList[splittCandidates[2]].maxPoint[splitAxis] ? index : 2;
		index = aabbList[splittCandidates[index]].maxPoint[splittCandidates[index]] > aabbList[splittCandidates[3]].maxPoint[splitAxis] ? index : 3;
		index = aabbList[splittCandidates[index]].maxPoint[splittCandidates[index]] > aabbList[splittCandidates[4]].maxPoint[splitAxis] ? index : 4;

		int temp = splittCandidates[4];
		splittCandidates[4] = splittCandidates[index];
		splittCandidates[index] = temp;

		// Find the smallest point and sort it out
		index = aabbList[splittCandidates[0]].minPoint[splitAxis] < aabbList[splittCandidates[1]].minPoint[splitAxis] ? 0 : 1;
		index = aabbList[splittCandidates[splittCandidates[index]]].minPoint[splitAxis] < aabbList[splittCandidates[2]].minPoint[splitAxis] ? index : 2;
		index = aabbList[splittCandidates[splittCandidates[index]]].minPoint[splitAxis] < aabbList[splittCandidates[3]].minPoint[splitAxis] ? index : 3;

		temp = splittCandidates[0];
		splittCandidates[0] = splittCandidates[index];
		splittCandidates[index] = temp;

		// Find the second largest point
		index = aabbList[splittCandidates[1]].minPoint[splitAxis] > aabbList[splittCandidates[2]].minPoint[splitAxis] ? 1 : 2;
		index = aabbList[splittCandidates[splittCandidates[index]]].minPoint[splitAxis] > aabbList[splittCandidates[3]].minPoint[splitAxis] ? index : 3;

		temp = splittCandidates[3];
		splittCandidates[3] = splittCandidates[index];
		splittCandidates[index] = temp;

		// Find the second smallest point
		index = aabbList[splittCandidates[1]].minPoint[splitAxis] < aabbList[splittCandidates[2]].minPoint[splitAxis] ? 1 : 2;

		temp = splittCandidates[2];
		splittCandidates[2] = splittCandidates[index];
		splittCandidates[index] = temp;

		// Deside which side of the box is the best splitt plane

		float comparison = aabbList[splittCandidates[2]].minPoint[splitAxis] + aabbList[splittCandidates[2]].maxPoint[splitAxis];
		comparison *= 0.5f;

		split = abs(aabbList[splittCandidates[2]].minPoint[splitAxis] - comparison) < abs(aabbList[splittCandidates[2]].maxPoint[splitAxis] - comparison) ? aabbList[splittCandidates[2]].minPoint[splitAxis] : aabbList[splittCandidates[2]].maxPoint[splitAxis];


		



		depth++;
	}

}