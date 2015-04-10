#include "Collisions.fx"



//StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);

RWStructuredBuffer<NodePass2> KDtree : register(u1); // to do skapa den fulla strukturen

RWStructuredBuffer<int> indiceList : register(u2); // to do skapa append list 


RWStructuredBuffer<int4> splittingSwap[2] : register(u3); // the int2 holds x = the left split index, y = the left aabb index, z = the right split index, w = right the aabb index  

RWStructuredBuffer<int2> splittSize : register(u5); // used for storing the size of every split and then the start values of the split 0 = size of previus split, 1 = offset in current split



//void moveData(int moveSplit, int offset,int workingSplit,int workID)
//{
//	splittingSwap[moveSplit][offset] = splittingSwap[workingSplit][workID];
//
//}


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


	// Creating kd-tree

	int lowIndex = 0;						// the current treads low work index
	int hightIndex = nrOfTriangles - 1;		// the current treads end work index

	//float split;							// the value to use as the split value

	workID = threadIndex;						// setting the workID for the first pass





	while (depth < 3)
	{
		
		//////////////////////////////////////////////////////////////////////
		//	SPLIT SELECTION		--	calculation not neded right now
		//////////////////////////////////////////////////////////////////////


		//////////////////////////////////////////////////////////////////////
		//	Beräkna splitsen för arbets listan
		//////////////////////////////////////////////////////////////////////
		int splitStart = pow(2,depth); // the start index for the kdtree at the current depth
		int nextSplitAmount = splitStart * 2; // the amount of splits for the next lvl

		while (workID < hightIndex)
		{
			int	oldSplitID = splittingSwap[workingSplit][workID][0];

			int	aabbSplitID = splittingSwap[workingSplit][workID][1];

			splittingSwap[workingSplit][workID][0] = -1;
			splittingSwap[workingSplit][workID][1] = -1;
			splittingSwap[workingSplit][workID][2] = -1;
			splittingSwap[workingSplit][workID][3] = -1;


			if (aabbList[aabbSplitID].maxPoint[KDtree[splitStart + oldSplitID].split.x] <= KDtree[splitStart + oldSplitID].split.y)
			{
				splittingSwap[workingSplit][workID][0] = oldSplitID;
				splittingSwap[workingSplit][workID][1] = aabbSplitID;

				InterlockedAdd(splittSize[oldSplitID + 1][0], 1);

			}
			else if (aabbList[aabbSplitID].minPoint[KDtree[splitStart + oldSplitID].split.x] >= KDtree[splitStart + oldSplitID].split.y)
			{
				splittingSwap[workingSplit][workID][2] = oldSplitID + 1;
				splittingSwap[workingSplit][workID][3] = aabbSplitID;

				InterlockedAdd(splittSize[oldSplitID + 2][0], 1);

			}
			//if (splittingSwap[workingSplit][workID][0] == -1 && splittingSwap[workingSplit][workID][2] == -1)
			else
			{
				splittingSwap[workingSplit][workID][0] = oldSplitID;
				splittingSwap[workingSplit][workID][1] = aabbSplitID;

				InterlockedAdd(splittSize[oldSplitID + 1][0], 1);



				splittingSwap[workingSplit][workID][2] = oldSplitID+1;
				splittingSwap[workingSplit][workID][3] = aabbSplitID;
				
				InterlockedAdd(splittSize[oldSplitID + 2][0], 1);

			}

			workID += NROFTHREADSCREATIONDISPATCHES;
		}

		//////////////////////////////////////////////////////////////////////
		//	Beräkna start index för varje split
		//////////////////////////////////////////////////////////////////////


		DeviceMemoryBarrierWithGroupSync();

		int sum = 0;
		workID = 1;
		if (threadIndex == 0)
		{
			while (splittSize[workID][0] != 0)
			{
				sum += splittSize[workID][0];
				//splittSize[workID][1] = splittSize[workID][0];
				splittSize[workID][0] = sum;
				workID++;
			}
		}

		DeviceMemoryBarrierWithGroupSync();




		//////////////////////////////////////////////////////////////////////
		//	Flytta splitten
		//////////////////////////////////////////////////////////////////////

		workID = threadIndex;

		// splittingSwap[2] // swapping structure to move and create the list of indices // the int4 holds x = the left split index, y = the left aabb index, z = the right split index, w = right the aabb index  
		// splitStart // the amount of splits for the current depth
		// moveSplit // the split to move the list to
		// workingSplit // the split that the elements are to be split from
		// splittSize // contains the start intex to wright to for the splits and how many has been written


		//if (workID < nextSplitAmount)
		//{

		//	int counter = 0;

		//	while (splittingSwap[workingSplit][counter][0] != -1 || splittingSwap[workingSplit][counter][2] != -1)
		//	{
		//		int leftRight = workID % 2;
		//
		//		if (splittingSwap[workingSplit][counter][leftRight * 2] == workID)
		//		{
		//			//int splitOffset = splittSize[workID][0]; // the offset to the start of the split the value belongs in
		//			//int moveID = splittSize[workID][1]; // the id offset to move the data to

		//			splittingSwap[moveSplit][splittSize[workID][1]][0] = splittingSwap[workingSplit][counter][leftRight * 2];
		//			splittingSwap[moveSplit][splittSize[workID][1]][1] = splittingSwap[workingSplit][counter][(leftRight * 2) + 1];
		//			splittingSwap[moveSplit][splittSize[workID][1]][2] = -1;
		//			splittingSwap[moveSplit][splittSize[workID][1]][3] = -1;

		//			InterlockedAdd(splittSize[workID][1],1);
		//		}

		//		counter++;
		//	}

		//	workID += NROFTHREADSCREATIONDISPATCHES;

		//}


		/////////////////////////// OLD

		while (splittingSwap[workingSplit][workID][0] != -1 || splittingSwap[workingSplit][workID][2] != -1)
			{
				int moveID; // the id to move the data to
				int moveToSplit; // the splitID to move the data to 
				//int splitOffset; // the offset to the start of the split the value belongs in

				if (splittingSwap[workingSplit][workID][0] != -1)
				{

					moveToSplit = splittingSwap[workingSplit][workID][0];
					//splitOffset = splittSize[moveToSplit];

					InterlockedAdd(splittSize[moveToSplit][0], 1, moveID);// moveID får orginal värdet av splittSize? sen adderas alla trådarna

					splittingSwap[moveSplit][moveID][0] = splittingSwap[workingSplit][workID][0];
					splittingSwap[moveSplit][moveID][1] = splittingSwap[workingSplit][workID][1];
					splittingSwap[moveSplit][moveID][2] = -1;
					splittingSwap[moveSplit][moveID][3] = -1;
				}
				if (splittingSwap[workingSplit][workID][2] != -1)
				{
					moveToSplit = splittingSwap[workingSplit][workID][2];
					//splitOffset = splittSize[moveToSplit];

					InterlockedAdd(splittSize[moveToSplit][0], 1, moveID); // moveID får orginal värdet av splittSize? sen adderas alla trådarna

					splittingSwap[moveSplit][moveID][0] = splittingSwap[workingSplit][workID][2];
					splittingSwap[moveSplit][moveID][1] = splittingSwap[workingSplit][workID][3];
					splittingSwap[moveSplit][moveID][2] = -1;
					splittingSwap[moveSplit][moveID][3] = -1;
				}


				workID += NROFTHREADSCREATIONDISPATCHES;
			}

		/////////////////////////// END OLD


		//////////////////////////////////////////////////////////////////////
		//	Gör redo för nästa split level
		//////////////////////////////////////////////////////////////////////

		DeviceMemoryBarrierWithGroupSync();


			// Splitta boxarna i kd-trädet -- done?
			// Flytta vilken split som är working och move - done
			// cleara move splitten om splitsen är bytta - tror inte denna behövs
			// clear splitSize - done
		
			workID = threadIndex;

			while (workID < splitStart)
			{
				// splitStart  // the number of nodes in the current depth

				int startIndexThisDepth = splitStart - 1;
				int nextDepth = splitStart * 2;
				int startIndexNextDepth = nextDepth - 1;

				if (splittSize[workID][0] > 5) // splitta boxen och skriv till nästa djup
				{

					// 0 = current depth = splitstart + workID
					// 1 = left child = splitstart + (workID * 2)
					// 2 = right child = splitstart + ((workID * 2) + 1)

					// chose the best split axis
					int splitAxis; // 0 = x, 1 = y, 2 = z
					float splitLength[3];
					splitLength[0] = KDtree[startIndexThisDepth + workID].aabb.maxPoint.x - KDtree[startIndexThisDepth + workID].aabb.minPoint.x;
					splitLength[1] = KDtree[startIndexThisDepth + workID].aabb.maxPoint.y - KDtree[startIndexThisDepth + workID].aabb.minPoint.y;
					splitLength[2] = KDtree[startIndexThisDepth + workID].aabb.maxPoint.z - KDtree[startIndexThisDepth + workID].aabb.minPoint.z;

					splitAxis = splitLength[0] > splitLength[1] ? 0 : 1;
					splitAxis = splitLength[splitAxis]	 > splitLength[2] ? splitAxis : 2;

					//float middleOffset = (KDtree[startIndexThisDepth + (workID * 2)].aabb.maxPoint[splitAxis] - KDtree[startIndexThisDepth + (workID * 2)].aabb.minPoint[splitAxis]) * 0.5f;
					
					float middleOffset = KDtree[startIndexThisDepth + workID].aabb.maxPoint[splitAxis];
					middleOffset -= KDtree[startIndexThisDepth + workID].aabb.minPoint[splitAxis];
					middleOffset *= 0.5f;

					// left
					KDtree[startIndexNextDepth + (workID * 2)] = KDtree[startIndexThisDepth + workID];

					KDtree[startIndexNextDepth + (workID * 2)].aabb.maxPoint[splitAxis] -= middleOffset;

					// right
					KDtree[startIndexNextDepth + ((workID * 2) + 1)] = KDtree[startIndexThisDepth + workID];

					KDtree[startIndexNextDepth + ((workID * 2) + 1)].aabb.minPoint[splitAxis] += middleOffset;

				}
				else // leafNode
				{

				}

				workID += NROFTHREADSCREATIONDISPATCHES;

			}

			workID = threadIndex;

			DeviceMemoryBarrierWithGroupSync();

		
			while (workID < 3000000)
			{
				splittSize[workID][0] = 0;
				splittSize[workID][1] = 0;

				workID += NROFTHREADSCREATIONDISPATCHES;

			}
			

			int temp = workingSplit;
			workingSplit = moveSplit;
			moveSplit = temp;

			depth++;
		//break;
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
