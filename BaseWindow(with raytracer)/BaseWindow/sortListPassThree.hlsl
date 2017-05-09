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

	

	// Calculate the final indice list start positions and assign them to the leaf nodes
	workID = threadIndex;
	while (workID < MAXSIZE) // Places the nr of aabbs next to the leafnode index that holds them and resets ParallelScan
	{
		UnsortedList[workID].y = splittSize[UnsortedList[workID].x].x;
		KDtree[UnsortedList[workID].x].nrOfTriangles = UnsortedList[workID].y;
		ParallelScan[workID].x = 0;
		ParallelScan[workID].y = 0;

		workID += NROFTHREADSCREATIONDISPATCHES;
	}

	DeviceMemoryBarrierWithGroupSync();
	workID = threadIndex;
	while (workID < MAXSIZE-1)
	{

		ParallelScan[workID+1][0] = UnsortedList[workID].y;
		ParallelScan[workID+1][1] = UnsortedList[workID].y;

		workID += NROFTHREADSCREATIONDISPATCHES;
	}

	DeviceMemoryBarrierWithGroupSync();

	int from = 0;
	int to = 1;
	int bitOffset = 1;
	int max = 1 << MAXDEPTH;
	while (bitOffset != max)  // Makes a Scan operation on the nr of triangles to determine start index positions
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

	//DeviceMemoryBarrierWithGroupSync();
	//workID = threadIndex;
	//while (workID < MAXSIZE) // Move the start indexes so the the start index is 0;
	//{
	//	int index = ParallelScan[workID][from];
	//	UnsortedList[workID].y = index;

	//	workID += NROFTHREADSCREATIONDISPATCHES;
	//}
	//UnsortedList[0].y = 0;


	DeviceMemoryBarrierWithGroupSync();
	workID = threadIndex;
	while (workID < MAXSIZE) // Assign the start possitions to the leaf nodes
	{
		KDtree[UnsortedList[workID].x].index = ParallelScan[workID][from];
		UnsortedList[workID].y = ParallelScan[workID][from];

		workID += NROFTHREADSCREATIONDISPATCHES;
	}


	DeviceMemoryBarrierWithGroupSync();
	workID = threadIndex;
	while (workID < MAXSIZE) // Assign the start possitions to the leaf nodes
	{
		splittSize[UnsortedList[workID].x].x = UnsortedList[workID].y;

		workID += NROFTHREADSCREATIONDISPATCHES;
	}

}