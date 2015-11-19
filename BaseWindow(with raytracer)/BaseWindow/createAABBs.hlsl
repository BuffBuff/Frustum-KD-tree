#include "Collisions.fx"

StructuredBuffer<TriangleMat> triangles :register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);

RWStructuredBuffer<NodePass2> KDtree : register(u1);

//AppendStructuredBuffer<int> indiceList : register(u2);

ConsumeStructuredBuffer<int4> splittingSwapConsume : register(u3);// the int4 holds x = the left split index, y = the left aabb index, z = the right split index, w = right the aabb index  
AppendStructuredBuffer<int4> splittingSwapAppend : register(u4);


RWStructuredBuffer<int2> splittSize : register(u5); // used for storing the size of every split and then the start values of the split 0 = size of previus split, 1 = offset in current split

RWStructuredBuffer<int> indexingCount : register(u6); // using this struct to designate which index in the indiceList to wright the leaf node to, index 1 is the depth value of the current depth

RWStructuredBuffer<float> mutex : register(u7);	// Used in the custom interlocking function

[numthreads(CORETHREADSWIDTH, CORETHREADSHEIGHT, 1)]
void main(uint3 threadID : SV_DispatchThreadID)
{
	// index of the thread in 1D buffers
	int threadIndex = threadID.x + threadID.y * CREATIONHEIGHT;	// the treads index
	int workID = threadIndex;								// the triangle/AABB that the tread currently handles
	int workingSplit = 0;							// the splitSwap currently woking on 0 - 1
	int moveSplit = 1;								// the splitSwap to move to
	//----------------------------------------------------------------------

	AABB aabbMemReadTest;

	aabbMemReadTest.minPoint.w = 0;
	aabbMemReadTest.minPoint.w = 0;
	aabbMemReadTest.maxPoint.w = 0;
	aabbMemReadTest.maxPoint.w = 0;

	TriangleMat triangleInWork;

	indexingCount[0] = 0;
	indexingCount[1] = 0;
	indexingCount[2] = nrOfTriangles;
	indexingCount[3] = 0;
	indexingCount[4] = 1;




	while (workID < MAXSIZE)
	{

		splittSize[workID][0] = 0;
		splittSize[workID][1] = 0;

		workID += NROFTHREADSCREATIONDISPATCHES;

	}

	workID = threadIndex;
	DeviceMemoryBarrierWithGroupSync();


	//// Creating the aabbs for the triangles
	while (workID < nrOfTriangles)
	{
		triangleInWork = triangles[workID];

		aabbMemReadTest.triangleID = workID;

		aabbMemReadTest.minPoint.x = triangleInWork.pos0.x < triangleInWork.pos1.x ? triangleInWork.pos0.x : triangleInWork.pos1.x;
		aabbMemReadTest.minPoint.x = aabbMemReadTest.minPoint.x < triangleInWork.pos2.x ? aabbMemReadTest.minPoint.x : triangleInWork.pos2.x;

		aabbMemReadTest.minPoint.y = triangleInWork.pos0.y < triangleInWork.pos1.y ? triangleInWork.pos0.y : triangleInWork.pos1.y;
		aabbMemReadTest.minPoint.y = aabbMemReadTest.minPoint.y < triangleInWork.pos2.y ? aabbMemReadTest.minPoint.y : triangleInWork.pos2.y;

		aabbMemReadTest.minPoint.z = triangleInWork.pos0.z < triangleInWork.pos1.z ? triangleInWork.pos0.z : triangleInWork.pos1.z;
		aabbMemReadTest.minPoint.z = aabbMemReadTest.minPoint.z < triangleInWork.pos2.z ? aabbMemReadTest.minPoint.z : triangleInWork.pos2.z;

		aabbMemReadTest.maxPoint.x = triangleInWork.pos0.x > triangleInWork.pos1.x ? triangleInWork.pos0.x : triangleInWork.pos1.x;
		aabbMemReadTest.maxPoint.x = aabbMemReadTest.maxPoint.x > triangleInWork.pos2.x ? aabbMemReadTest.maxPoint.x : triangleInWork.pos2.x;

		aabbMemReadTest.maxPoint.y = triangleInWork.pos0.y > triangleInWork.pos1.y ? triangleInWork.pos0.y : triangleInWork.pos1.y;
		aabbMemReadTest.maxPoint.y = aabbMemReadTest.maxPoint.y > triangleInWork.pos2.y ? aabbMemReadTest.maxPoint.y : triangleInWork.pos2.y;

		aabbMemReadTest.maxPoint.z = triangleInWork.pos0.z > triangleInWork.pos1.z ? triangleInWork.pos0.z : triangleInWork.pos1.z;
		aabbMemReadTest.maxPoint.z = aabbMemReadTest.maxPoint.z > triangleInWork.pos2.z ? aabbMemReadTest.maxPoint.z : triangleInWork.pos2.z;

		aabbList[workID] = aabbMemReadTest;

		int4 appendValues;
		appendValues[0] = 0;
		appendValues[1] = workID;
		appendValues[2] = -1;
		appendValues[3] = -1;

		splittingSwapAppend.Append(appendValues);
		splittSize[0].x = nrOfTriangles;

		workID += NROFTHREADSCREATIONDISPATCHES;

	}

	DeviceMemoryBarrierWithGroupSync();

	///////////////////////////////////////////////////////////
	//	CALCULATE AABB FOR ROOT NODE  -- detta �r just nu en bottle neck som vi beh�ver optimera senare
	///////////////////////////////////////////////////////////




	if (threadIndex < 6)
	{
		float minValue = MAXDIST;
		float maxValue = -MAXDIST;
		int listPart = threadIndex % 2;
		int splitPart = threadIndex % 3;
		for (int i = nrOfTriangles*(listPart * 0.5); i < nrOfTriangles *(0.5 * (listPart + 1)); i++)
		{
			minValue = aabbList[i].minPoint[splitPart] < minValue ? aabbList[i].minPoint[splitPart] : minValue;
			maxValue = aabbList[i].maxPoint[splitPart] > maxValue ? aabbList[i].maxPoint[splitPart] : maxValue;
		}

		KDtree[listPart].aabb.minPoint[splitPart] = minValue;
		KDtree[listPart].aabb.maxPoint[splitPart] = maxValue;

	}

	if (threadIndex == 0)
	{
		for (int i = 0; i < 3; i++)
		{
			KDtree[0].aabb.minPoint[i] = KDtree[0].aabb.minPoint[i] < KDtree[1].aabb.minPoint[i] ? KDtree[0].aabb.minPoint[i] : KDtree[1].aabb.minPoint[i];
			KDtree[0].aabb.maxPoint[i] = KDtree[0].aabb.maxPoint[i] > KDtree[1].aabb.maxPoint[i] ? KDtree[0].aabb.maxPoint[i] : KDtree[1].aabb.maxPoint[i];
		}
		KDtree[0].index = -1;

		int splitAxis; // 0 = x, 1 = y, 2 = z
		float splitLength[3];
		splitLength[0] = KDtree[0].aabb.maxPoint.x - KDtree[0].aabb.minPoint.x;
		splitLength[1] = KDtree[0].aabb.maxPoint.y - KDtree[0].aabb.minPoint.y;
		splitLength[2] = KDtree[0].aabb.maxPoint.z - KDtree[0].aabb.minPoint.z;

		splitAxis = splitLength[0] > splitLength[1] ? 0 : 1;
		splitAxis = splitLength[splitAxis]	 > splitLength[2] ? splitAxis : 2;

		

		// left
		KDtree[1] = KDtree[0];

		KDtree[1].aabb.maxPoint[splitAxis] -= (KDtree[1].aabb.maxPoint[splitAxis] - KDtree[1].aabb.minPoint[splitAxis]) * 0.5f;

		// right
		KDtree[2] = KDtree[0];

		KDtree[2].aabb.minPoint[splitAxis] += (KDtree[2].aabb.maxPoint[splitAxis] - KDtree[2].aabb.minPoint[splitAxis]) * 0.5f;

		KDtree[0].split.x = splitAxis;
		KDtree[0].split.y = KDtree[2].aabb.minPoint.z;

	}

}