#include "Collisions.fx"



//StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<AABB> aabbList : register(u0);

RWStructuredBuffer<NodePass2> KDtree : register(u1);

ConsumeStructuredBuffer<int> indiceList : register(u2);

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

	mutex[workID] = -1;

	if (workID == 0)
	{

		for (int i = 0; i < 36; i++)
		{
			mutex[i] = indiceList.Consume();
		}


	}

}