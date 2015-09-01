#include "Collisions.fx"



//StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);

RWStructuredBuffer<NodePass2> KDtree : register(u1);

RWStructuredBuffer<int> indiceList : register(u2);


RWStructuredBuffer<int4> splittingSwap[2] : register(u3); // the int4 holds x = the left split index, y = the left aabb index, z = the right split index, w = right the aabb index  

RWStructuredBuffer<int2> splittSize : register(u5); // used for storing the size of every split and then the start values of the split 0 = size of previus split, 1 = offset in current split

RWStructuredBuffer<int> indexingCount : register(u6); // using this struct to designate which index in the indiceList to wright the leaf node to, index 1 is a value to see if the tree is complete, index 2 is highIndex, index 3 = workingSplit, index 4 = moveSplit

RWStructuredBuffer<int> mutex : register(u7);	// Used in the custom interlocking function


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





	// Creating kd-tree

	int lowIndex = 0;						// the current treads low work index
	int highIndex = indexingCount[2];			// the current treads end work index

	while (workID < MAXSIZE)
	{
		splittSize[workID][0] = 0;
		splittSize[workID][1] = 0;

		/*		splittingSwap[moveSplit][workID][0] = -1;
		splittingSwap[moveSplit][workID][1] = -1;*/

		workID += NROFTHREADSCREATIONDISPATCHES;

	}

	workID = threadIndex;						// setting the workID for the first pass

	//////////////////////////////////////////////////////////////////////
	//	Beräkna splitsen för arbets listan
	//////////////////////////////////////////////////////////////////////
	int splitStart = (1 << depth + 1) - 1; // the start index for the kdtree at the current depth
	int nextSplitAmount = (1 << (depth + 1)); // the amount of splits for the next lvl

	while (workID < MAXSIZE)
	{
		//first:	what array to work from
		//second:	offset in the array
		//third:	int4(x,y,z,w)
		//splittingSwap[0/1][0/MAXSIZE][0/3]

		if (splittingSwap[workingSplit][workID][0] != -1)
		{
			int	oldSplitID = splittingSwap[workingSplit][workID][0];
			oldSplitID *= 2;

			int	aabbSplitID = splittingSwap[workingSplit][workID][1];

			//sets the values to -1 to represent empty
			splittingSwap[workingSplit][workID][0] = -1;
			splittingSwap[workingSplit][workID][1] = -1;
			splittingSwap[workingSplit][workID][2] = -1;
			splittingSwap[workingSplit][workID][3] = -1;

			//checks if the maxpoint for a specific triangleaabb is smaller then current splitvalue
			//adding to one side of the split
			//if (aabbList[aabbSplitID].maxPoint[KDtree[splitStart + oldSplitID].split.x] < KDtree[splitStart + oldSplitID].split.y)
			//{
			//	splittingSwap[workingSplit][workID][0] = oldSplitID;
			//	splittingSwap[workingSplit][workID][1] = aabbSplitID;

			//	InterlockedAdd(splittSize[oldSplitID + 1][0], 1);

			//}
			////checks if the minpoint for a specific triangleaabb is larger then current splitvalue
			////adding to the other side of the split
			//else if (aabbList[aabbSplitID].minPoint[KDtree[splitStart + oldSplitID].split.x] > KDtree[splitStart + oldSplitID].split.y)
			//{
			//	splittingSwap[workingSplit][workID][2] = oldSplitID + 1;
			//	splittingSwap[workingSplit][workID][3] = aabbSplitID;

			//	InterlockedAdd(splittSize[oldSplitID + 2][0], 1);

			//}
			//else //the split is through the triangleaabb
			//added to both sides of the split
			//if (splittingSwap[workingSplit][workID][0] == -1 && splittingSwap[workingSplit][workID][2] == -1)
			{
				splittingSwap[workingSplit][workID][0] = oldSplitID;
				splittingSwap[workingSplit][workID][1] = aabbSplitID;

				InterlockedAdd(splittSize[oldSplitID + 1][0], 1);


				splittingSwap[workingSplit][workID][2] = oldSplitID + 1;
				splittingSwap[workingSplit][workID][3] = aabbSplitID;

				InterlockedAdd(splittSize[oldSplitID + 2][0], 1);

			}



			/*if (aabbList[aabbSplitID].maxPoint[KDtree[splitStart + oldSplitID].split.x] < 60)
			{
			splittingSwap[workingSplit][workID][0] = oldSplitID;
			splittingSwap[workingSplit][workID][1] = aabbSplitID;

			InterlockedAdd(splittSize[oldSplitID + 1][0], 1);

			}*/

			//checks if the minpoint for a specific triangleaabb is larger then current splitvalue
			//adding to the other side of the split


			/*if (aabbList[aabbSplitID].minPoint[KDtree[splitStart + oldSplitID].split.x] > -1 &&
			aabbList[aabbSplitID].minPoint[KDtree[splitStart + oldSplitID].split.x] < 57)
			{
			splittingSwap[workingSplit][workID][0] = oldSplitID;
			splittingSwap[workingSplit][workID][1] = aabbSplitID;

			InterlockedAdd(splittSize[oldSplitID + 1][0], 1);

			}*/

			/*splittingSwap[workingSplit][workID][0] = oldSplitID;
			splittingSwap[workingSplit][workID][1] = aabbSplitID;

			InterlockedAdd(splittSize[oldSplitID + 1][0], 1);*/

			/*if (KDtree[splitStart + oldSplitID].split.y > 27 && KDtree[splitStart + oldSplitID].split.y < 28)
			{
			splittingSwap[workingSplit][workID][2] = oldSplitID + 1;
			splittingSwap[workingSplit][workID][3] = aabbSplitID;

			InterlockedAdd(splittSize[oldSplitID + 2][0], 1);

			}*/
			//if (aabbList[aabbSplitID].maxPoint[KDtree[splitStart + oldSplitID].split.x] < 0.00000)
			//if (aabbList[aabbSplitID].minPoint.z >= 0.00000)
			////if (aabbList[aabbSplitID].maxPoint[KDtree[splitStart + oldSplitID].split.x] == -10.00000)
			////if (splitStart + oldSplitID == 0)
			////if (KDtree[splitStart + oldSplitID].split.x < 4)
			//{


			//	splittingSwap[workingSplit][workID][0] = oldSplitID;
			//	splittingSwap[workingSplit][workID][1] = aabbSplitID;

			//	InterlockedAdd(splittSize[oldSplitID + 1][0], 1);


			//	splittingSwap[workingSplit][workID][2] = oldSplitID + 1;
			//	splittingSwap[workingSplit][workID][3] = aabbSplitID;

			//	InterlockedAdd(splittSize[oldSplitID + 2][0], 1);

			//}
		}
		workID += NROFTHREADSCREATIONDISPATCHES;
	}


}







