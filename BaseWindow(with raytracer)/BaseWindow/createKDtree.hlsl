#include "Collisions.fx"



StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);

RWStructuredBuffer<NodePass2> KDtree : register(u1); // to do skapa den fulla strukturen

RWStructuredBuffer<int> indiceList : register(u2); // to do skapa append list 


RWStructuredBuffer<int2> splittingSwap[2] : register(u3);



[numthreads(CORETHREADSWIDTH, CORETHREADSHEIGHT, 1)]
void main(uint3 threadID : SV_DispatchThreadID)
{
	// index of the thread in 1D buffers
	int index = threadID.x + threadID.y * HEIGHT;	// the treads index
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

		splittingSwap[workingSplit][workID][0] = workID;
		splittingSwap[workingSplit][workID][1] = -1;

		workID += NROFTREADSKDTREECREATION;
		
	}


	//----------------------------------------------------------------------
	// Creating kd-tree

	int lowIndex = 0;						// the current treads low work index
	int hightIndex = nrOfTriangles - 1;		// the current treads end work index

	int splitAxis = 0;						// the axis the slit is made in 0 = x, 1 = y, 2 = z

	int depth = 0;							// the current depth of the tree;
	float split;							// the value to use as the split value

	workID = lowIndex;						// setting the workID for the first pass

	while (true)
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
		index = aabbList[splittingSwap[workingSplit][splittCandidates[0]][0]].maxPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[1]][0]].maxPoint[splitAxis] ? 0 : 1;
		index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][0]].maxPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[2]][0]].maxPoint[splitAxis] ? index : 2;
		index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][0]].maxPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[3]][0]].maxPoint[splitAxis] ? index : 3;
		index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][0]].maxPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[4]][0]].maxPoint[splitAxis] ? index : 4;

		int temp = splittCandidates[4];
		splittCandidates[4] = splittCandidates[index];
		splittCandidates[index] = temp;

		// Find the smallest point and sort it out
		index = aabbList[splittingSwap[workingSplit][splittCandidates[0]][0]].minPoint[splitAxis] < aabbList[splittingSwap[workingSplit][splittCandidates[1]][0]].minPoint[splitAxis] ? 0 : 1;
		index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][0]].minPoint[splitAxis] < aabbList[splittingSwap[workingSplit][splittCandidates[2]][0]].minPoint[splitAxis] ? index : 2;
		index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][0]].minPoint[splitAxis] < aabbList[splittingSwap[workingSplit][splittCandidates[3]][0]].minPoint[splitAxis] ? index : 3;

		temp = splittCandidates[0];
		splittCandidates[0] = splittCandidates[index];
		splittCandidates[index] = temp;

		// Find the second largest point
		index = aabbList[splittingSwap[workingSplit][splittCandidates[1]][0]].minPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[2]][0]].minPoint[splitAxis] ? 1 : 2;
		index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][0]].minPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[3]][0]].minPoint[splitAxis] ? index : 3;

		temp = splittCandidates[3];
		splittCandidates[3] = splittCandidates[index];
		splittCandidates[index] = temp;

		// Find the second smallest point
		index = aabbList[splittingSwap[workingSplit][splittCandidates[1]][0]].minPoint[splitAxis] < aabbList[splittingSwap[workingSplit][splittCandidates[2]][0]].minPoint[splitAxis] ? 1 : 2;

		temp = splittCandidates[2];
		splittCandidates[2] = splittCandidates[index];
		splittCandidates[index] = temp;

		// Deside which side of the box is the best splitt plane

		float comparison = aabbList[splittingSwap[workingSplit][splittCandidates[2]][0]].minPoint[splitAxis] + aabbList[splittingSwap[workingSplit][splittCandidates[2]][0]].maxPoint[splitAxis];
		comparison *= 0.5f;

		split = abs(aabbList[splittingSwap[workingSplit][splittCandidates[2]][0]].minPoint[splitAxis] - comparison) < abs(aabbList[splittingSwap[workingSplit][splittCandidates[2]][0]].maxPoint[splitAxis] - comparison) ? aabbList[splittingSwap[workingSplit][splittCandidates[2]][0]].minPoint[splitAxis] : aabbList[splittingSwap[workingSplit][splittCandidates[2]][0]].maxPoint[splitAxis];

		//////////////////////////////////////////////////////////////////////
		//  DONE SELECTION SPLIT
		//////////////////////////////////////////////////////////////////////

		//////////////////////////////////////////////////////////////////////
		//	Beräkna splitsen för arbets listan
		//////////////////////////////////////////////////////////////////////
		while (workID < hightIndex)
		{
			int	aabbSplitID = splittingSwap[workingSplit][workID][0];

			splittingSwap[workingSplit][workID][0] = aabbList[aabbSplitID].maxPoint[splitAxis] <= split ? aabbSplitID : -1;
			splittingSwap[workingSplit][workID][1] = aabbList[aabbSplitID].minPoint[splitAxis] >= split ? aabbSplitID : -1;
			
			if (splittingSwap[workingSplit][workID][0] == -1 && splittingSwap[workingSplit][workID][1] == -1)
			{
				splittingSwap[workingSplit][workID][0] = aabbSplitID;
				splittingSwap[workingSplit][workID][1] = aabbSplitID;
			}
			workID += NROFTREADSKDTREECREATION;
		}

		//////////////////////////////////////////////////////////////////////
		//	Flytta splitten
		//////////////////////////////////////////////////////////////////////


		break;
	}

}