#include "Collisions.fx"

RWStructuredBuffer<int2> IndiceBuffer : register(u1); // x: kdtree index - y: aabb index

RWStructuredBuffer<int> IndiceFinal : register(u2); // The final output list of 

RWStructuredBuffer<int2> UnsortedList : register(u3);

RWStructuredBuffer<int2> ParallelScan : register(u4);

RWStructuredBuffer<int2> splittSize : register(u5); // used for storing the size of every split and then the start values of the split 0 = size of previus split, 1 = offset in current split

RWStructuredBuffer<NodePass2> KDtree : register(u6);


[numthreads(CORETHREADSWIDTH, CORETHREADSHEIGHT, 1)]
void main(uint3 threadID : SV_DispatchThreadID)
{
	int threadIndex = threadID.x + threadID.y * CREATIONHEIGHT;

	int workID = threadIndex;

	//Isolate unique leafnode ids and store them in UnsortedList.x

	while (workID < MAXSIZE)
	{
		UnsortedList[IndiceBuffer[workID].x].x = IndiceBuffer[workID].x;
		UnsortedList[IndiceBuffer[workID].x].y = 1;
		workID += NROFTHREADSCREATIONDISPATCHES;
	}

	DeviceMemoryBarrierWithGroupSync();

	//Sort the list of unique leafnode indexes
	workID = threadIndex;
	while (workID < MAXSIZE)
	{

		ParallelScan[workID][0] = UnsortedList[workID].y;
		ParallelScan[workID][1] = UnsortedList[workID].y;

		workID += NROFTHREADSCREATIONDISPATCHES;
	}

	DeviceMemoryBarrierWithGroupSync();

	int from = 0;
	int to = 1;
	int bitOffset = 1;
	int max = 1 << MAXDEPTH;
	while (bitOffset != max) // needs to find the exiting condition
	{
		workID = threadIndex;

		while (workID < MAXSIZE)
		{
			ParallelScan[workID][to] = ParallelScan[workID][from];

			workID += NROFTHREADSCREATIONDISPATCHES;
		}

		workID = threadIndex + bitOffset;

		while (workID < MAXSIZE)
		{

			ParallelScan[workID][to] = ParallelScan[workID][from] + ParallelScan[workID - bitOffset][from];

			workID += NROFTHREADSCREATIONDISPATCHES;
		}
		bitOffset = bitOffset << 1; // måste kolla om det stämmer

		int temp = from;
		from = to;
		to = temp;
	}


	DeviceMemoryBarrierWithGroupSync();
	workID = threadIndex;

	// Place the Unique indexes on the correct indexes
	while (workID < MAXSIZE)
	{
		if (UnsortedList[workID].x != -1)
		{
			int leafIndex = UnsortedList[workID].x;
			UnsortedList[workID].x = 0;
			UnsortedList[workID].y = 0;

			UnsortedList[ParallelScan[workID][from] - 1].x = leafIndex;
		}

		workID += NROFTHREADSCREATIONDISPATCHES;
	}

}