#include "Collisions.fx"



StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);

RWStructuredBuffer<NodePass2> KDtree : register(u1); // to do skapa den fulla strukturen

RWStructuredBuffer<int> indiceList : register(u2); // to do skapa append list 


RWStructuredBuffer<int4> splittingSwap[2] : register(u3); // the int2 holds x = the left split index, y = the left aabb index, z = the right split index, w = right the aabb index  




[numthreads(CORETHREADSWIDTH, CORETHREADSHEIGHT, 1)]
void main(uint3 threadID : SV_DispatchThreadID)
{
	// index of the thread in 1D buffers
	int index = threadID.x + threadID.y * CREATIONHEIGHT;	// the treads index
	int workID = index;								// the triangle/AABB that the tread currently handles
	int workingSplit = 0;							// the splitSwap currently woking on 0 - 1
	int moveSplit = 1;								// the splitSwap to move to
	//----------------------------------------------------------------------

	AABB aabbMemReadTest;

	aabbMemReadTest.minPoint.w = 0;
	aabbMemReadTest.minPoint.w = 0;
	aabbMemReadTest.maxPoint.w = 0;
	aabbMemReadTest.maxPoint.w = 0;

	TriangleMat triangleInWork;

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
		splittingSwap[workingSplit][workID][3] = -1;

		workID += NROFTHREADSCREATIONDISPATCHES;

	}

}