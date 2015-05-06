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
	int depth = indexingCount[1];							// the current depth of the tree;
	int nrOfElements = nrOfTriangles;




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

		
		indexingCount[1] = 0;
		DeviceMemoryBarrierWithGroupSync();
		workID = threadIndex;						// setting the workID for the first pass

		//////////////////////////////////////////////////////////////////////
		//	Beräkna splitsen för arbets listan
		//////////////////////////////////////////////////////////////////////
		int splitStart = (1 << depth + 1) - 1; // the start index for the kdtree at the current depth
		int nextSplitAmount = (1 << (depth + 1)); // the amount of splits for the next lvl

		while (workID < highIndex)
		{
			int	oldSplitID = splittingSwap[workingSplit][workID][0];
			oldSplitID *= 2;

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



				splittingSwap[workingSplit][workID][2] = oldSplitID + 1;
				splittingSwap[workingSplit][workID][3] = aabbSplitID;
				
				InterlockedAdd(splittSize[oldSplitID + 2][0], 1);

			}

			workID += NROFTHREADSCREATIONDISPATCHES;
		}

		//////////////////////////////////////////////////////////////////////
		//	Beräkna start index för varje split
		//////////////////////////////////////////////////////////////////////

		DeviceMemoryBarrierWithGroupSync();

		workID = threadIndex;

		while (workID < MAXSIZE - 1)
		{
			splittSize[workID][1] = splittSize[workID+1][0];
			workID += NROFTHREADSCREATIONDISPATCHES;

		}


		//DeviceMemoryBarrierWithGroupSync();

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


}







