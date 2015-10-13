#include "Collisions.fx"



//StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);

RWStructuredBuffer<NodePass2> KDtree : register(u1);

AppendStructuredBuffer<int2> indiceList : register(u2);

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
	int depth = pad.x;							// the current depth of the tree;


	// Creating kd-tree

	int lowIndex = 0;						// the current treads low work index
	int highIndex = nrOfTriangles;			// the current treads end work index

	while (true)
	{

		int4 workElement = splittingSwapConsume.Consume();
		// if the consume gives null value
		if (workElement.w == 0)
		{
			break;
		}	

		// Finding the index values for the node
		// depth
		int kdTreeOffset = workElement.y - (1 << depth);			// the offset to the kd-node on current lvl
		int aabbIndex = workElement.x;								// the index of the aabb to process
		int childIndex[2];								
		childIndex[0] = (1 << (depth + 1)) + (kdTreeOffset * 2);		// left kd child node index
		childIndex[1] = (1 << (depth + 1)) + (kdTreeOffset * 2) + 1;	// right kd child node index

		if (splittSize[workElement.y].x <= 6 || depth == MAXDEPTH) // om en child node ska skapas
		{

			int2 appendValues;
			appendValues[0] = workElement.y;
			appendValues[1] = aabbIndex;

			indiceList.Append(appendValues);

			KDtree[workElement.y].nrOfTriangles = splittSize[workElement.y].x;

		}
		else
		{
			if (aabbList[aabbIndex].minPoint[KDtree[childIndex[0]].split.x] > KDtree[childIndex[0]].split.y) // left split
			{
				int4 appendValues;
				appendValues[0] = childIndex[0];
				appendValues[1] = aabbIndex;
				appendValues[2] = -1;
				appendValues[3] = -1;

				InterlockedAdd(splittSize[childIndex[0]].x, 1);

				splittingSwapAppend.Append(appendValues);
			}

			if (aabbList[aabbIndex].maxPoint[KDtree[childIndex[1]].split.x] < KDtree[childIndex[1]].split.y) // right split
			{
				int4 appendValues;
				appendValues[0] = childIndex[1];
				appendValues[1] = aabbIndex;
				appendValues[2] = -1;
				appendValues[3] = -1;

				InterlockedAdd(splittSize[childIndex[1]].x, 1);

				splittingSwapAppend.Append(appendValues);
			}

		}
	}


}

//
//while (workID < MAXSIZE)
//{
//	splittSize[workID][0] = 0;
//	splittSize[workID][1] = 0;
//
//	/*		splittingSwap[moveSplit][workID][0] = -1;
//	splittingSwap[moveSplit][workID][1] = -1;*/
//
//	workID += NROFTHREADSCREATIONDISPATCHES;
//
//}
//
//
//DeviceMemoryBarrierWithGroupSync();
//workID = threadIndex;						// setting the workID for the first pass
//
////////////////////////////////////////////////////////////////////////
////	Ber�kna splitsen f�r arbets listan
////////////////////////////////////////////////////////////////////////
//int splitStart = (1 << depth + 1) - 1; // the start index for the kdtree at the current depth
//int nextSplitAmount = (1 << (depth + 1)); // the amount of splits for the next lvl
//
//while (workID < MAXSIZE)
//{
//	//first:	what array to work from
//	//second:	offset in the array
//	//third:	int4(x,y,z,w)
//	//splittingSwap[0/1][0/MAXSIZE][0/3]
//
//	if (splittingSwap[workingSplit][workID][0] != -1)
//	{
//		int	oldSplitID = splittingSwap[workingSplit][workID][0];
//		oldSplitID *= 2;
//
//		int	aabbSplitID = splittingSwap[workingSplit][workID][1];
//
//		//sets the values to -1 to represent empty
//		splittingSwap[workingSplit][workID][0] = -1;
//		splittingSwap[workingSplit][workID][1] = -1;
//		splittingSwap[workingSplit][workID][2] = -1;
//		splittingSwap[workingSplit][workID][3] = -1;
//
//		//checks if the maxpoint for a specific triangleaabb is smaller then current splitvalue
//		//adding to one side of the split
//		//if (aabbList[aabbSplitID].maxPoint[KDtree[splitStart + oldSplitID].split.x] < KDtree[splitStart + oldSplitID].split.y)
//		//{
//		//	splittingSwap[workingSplit][workID][0] = oldSplitID;
//		//	splittingSwap[workingSplit][workID][1] = aabbSplitID;
//
//		//	InterlockedAdd(splittSize[oldSplitID + 1][0], 1);
//
//		//}
//		////checks if the minpoint for a specific triangleaabb is larger then current splitvalue
//		////adding to the other side of the split
//		//else if (aabbList[aabbSplitID].minPoint[KDtree[splitStart + oldSplitID].split.x] > KDtree[splitStart + oldSplitID].split.y)
//		//{
//		//	splittingSwap[workingSplit][workID][2] = oldSplitID + 1;
//		//	splittingSwap[workingSplit][workID][3] = aabbSplitID;
//
//		//	InterlockedAdd(splittSize[oldSplitID + 2][0], 1);
//
//		//}
//		//else //the split is through the triangleaabb
//		//added to both sides of the split
//		//if (splittingSwap[workingSplit][workID][0] == -1 && splittingSwap[workingSplit][workID][2] == -1)
//		{
//			splittingSwap[moveSplit][workID][0] = oldSplitID;
//			splittingSwap[moveSplit][workID][1] = aabbSplitID;
//
//			InterlockedAdd(splittSize[oldSplitID + 1][0], 1);
//
//
//			splittingSwap[moveSplit][workID][2] = oldSplitID + 1;
//			splittingSwap[moveSplit][workID][3] = aabbSplitID;
//
//			InterlockedAdd(splittSize[oldSplitID + 2][0], 1);
//
//		}
//
//
//
//		/*if (aabbList[aabbSplitID].maxPoint[KDtree[splitStart + oldSplitID].split.x] < 60)
//		{
//		splittingSwap[workingSplit][workID][0] = oldSplitID;
//		splittingSwap[workingSplit][workID][1] = aabbSplitID;
//
//		InterlockedAdd(splittSize[oldSplitID + 1][0], 1);
//
//		}*/
//
//		//checks if the minpoint for a specific triangleaabb is larger then current splitvalue
//		//adding to the other side of the split
//
//
//		/*if (aabbList[aabbSplitID].minPoint[KDtree[splitStart + oldSplitID].split.x] > -1 &&
//		aabbList[aabbSplitID].minPoint[KDtree[splitStart + oldSplitID].split.x] < 57)
//		{
//		splittingSwap[workingSplit][workID][0] = oldSplitID;
//		splittingSwap[workingSplit][workID][1] = aabbSplitID;
//
//		InterlockedAdd(splittSize[oldSplitID + 1][0], 1);
//
//		}*/
//
//		/*splittingSwap[workingSplit][workID][0] = oldSplitID;
//		splittingSwap[workingSplit][workID][1] = aabbSplitID;
//
//		InterlockedAdd(splittSize[oldSplitID + 1][0], 1);*/
//
//		/*if (KDtree[splitStart + oldSplitID].split.y > 27 && KDtree[splitStart + oldSplitID].split.y < 28)
//		{
//		splittingSwap[workingSplit][workID][2] = oldSplitID + 1;
//		splittingSwap[workingSplit][workID][3] = aabbSplitID;
//
//		InterlockedAdd(splittSize[oldSplitID + 2][0], 1);
//
//		}*/
//		//if (aabbList[aabbSplitID].maxPoint[KDtree[splitStart + oldSplitID].split.x] < 0.00000)
//		//if (aabbList[aabbSplitID].minPoint.z >= 0.00000)
//		////if (aabbList[aabbSplitID].maxPoint[KDtree[splitStart + oldSplitID].split.x] == -10.00000)
//		////if (splitStart + oldSplitID == 0)
//		////if (KDtree[splitStart + oldSplitID].split.x < 4)
//		//{
//
//
//		//	splittingSwap[workingSplit][workID][0] = oldSplitID;
//		//	splittingSwap[workingSplit][workID][1] = aabbSplitID;
//
//		//	InterlockedAdd(splittSize[oldSplitID + 1][0], 1);
//
//
//		//	splittingSwap[workingSplit][workID][2] = oldSplitID + 1;
//		//	splittingSwap[workingSplit][workID][3] = aabbSplitID;
//
//		//	InterlockedAdd(splittSize[oldSplitID + 2][0], 1);
//
//		//}
//	}
//	workID += NROFTHREADSCREATIONDISPATCHES;
//}
//
////////////////////////////////////////////////////////////////////////
////	Ber�kna start index f�r varje split
////////////////////////////////////////////////////////////////////////
//
//
//
//DeviceMemoryBarrierWithGroupSync();
//
//
//
//
//workID = threadIndex;
//
//while (workID < 2999999)
//{
//	splittSize[workID][1] = splittSize[workID + 1][0];
//	workID += NROFTHREADSCREATIONDISPATCHES;
//
//}
//
//
//
//DeviceMemoryBarrierWithGroupSync();
//
//int sum = 0;
//workID = 1;
//if (threadIndex == 0)
//{
//	while (workID < MAXSIZE)
//	{
//		sum += splittSize[workID][0];
//		//splittSize[workID][1] = splittSize[workID][0];
//		splittSize[workID][0] = sum;
//		workID++;
//	}
//}
//
////DeviceMemoryBarrierWithGroupSync();
//
//
//
////////////////////////////////////////////////////////////////////////
////	Flytta splitten
////////////////////////////////////////////////////////////////////////
//
////workID = threadIndex;
//
//
////// splittingSwap[2] // swapping structure to move and create the list of indices // the int4 holds x = the left split index, y = the left aabb index, z = the right split index, w = right the aabb index  
////// splitStart // the amount of splits for the current depth
////// moveSplit // the split to move the list to
////// workingSplit // the split that the elements are to be split from
////// splittSize // contains the start intex to wright to for the splits and how many has been written
//
//
//
////while (workID < (1 << (depth + 1)))
////{
//
////	int counter = 0;
//
////	//while (splittingSwap[workingSplit][counter][0] != -1 || splittingSwap[workingSplit][counter][2] != -1) // FEL H�R DETTA F�R TRIANGLAR ATT F�RSVINNA OM EN TRIANGEL INTE ANSES FINNAS I KD-TR�DET
////	while (counter < highIndex) // FEL H�R DETTA F�R TRIANGLAR ATT F�RSVINNA OM EN TRIANGEL INTE ANSES FINNAS I KD-TR�DET
////	{
////		int leftRight = workID % 2;
//
//
//
////		if (splittingSwap[workingSplit][counter][leftRight * 2] == workID)
////		{
////			//int splitOffset = splittSize[workID][0]; // the offset to the start of the split the value belongs in
////			//int moveID = splittSize[workID][1]; // the id offset to move the data to
//
////			splittingSwap[workingSplit][splittSize[workID][0]][0] = splittingSwap[moveSplit][counter][leftRight * 2];
////			splittingSwap[workingSplit][splittSize[workID][0]][1] = splittingSwap[moveSplit][counter][(leftRight * 2) + 1];
////			splittingSwap[workingSplit][splittSize[workID][0]][2] = -1;
////			splittingSwap[workingSplit][splittSize[workID][0]][3] = -1;
//
////			splittingSwap[moveSplit][counter][leftRight * 2] = -1;
////			splittingSwap[moveSplit][counter][(leftRight * 2) + 1] = -1;
////			//mutex[counter] = splittingSwap[moveSplit][splittSize[workID][0]][0];
//
//
////			InterlockedAdd(splittSize[workID][0], 1);
////		}
//
////		counter++;
////	}
//
////	workID += NROFTHREADSCREATIONDISPATCHES;
//
////}
//
//
////////////////////////////////////////////////////////////////////////
////	G�r redo f�r n�sta split level
////////////////////////////////////////////////////////////////////////
//
////DeviceMemoryBarrierWithGroupSync();
//
//
////workID = threadIndex;
//
////if (depth == 0)
////{
//
////	mutex[0] = Depth37; //--------------------------------------------------------------------- DEBUGING
////	//mutex[workID * 2] = splittSize[workID][0]; //--------------------------------------------------------------------- DEBUGING
////	//mutex[(workID * 2) + 1] = splittSize[workID][1]; //--------------------------------------------------------------------- DEBUGING
////}
//
////DeviceMemoryBarrierWithGroupSync();
//
//
//
////// Splitta boxarna i kd-tr�det -- done?
////// Flytta vilken split som �r working och move - done
////// cleara move splitten om splitsen �r bytta - tror inte denna beh�vs
////// clear splitSize - done
//
////workID = threadIndex;
//
//
//
////int startIndexThisDepth = (1 << (depth + 1)) - 1;
////int nextDepth = (1 << (depth + 1));
////int startIndexNextDepth = (1 << (depth + 2)) - 1;
//
////while (workID < (nextDepth))
////{
////	// splitStart  // the number of nodes in the current depth
//
//
//
////	if (splittSize[workID][1] > 6 && depth < MAXDEPTH - 1) // splitta boxen och skriv till n�sta djup
////	{
//
////		// 0 = current depth = splitstart + workID
////		// 1 = left child = splitstart + (workID * 2)
////		// 2 = right child = splitstart + ((workID * 2) + 1)
//
////		// add to continue splitting
////		InterlockedAdd(indexingCount[1], indexingCount[1] + 1, indexingCount[2]);
//
//
////		// chose the best split axis
////		int splitAxis; // 0 = x, 1 = y, 2 = z
////		float splitLength[3];
////		splitLength[0] = KDtree[startIndexThisDepth + workID].aabb.maxPoint.x - KDtree[startIndexThisDepth + workID].aabb.minPoint.x;
////		splitLength[1] = KDtree[startIndexThisDepth + workID].aabb.maxPoint.y - KDtree[startIndexThisDepth + workID].aabb.minPoint.y;
////		splitLength[2] = KDtree[startIndexThisDepth + workID].aabb.maxPoint.z - KDtree[startIndexThisDepth + workID].aabb.minPoint.z;
//
////		splitAxis = splitLength[0] > splitLength[1] ? 0 : 1;
////		splitAxis = splitLength[splitAxis] > splitLength[2] ? splitAxis : 2;
//
////		//float middleOffset = (KDtree[startIndexThisDepth + (workID * 2)].aabb.maxPoint[splitAxis] - KDtree[startIndexThisDepth + (workID * 2)].aabb.minPoint[splitAxis]) * 0.5f;
//
////		float middleOffset = KDtree[startIndexThisDepth + workID].aabb.maxPoint[splitAxis];
////		middleOffset -= KDtree[startIndexThisDepth + workID].aabb.minPoint[splitAxis];
////		middleOffset *= 0.5f;
//
////		// left
////		KDtree[startIndexNextDepth + (workID * 2)] = KDtree[startIndexThisDepth + workID];
////		KDtree[startIndexNextDepth + (workID * 2)].index = -1;
//
////		KDtree[startIndexNextDepth + (workID * 2)].aabb.maxPoint[splitAxis] -= middleOffset;
//
////		KDtree[startIndexNextDepth + (workID * 2)].split.x = splitAxis;
////		KDtree[startIndexNextDepth + (workID * 2)].split.y = KDtree[startIndexNextDepth + (workID * 2)].aabb.maxPoint[splitAxis];
//
////		// right
////		KDtree[startIndexNextDepth + ((workID * 2) + 1)] = KDtree[startIndexThisDepth + workID];
////		KDtree[startIndexNextDepth + ((workID * 2) + 1)].index = -1;
//
////		KDtree[startIndexNextDepth + ((workID * 2) + 1)].aabb.minPoint[splitAxis] += middleOffset;
//
////		KDtree[startIndexNextDepth + (workID * 2)].split.x = splitAxis;
////		KDtree[startIndexNextDepth + (workID * 2)].split.y = KDtree[startIndexNextDepth + ((workID * 2) + 1)].aabb.minPoint[splitAxis];
//
////	}
////	else if (splittSize[workID][0] > 0)// leafNode
////	{
////		// KDtree index				-	index to start reading triangle indexes from
////		// KDtree nrOfTriangles		-	the amount to read
////		// KDtree split				-	not needed
////		// KDtree aabb minPoint		-	not needed
////		// KDtree aabb maxPoint		-	not needed
//
////		// startIndexThisDepth
////		// KDtree[startIndexThisDepth]
//
////		// nr of traingles											- finns i splittSize[1] 
////		int nrOfTrianglesInSplit = splittSize[workID][1];
//
////		// Start location of the triangles in the splittingSwap		- ber�knas med splittSize[0] - splittSize[1]
////		int splittingSwapStartLocation = splittSize[workID][0] - splittSize[workID][1];
//
////		// Location to write them to								- anv�nd indexingCount[0] samt InterlockedAdd f�r att best�mma plattsen
////		int wrightLocation;
////		InterlockedAdd(indexingCount[0], nrOfTrianglesInSplit, wrightLocation);
//
////		KDtree[startIndexThisDepth + workID].index = wrightLocation;
////		KDtree[startIndexThisDepth + workID].nrOfTriangles = nrOfTrianglesInSplit;
//
////		//KDtree[startIndexThisDepth + workID].split[0] = depth;
////		//KDtree[startIndexThisDepth + workID].split[1] = 50;
//
//
//
////		for (int i = 0; i < nrOfTrianglesInSplit; i++)
////		{
//
//
//
////			indiceList[wrightLocation + i] = aabbList[splittingSwap[workingSplit][splittingSwapStartLocation + i][1]].triangleID;
////			splittingSwap[workingSplit][splittingSwapStartLocation + i][0] = -1;  // KAN G� HELT �T SKOGEN ATT S�TTA DEM TILL -1 H�R -----------------------------------------------------------------
////			splittingSwap[workingSplit][splittingSwapStartLocation + i][1] = -1;
//
//
////		}
//
//
////	}
////	else
////	{
////		KDtree[startIndexNextDepth + workID].index = 0;
////		KDtree[startIndexNextDepth + workID].aabb.minPoint.w = startIndexNextDepth + workID;
////		KDtree[startIndexNextDepth + workID].aabb.minPoint.z = startIndexNextDepth;
////		KDtree[startIndexNextDepth + workID].aabb.minPoint.y = nextDepth;
////		KDtree[startIndexNextDepth + workID].aabb.minPoint.x = startIndexThisDepth;
//
////		KDtree[startIndexNextDepth + workID].aabb.maxPoint.w = 9999;
////		KDtree[startIndexNextDepth + workID].aabb.maxPoint.z = 9999;
////		KDtree[startIndexNextDepth + workID].aabb.maxPoint.y = 9999;
////		KDtree[startIndexNextDepth + workID].aabb.maxPoint.x = 9999;
//
////		KDtree[startIndexNextDepth + workID].split[0] = depth;
////		KDtree[startIndexNextDepth + workID].split[1] = workID;
////	}
//
////	workID += NROFTHREADSCREATIONDISPATCHES;
//
////}
//*/