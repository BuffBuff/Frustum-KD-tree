#include "Collisions.fx"

RWStructuredBuffer<int2> IndiceBuffer : register(u1); // x: kdtree index - y: aabb index

RWStructuredBuffer<int> IndiceFinal : register(u2); // The final output list of 

RWStructuredBuffer<int2> UnsortedList : register(u3);

RWStructuredBuffer<int2> ParallelScan : register(u4);

RWStructuredBuffer<int2> splittSize : register(u5); // used for storing the size of every split and then the start values of the split 0 = size of previus split, 1 = offset in current split

RWStructuredBuffer<NodePass2> KDtree : register(u6);


[numthreads(1, 1, 1)]
void main(uint3 threadID : SV_DispatchThreadID)
{
	int threadIndex = threadID.x + threadID.y * CREATIONHEIGHT;

	int workID = threadIndex;

	// Assign the aabb indexes to the correct leafnode index intervalls
	//(slow version)

	unsigned int i = 0;
	while (i < MAXSIZE)
	{
		if (IndiceBuffer[i].x > -1)
		{
			IndiceFinal[splittSize[workID].x] = IndiceBuffer[i].x;
			InterlockedAdd(splittSize[workID].x, 1);
		}
		i += 1;
	}
}