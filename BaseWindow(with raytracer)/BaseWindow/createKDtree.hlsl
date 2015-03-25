#include "Collisions.fx"



StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);

RWStructuredBuffer<NodePass2> KDtree : register(u1); // to do skapa den fulla strukturen

RWStructuredBuffer<int> indiceList : register(u2); // to do skapa append list 


RWStructuredBuffer<int4> splittingSwap[2] : register(u3); // the int2 holds x = the left split index, y = the left aabb index, z = the right split index, w = right the aabb index  

RWStructuredBuffer<int> splittSize : register(u5); // used for storing the size of every split and then the start values of the split

[numthreads(CORETHREADSWIDTH, CORETHREADSHEIGHT, 1)]
void main(uint3 threadID : SV_DispatchThreadID)
{
	// index of the thread in 1D buffers
	int threadIndex = threadID.x + threadID.y * CREATIONHEIGHT;	// the treads index
	int workID = threadIndex;								// the triangle/AABB that the tread currently handles
	int workingSplit = 0;							// the splitSwap currently woking on 0 - 1
	int moveSplit = 1;								// the splitSwap to move to
	int nrOfSplits = 2;
	int depth = 0;							// the current depth of the tree;
	int nrOfElements = nrOfTriangles;

	splittSize[threadIndex] = 0;

	// Creating kd-tree

	int lowIndex = 0;						// the current treads low work index
	int hightIndex = nrOfTriangles - 1;		// the current treads end work index

	//float split;							// the value to use as the split value

	workID = threadIndex;						// setting the workID for the first pass


	///////////////////////////////////////////////////////////
	//	CALCULATE AABB FOR ROOT NODE  -- detta är just nu en bottle neck som vi behöver optimera senare
	///////////////////////////////////////////////////////////

	if (threadIndex < 6)
	{
		float minValue = MAXDIST;
		float maxValue = -MAXDIST;
		int listPart = threadIndex % 2;
		int splitPart = threadIndex % 3;
		for (int i = nrOfTriangles*(listPart * 0.5); i < nrOfTriangles *( 0.5 * (listPart + 1)); i++)
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
			KDtree[0].aabb.maxPoint[i] = KDtree[0].aabb.maxPoint[i] > KDtree[1].aabb.maxPoint[i] ? KDtree[0].aabb.minPoint[i] : KDtree[1].aabb.minPoint[i];
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

	}

	while (true)
	{
		
		//////////////////////////////////////////////////////////////////////
		//	SPLIT SELECTION		--	calculation not neded right now
		//////////////////////////////////////////////////////////////////////


		//////////////////////////////////////////////////////////////////////
		//	Beräkna splitsen för arbets listan
		//////////////////////////////////////////////////////////////////////
		int splitStart = pow(2,depth); // the start index for the kdtree

		while (workID < hightIndex)
		{
			int	oldSplitID = splittingSwap[workingSplit][workID][0];

			int	aabbSplitID = splittingSwap[workingSplit][workID][1];

			splittingSwap[workingSplit][workID][0] = -1;
			splittingSwap[workingSplit][workID][2] = -1;


			if (aabbList[aabbSplitID].maxPoint[KDtree[splitStart + oldSplitID].split.x] <= KDtree[splitStart + oldSplitID].split.y)
			{
				splittingSwap[workingSplit][workID][0] = oldSplitID;
				splittingSwap[workingSplit][workID][1] = aabbSplitID;
				//splittSize[oldSplitID + 1] += 1;
				InterlockedAdd(splittSize[oldSplitID + 1], 1);
			}
			else if (aabbList[aabbSplitID].minPoint[KDtree[splitStart + oldSplitID].split.x] >= KDtree[splitStart + oldSplitID].split.y)
			{
				splittingSwap[workingSplit][workID][2] = oldSplitID + 1;
				splittingSwap[workingSplit][workID][3] = aabbSplitID;
				//splittSize[oldSplitID + 2] += 1;
				InterlockedAdd(splittSize[oldSplitID + 2], 1);


			}
			//if (splittingSwap[workingSplit][workID][0] == -1 && splittingSwap[workingSplit][workID][2] == -1)
			else
			{
				splittingSwap[workingSplit][workID][0] = oldSplitID;
				splittingSwap[workingSplit][workID][1] = aabbSplitID;
				//splittSize[oldSplitID + 1] += 1;
				InterlockedAdd(splittSize[oldSplitID + 1], 1);



				splittingSwap[workingSplit][workID][2] = oldSplitID+1;
				splittingSwap[workingSplit][workID][3] = aabbSplitID;
				//splittSize[oldSplitID + 2] += 1;
				InterlockedAdd(splittSize[oldSplitID + 2], 1);


			}
			workID += NROFTHREADSCREATIONDISPATCHES;
		}

		//////////////////////////////////////////////////////////////////////
		//	Flytta splitten
		//////////////////////////////////////////////////////////////////////

		workID = threadIndex;

		int forEnd = pow(2, depth); // the amount of splits for the current depth


		while (workID < forEnd) // Vilken split som ska flyttas = ränka elementen
		{
		//	int j = 0;
		//	//int indexSplitCount = 0; // conts the amount of AABBs that the thread ID ecuals

		//	int leftRightSwapCount = (workID % 2) * 2; // om Index värdet ligger på en höger eller vänster gren

		//	splittSize[workID + 1] = 0;

		//	while (j < nrOfElements) // ränka antalet element tillhörande splitten med workID som index
		//	{
		//		if (splittingSwap[workingSplit][j][leftRightSwapCount] == workID)
		//		{
		//			splittSize[workID + 1] += 1;

		//			//indexSplitCount++;
		//		}
		//		j++;
		//	}

		//	//splittSize[workID + 1] = indexSplitCount;

		//	workID += NROFTREADSKDTREECREATION;
		}
		

		break;
	}

}










///////////////////////////////////////////////////////
//	OLD SPLIT SELECTION
///////////////////////////////////////////////////////

//int splittCandidates[5];
//splittCandidates[0] = lowIndex;
//splittCandidates[1] = lowIndex + (hightIndex - lowIndex) * 0.25f;
//splittCandidates[2] = lowIndex + (hightIndex - lowIndex) * 0.5f;
//splittCandidates[3] = lowIndex + (hightIndex - lowIndex) * 0.75f;
//splittCandidates[4] = hightIndex;
//
//float minPoint;
//float maxPoint;
//
//int index;
//
//// Find the largest point and sort it out
//index = aabbList[splittingSwap[workingSplit][splittCandidates[0]][1]].maxPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[1]][1]].maxPoint[splitAxis] ? 0 : 1;
//index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][1]].maxPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[2]][1]].maxPoint[splitAxis] ? index : 2;
//index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][1]].maxPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[3]][1]].maxPoint[splitAxis] ? index : 3;
//index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][1]].maxPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[4]][1]].maxPoint[splitAxis] ? index : 4;
//
//int temp = splittCandidates[4];
//splittCandidates[4] = splittCandidates[index];
//splittCandidates[index] = temp;
//
//// Find the smallest point and sort it out
//index = aabbList[splittingSwap[workingSplit][splittCandidates[0]][1]].minPoint[splitAxis] < aabbList[splittingSwap[workingSplit][splittCandidates[1]][1]].minPoint[splitAxis] ? 0 : 1;
//index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][1]].minPoint[splitAxis] < aabbList[splittingSwap[workingSplit][splittCandidates[2]][1]].minPoint[splitAxis] ? index : 2;
//index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][1]].minPoint[splitAxis] < aabbList[splittingSwap[workingSplit][splittCandidates[3]][1]].minPoint[splitAxis] ? index : 3;
//
//temp = splittCandidates[0];
//splittCandidates[0] = splittCandidates[index];
//splittCandidates[index] = temp;
//
//// Find the second largest point
//index = aabbList[splittingSwap[workingSplit][splittCandidates[1]][1]].minPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[2]][1]].minPoint[splitAxis] ? 1 : 2;
//index = aabbList[splittingSwap[workingSplit][splittCandidates[index]][1]].minPoint[splitAxis] > aabbList[splittingSwap[workingSplit][splittCandidates[3]][1]].minPoint[splitAxis] ? index : 3;
//
//temp = splittCandidates[3];
//splittCandidates[3] = splittCandidates[index];
//splittCandidates[index] = temp;
//
//// Find the second smallest point
//index = aabbList[splittingSwap[workingSplit][splittCandidates[1]][1]].minPoint[splitAxis] < aabbList[splittingSwap[workingSplit][splittCandidates[2]][1]].minPoint[splitAxis] ? 1 : 2;
//
//temp = splittCandidates[2];
//splittCandidates[2] = splittCandidates[index];
//splittCandidates[index] = temp;
//
//// Deside which side of the box is the best splitt plane
//
//float comparison = aabbList[splittingSwap[workingSplit][splittCandidates[2]][1]].minPoint[splitAxis] + aabbList[splittingSwap[workingSplit][splittCandidates[2]][1]].maxPoint[splitAxis];
//comparison *= 0.5f;
//
//split = abs(aabbList[splittingSwap[workingSplit][splittCandidates[2]][1]].minPoint[splitAxis] - comparison) < abs(aabbList[splittingSwap[workingSplit][splittCandidates[2]][1]].maxPoint[splitAxis] - comparison) ? aabbList[splittingSwap[workingSplit][splittCandidates[2]][1]].minPoint[splitAxis] : aabbList[splittingSwap[workingSplit][splittCandidates[2]][1]].maxPoint[splitAxis];
