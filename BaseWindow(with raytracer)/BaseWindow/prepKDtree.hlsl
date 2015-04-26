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

					KDtree[startIndexNextDepth + (workID * 2)].split = splitAxis;
					KDtree[startIndexNextDepth + (workID * 2)].split = KDtree[startIndexNextDepth + (workID * 2)].aabb.maxPoint[splitAxis];

					// right
					KDtree[startIndexNextDepth + ((workID * 2) + 1)] = KDtree[startIndexThisDepth + workID];
					KDtree[startIndexNextDepth + ((workID * 2) + 1)].index = -1;

					KDtree[startIndexNextDepth + ((workID * 2) + 1)].aabb.minPoint[splitAxis] += middleOffset;

					KDtree[startIndexNextDepth + (workID * 2)].split = splitAxis;
					KDtree[startIndexNextDepth + (workID * 2)].split = KDtree[startIndexNextDepth + ((workID * 2) + 1)].aabb.minPoint[splitAxis];

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




			//int temp = indexingCount[3];
			//indexingCount[3] = indexingCount[4];
			//indexingCount[4] = temp;


			if (threadIndex == 0)
			{
				indexingCount[1] += 1;
				indexingCount[2] = splittSize[(1 << (depth + 1))][0];

			}

			while (workID < indexingCount[2])
			{
				splittingSwap[moveSplit][workID] = splittingSwap[workingSplit][workID];


				workID += NROFTHREADSCREATIONDISPATCHES;
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
