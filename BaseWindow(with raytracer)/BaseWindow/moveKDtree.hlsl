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




		//////////////////////////////////////////////////////////////////////
		//	Flytta splitten
		//////////////////////////////////////////////////////////////////////

		workID = threadIndex;

		// splittingSwap[2] // swapping structure to move and create the list of indices // the int4 holds x = the left split index, y = the left aabb index, z = the right split index, w = right the aabb index  
		// splitStart // the amount of splits for the current depth
		// moveSplit // the split to move the list to
		// workingSplit // the split that the elements are to be split from
		// splittSize // contains the start intex to wright to for the splits and how many has been written


		if (workID < (1 << (depth + 1)))
		{

			int counter = 0;

			//while (splittingSwap[workingSplit][counter][0] != -1 || splittingSwap[workingSplit][counter][2] != -1)
			while (counter < highIndex)
			{
				int leftRight = workID % 2;
		
				if (splittingSwap[workingSplit][counter][leftRight * 2] == workID)
				{
					//int splitOffset = splittSize[workID][0]; // the offset to the start of the split the value belongs in
					//int moveID = splittSize[workID][1]; // the id offset to move the data to

					splittingSwap[moveSplit][splittSize[workID][0]][0] = splittingSwap[workingSplit][counter][leftRight * 2];
					splittingSwap[moveSplit][splittSize[workID][0]][1] = splittingSwap[workingSplit][counter][(leftRight * 2) + 1];
					splittingSwap[moveSplit][splittSize[workID][0]][2] = -1;
					splittingSwap[moveSplit][splittSize[workID][0]][3] = -1;

					InterlockedAdd(splittSize[workID][0],1);
				}

				counter++;
			}

			workID += NROFTHREADSCREATIONDISPATCHES;

		}

}







