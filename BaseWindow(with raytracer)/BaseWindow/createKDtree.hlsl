#include "Collisions.fx"



//StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);

RWStructuredBuffer<NodePass2> KDtree : register(u1);

RWStructuredBuffer<int> indiceList : register(u2);


RWStructuredBuffer<int4> splittingSwap[2] : register(u3); // the int4 holds x = the left split index, y = the left aabb index, z = the right split index, w = right the aabb index  

RWStructuredBuffer<int2> splittSize : register(u5); // used for storing the size of every split and then the start values of the split 0 = size of previus split, 1 = offset in current split

RWStructuredBuffer<int> indexingCount : register(u6); // using this struct to designate which index in the indiceList to wright the leaf node to, index 1 is the depth value of the current depth

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
	int nrOfElements = nrOfTriangles;




	// Creating kd-tree

	int lowIndex = 0;						// the current treads low work index
	int highIndex = nrOfTriangles;			// the current treads end work index

	//float split;							// the value to use as the split value


	int stop = 0;

	int q;

	//while (depth < 2)
	for (; depth < MAXDEPTH;)
	{

		while (workID < 3000000)
		{
			splittSize[workID][0] = 0;
			splittSize[workID][1] = 0;

	/*		splittingSwap[moveSplit][workID][0] = -1;
			splittingSwap[moveSplit][workID][1] = -1;*/

			workID += NROFTHREADSCREATIONDISPATCHES;

		}

		
		DeviceMemoryBarrierWithGroupSync();
		workID = threadIndex;						// setting the workID for the first pass

		//////////////////////////////////////////////////////////////////////
		//	Beräkna splitsen för arbets listan
		//////////////////////////////////////////////////////////////////////
		int splitStart = (1 << depth + 1) - 1; // the start index for the kdtree at the current depth
		int nextSplitAmount = (1 << (depth + 1)); // the amount of splits for the next lvl

		while (workID < highIndex)
		{
			//first:	what array to work from
			//second:	offset in the array
			//third:	int4(x,y,z,w)
			//splittingSwap[0/1][0/3000000][0/3]
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
			if (aabbList[aabbSplitID].maxPoint[KDtree[splitStart + oldSplitID].split.x] <= KDtree[splitStart + oldSplitID].split.y)
			{
				splittingSwap[workingSplit][workID][0] = oldSplitID;
				splittingSwap[workingSplit][workID][1] = aabbSplitID;

				InterlockedAdd(splittSize[oldSplitID + 1][0], 1);

			}
			//checks if the minpoint for a specific triangleaabb is larger then current splitvalue
			//adding to the other side of the split
			else if (aabbList[aabbSplitID].minPoint[KDtree[splitStart + oldSplitID].split.x] >= KDtree[splitStart + oldSplitID].split.y)
			{
				splittingSwap[workingSplit][workID][2] = oldSplitID + 1;
				splittingSwap[workingSplit][workID][3] = aabbSplitID;

				InterlockedAdd(splittSize[oldSplitID + 2][0], 1);

			}
			//else the split is through the triangleaabb
			//added to both sides of the split
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

		while (workID < 2999999)
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

			while (splittingSwap[workingSplit][counter][0] != -1 || splittingSwap[workingSplit][counter][2] != -1)
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


		//////////////////////////////////////////////////////////////////////
		//	Gör redo för nästa split level
		//////////////////////////////////////////////////////////////////////

		DeviceMemoryBarrierWithGroupSync();


			// Splitta boxarna i kd-trädet -- done?
			// Flytta vilken split som är working och move - done
			// cleara move splitten om splitsen är bytta - tror inte denna behövs
			// clear splitSize - done
		
			workID = threadIndex;

			int startIndexThisDepth = (1 << (depth + 1)) - 1;
			int nextDepth = (1 << (depth + 1));
			int startIndexNextDepth = (1 << (depth + 2)) -1;

			while (workID < (nextDepth))
			{
				// splitStart  // the number of nodes in the current depth

				

				if (splittSize[workID][1] > 8 && MAXDEPTH - 1 != depth) // splitta boxen och skriv till nästa djup
				{

					// 0 = current depth = splitstart + workID
					// 1 = left child = splitstart + (workID * 2)
					// 2 = right child = splitstart + ((workID * 2) + 1)

					// add to continue splitting
					InterlockedAdd(indexingCount[1], indexingCount[1] + 1, indexingCount[2]);


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
					KDtree[startIndexNextDepth + (workID * 2)].index = -1;

					KDtree[startIndexNextDepth + (workID * 2)].aabb.maxPoint[splitAxis] -= middleOffset;

					KDtree[startIndexNextDepth + (workID * 2)].split.x = splitAxis;
					KDtree[startIndexNextDepth + (workID * 2)].split.y = KDtree[startIndexNextDepth + (workID * 2)].aabb.maxPoint[splitAxis];

					// right
					KDtree[startIndexNextDepth + ((workID * 2) + 1)] = KDtree[startIndexThisDepth + workID];
					KDtree[startIndexNextDepth + ((workID * 2) + 1)].index = -1;

					KDtree[startIndexNextDepth + ((workID * 2) + 1)].aabb.minPoint[splitAxis] += middleOffset;

					KDtree[startIndexNextDepth + (workID * 2)].split.x = splitAxis;
					KDtree[startIndexNextDepth + (workID * 2)].split.y = KDtree[startIndexNextDepth + ((workID * 2) + 1)].aabb.minPoint[splitAxis];

				}
				else if (splittSize[workID][0] > 0)// leafNode
				{
					// KDtree index				-	index to start reading triangle indexes from
					// KDtree nrOfTriangles		-	the amount to read
					// KDtree split				-	not needed
					// KDtree aabb minPoint		-	not needed
					// KDtree aabb maxPoint		-	not needed

					// startIndexThisDepth
					// KDtree[startIndexThisDepth]

					// nr of traingles											- finns i splittSize[1] 
					int nrOfTrianglesInSplit = splittSize[workID][1];

					// Start location of the triangles in the splittingSwap		- beräknas med splittSize[0] - splittSize[1]
					int splittingSwapStartLocation = splittSize[workID][0] - splittSize[workID][1];

					// Location to write them to								- använd indexingCount[0] samt InterlockedAdd för att bestämma plattsen
					int wrightLocation;
					InterlockedAdd(indexingCount[0], nrOfTrianglesInSplit, wrightLocation);

					KDtree[startIndexThisDepth + workID].index = wrightLocation;
					KDtree[startIndexThisDepth + workID].nrOfTriangles = nrOfTrianglesInSplit;

					//KDtree[startIndexThisDepth + workID].split[0] = depth;
					//KDtree[startIndexThisDepth + workID].split[1] = 50;

					for (int i = 0; i < nrOfTrianglesInSplit; i++)
					{
						indiceList[wrightLocation + i] = aabbList[splittingSwap[moveSplit][splittingSwapStartLocation + i][1]].triangleID;
						splittingSwap[moveSplit][splittingSwapStartLocation + i][0] = -1;  // KAN GÅ HELT ÅT SKOGEN ATT SÄTTA DEM TILL -1 HÄR -----------------------------------------------------------------
						splittingSwap[moveSplit][splittingSwapStartLocation + i][1] = -1;
					}

				
				}
				/*else
				{
					KDtree[startIndexNextDepth + workID].split[0] = -1;
					KDtree[startIndexNextDepth + workID].split[1] = -1;
				}*/

				workID += NROFTHREADSCREATIONDISPATCHES;

			}

			workID = threadIndex;

			DeviceMemoryBarrierWithGroupSync();


			int temp = workingSplit;
			workingSplit = moveSplit;
			moveSplit = temp;

			highIndex = splittSize[(1 << (depth + 1))][0];


		
		
			depth++;

			DeviceMemoryBarrierWithGroupSync();

			/*if (indexingCount[1] == 0)
			{
				break;
			}*/
	}

}









/*
////////////////////////////////////////////////////////////// NEJ funkar ej beskriver old felet

//int output;// = CustomInterlockedAdd(0, 1);


//InterlockedAdd(splittSize[0][0], 1, output); // denna rad ska addera ett värde till splittSize[0][0] och sedan returnera värdet under det nya värdet // detta är inte vad den gör

//// -- varje tråd i parallel
//// Addera 1 till splittSize[0][0]
//// Få ut värdet som blir efter att den egna tråden har adderat 1
//// Sätt output till värdet som fås ut
//

//splittSize[workID][1] = output;

//splittSize[workID][0] = 0;

//splittSize[0][0] = 0;


//DeviceMemoryBarrierWithGroupSync();


//InterlockedAdd(splittSize[splittSize[workID][1]][0],1);

//	int output = CustomInterlockedAdd(splittSize[workID][0], 999);


/////////////////////////// OLD

//while (splittingSwap[workingSplit][workID][0] != -1 || splittingSwap[workingSplit][workID][2] != -1)
//{
//	int moveID; // the id to move the data to
//	int moveToSplit; // the splitID to move the data to
//	//int splitOffset; // the offset to the start of the split the value belongs in

//	if (splittingSwap[workingSplit][workID][0] != -1)
//	{

//		moveToSplit = splittingSwap[workingSplit][workID][0];
//		//splitOffset = splittSize[moveToSplit];

//		InterlockedAdd(splittSize[moveToSplit][0], 1, moveID);// moveID får orginal värdet av splittSize? sen adderas alla trådarna

//		splittingSwap[moveSplit][moveID][0] = splittingSwap[workingSplit][workID][0];
//		splittingSwap[moveSplit][moveID][1] = splittingSwap[workingSplit][workID][1];
//		splittingSwap[moveSplit][moveID][2] = -1;
//		splittingSwap[moveSplit][moveID][3] = -1;
//	}
//	if (splittingSwap[workingSplit][workID][2] != -1)
//	{
//		moveToSplit = splittingSwap[workingSplit][workID][2];
//		//splitOffset = splittSize[moveToSplit];

//		InterlockedAdd(splittSize[moveToSplit][0], 1, moveID); // moveID får orginal värdet av splittSize? sen adderas alla trådarna

//		splittingSwap[moveSplit][moveID][0] = splittingSwap[workingSplit][workID][2];
//		splittingSwap[moveSplit][moveID][1] = splittingSwap[workingSplit][workID][3];
//		splittingSwap[moveSplit][moveID][2] = -1;
//		splittingSwap[moveSplit][moveID][3] = -1;
//	}


//		workID += NROFTHREADSCREATIONDISPATCHES;
//	}

/////////////////////////// END OLD
*/
