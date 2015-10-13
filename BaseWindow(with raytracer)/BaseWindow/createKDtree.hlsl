#include "Collisions.fx"



StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);

RWStructuredBuffer<NodePass2> KDtree : register(u1);

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
	int depth = 0;							// the current depth of the tree;



	// Creating kd-tree

	int lowIndex = 0;						// the current treads low work index
	int highIndex = nrOfTriangles;			// the current treads end work index




	while (depth < MAXOFFLINEDEPTH)
	{

		int startIndexThisDepth = (1 << (depth)) - 1;
		int nextDepth = (1 << (depth));
		int startIndexNextDepth = (1 << (depth + 1)) - 1;


		while (workID < (nextDepth))
		{
			// splitStart  // the number of nodes in the current depth


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


			workID += NROFTHREADSCREATIONDISPATCHES;

		}

		workID = threadIndex;

		depth++;
	}
}


