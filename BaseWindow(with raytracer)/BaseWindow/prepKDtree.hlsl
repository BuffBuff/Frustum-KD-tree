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
	int depth = 0;							// the current depth of the tree;
	int nrOfElements = nrOfTriangles;




		//////////////////////////////////////////////////////////////////////
		//	G�r redo f�r n�sta split level
		//////////////////////////////////////////////////////////////////////

		DeviceMemoryBarrierWithGroupSync();


			// Splitta boxarna i kd-tr�det -- done?
			// Flytta vilken split som �r working och move - done
			// cleara move splitten om splitsen �r bytta - tror inte denna beh�vs
			// clear splitSize - done
		
			workID = threadIndex;

			int startIndexThisDepth = (1 << (depth + 1)) - 1;
			int nextDepth = (1 << (depth + 1));
			int startIndexNextDepth = (1 << (depth + 2)) -1;

			while (workID < (nextDepth))
			{
				// splitStart  // the number of nodes in the current depth



				if (splittSize[workID][1] > 6 && depth < MAXDEPTH - 1) // splitta boxen och skriv till n�sta djup
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
					splitAxis = splitLength[splitAxis] > splitLength[2] ? splitAxis : 2;

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

					// Start location of the triangles in the splittingSwap		- ber�knas med splittSize[0] - splittSize[1]
					int splittingSwapStartLocation = splittSize[workID][0] - splittSize[workID][1];

					// Location to write them to								- anv�nd indexingCount[0] samt InterlockedAdd f�r att best�mma plattsen
					int wrightLocation;
					InterlockedAdd(indexingCount[0], nrOfTrianglesInSplit, wrightLocation);

					KDtree[startIndexThisDepth + workID].index = wrightLocation;
					KDtree[startIndexThisDepth + workID].nrOfTriangles = nrOfTrianglesInSplit;

					//KDtree[startIndexThisDepth + workID].split[0] = depth;
					//KDtree[startIndexThisDepth + workID].split[1] = 50;



					for (int i = 0; i < nrOfTrianglesInSplit; i++)
					{



						indiceList[wrightLocation + i] = aabbList[splittingSwap[moveSplit][splittingSwapStartLocation + i][1]].triangleID;
						splittingSwap[moveSplit][splittingSwapStartLocation + i][0] = -1;  // KAN G� HELT �T SKOGEN ATT S�TTA DEM TILL -1 H�R -----------------------------------------------------------------
						splittingSwap[moveSplit][splittingSwapStartLocation + i][1] = -1;


					}


				}
				else
				{
					KDtree[startIndexNextDepth + workID].index = 0;
					KDtree[startIndexNextDepth + workID].aabb.minPoint.w = startIndexNextDepth + workID;
					KDtree[startIndexNextDepth + workID].aabb.minPoint.z = startIndexNextDepth;
					KDtree[startIndexNextDepth + workID].aabb.minPoint.y = nextDepth;
					KDtree[startIndexNextDepth + workID].aabb.minPoint.x = startIndexThisDepth;

					KDtree[startIndexNextDepth + workID].aabb.maxPoint.w = 9999;
					KDtree[startIndexNextDepth + workID].aabb.maxPoint.z = 9999;
					KDtree[startIndexNextDepth + workID].aabb.maxPoint.y = 9999;
					KDtree[startIndexNextDepth + workID].aabb.maxPoint.x = 9999;

					KDtree[startIndexNextDepth + workID].split[0] = depth;
					KDtree[startIndexNextDepth + workID].split[1] = workID;
				}

				workID += NROFTHREADSCREATIONDISPATCHES;

			}



}









/*
////////////////////////////////////////////////////////////// NEJ funkar ej beskriver old felet

//int output;// = CustomInterlockedAdd(0, 1);


//InterlockedAdd(splittSize[0][0], 1, output); // denna rad ska addera ett v�rde till splittSize[0][0] och sedan returnera v�rdet under det nya v�rdet // detta �r inte vad den g�r

//// -- varje tr�d i parallel
//// Addera 1 till splittSize[0][0]
//// F� ut v�rdet som blir efter att den egna tr�den har adderat 1
//// S�tt output till v�rdet som f�s ut
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

//		InterlockedAdd(splittSize[moveToSplit][0], 1, moveID);// moveID f�r orginal v�rdet av splittSize? sen adderas alla tr�darna

//		splittingSwap[moveSplit][moveID][0] = splittingSwap[workingSplit][workID][0];
//		splittingSwap[moveSplit][moveID][1] = splittingSwap[workingSplit][workID][1];
//		splittingSwap[moveSplit][moveID][2] = -1;
//		splittingSwap[moveSplit][moveID][3] = -1;
//	}
//	if (splittingSwap[workingSplit][workID][2] != -1)
//	{
//		moveToSplit = splittingSwap[workingSplit][workID][2];
//		//splitOffset = splittSize[moveToSplit];

//		InterlockedAdd(splittSize[moveToSplit][0], 1, moveID); // moveID f�r orginal v�rdet av splittSize? sen adderas alla tr�darna

//		splittingSwap[moveSplit][moveID][0] = splittingSwap[workingSplit][workID][2];
//		splittingSwap[moveSplit][moveID][1] = splittingSwap[workingSplit][workID][3];
//		splittingSwap[moveSplit][moveID][2] = -1;
//		splittingSwap[moveSplit][moveID][3] = -1;
//	}


//		workID += NROFTHREADSCREATIONDISPATCHES;
//	}

/////////////////////////// END OLD
*/
