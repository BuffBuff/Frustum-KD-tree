#include "Collisions.fx"



StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);

RWStructuredBuffer<NodePass2> KDtree : register(u1); // to do skapa den fulla strukturen

RWStructuredBuffer<int> indiceList : register(u2); // to do skapa append list 


RWStructuredBuffer<int4> splittingSwap[2] : register(u3); // the int2 holds x = the left split index, y = the left aabb index, z = the right split index, w = right the aabb index  

RWStructuredBuffer<int2> splittSize : register(u5); // used for storing the size of every split and then the start values of the split



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



	while (workID < 3000000)
	{
		splittingSwap[0][workID][0] = -1;
		splittingSwap[0][workID][1] = -1;
		splittingSwap[0][workID][2] = -1;
		splittingSwap[0][workID][3] = -1;

		splittingSwap[1][workID][0] = -1;
		splittingSwap[1][workID][1] = -1;
		splittingSwap[1][workID][2] = -1;
		splittingSwap[1][workID][3] = -1;

		splittSize[workID][0] = 0;
		splittSize[workID][1] = 0;

		indiceList[workID] = -1;


		workID += NROFTHREADSCREATIONDISPATCHES;

	}

	workID = threadIndex;
	DeviceMemoryBarrierWithGroupSync();


	// Creating the aabbs for the triangles
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

		splittingSwap[workingSplit][workID][0] = 0;
		splittingSwap[workingSplit][workID][1] = workID;
		splittingSwap[workingSplit][workID][2] = -1;
		splittingSwap[workingSplit][workID][3] = 0;

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
		[unroll]for (int i = 0; i < 3; i++)
		{
			KDtree[0].aabb.minPoint[i] = KDtree[0].aabb.minPoint[i] < KDtree[1].aabb.minPoint[i] ? KDtree[0].aabb.minPoint[i] : KDtree[1].aabb.minPoint[i];
			KDtree[0].aabb.maxPoint[i] = KDtree[0].aabb.maxPoint[i] > KDtree[1].aabb.maxPoint[i] ? KDtree[0].aabb.maxPoint[i] : KDtree[1].aabb.maxPoint[i];
		}


		// left
		KDtree[1].aabb.minPoint = KDtree[0].aabb.minPoint;
		KDtree[1].aabb.maxPoint = KDtree[0].aabb.maxPoint;

		KDtree[1].aabb.maxPoint.x -= (KDtree[1].aabb.maxPoint.x - KDtree[1].aabb.minPoint.x) * 0.5f;

		// right
		KDtree[2].aabb.minPoint = KDtree[0].aabb.minPoint;
		KDtree[2].aabb.maxPoint = KDtree[0].aabb.maxPoint;

		KDtree[2].aabb.minPoint.x += (KDtree[2].aabb.maxPoint.x - KDtree[2].aabb.minPoint.x) * 0.5f;

		KDtree[0].split.x = 0;
		KDtree[0].split.y = KDtree[2].aabb.minPoint.x;

		KDtree[0].index = -1;

	}

}