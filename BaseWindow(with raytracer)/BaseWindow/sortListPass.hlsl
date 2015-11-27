#include "Collisions.fx"

ConsumeStructuredBuffer<int4> ConsumeIndiceBuffer : register(u0);

RWStructuredBuffer<int2> IndiceBuffer : register(u1); // x: kdtree index - y: aabb index

RWStructuredBuffer<int> IndiceFinal : register(u2); // The final output list of 

RWStructuredBuffer<int2> UnsortedList : register(u3);

RWStructuredBuffer<int2> ParallelScan : register(u4);

RWStructuredBuffer<int2> splittSize : register(u5); // used for storing the size of every split and then the start values of the split 0 = size of previus split, 1 = offset in current split

RWStructuredBuffer<NodePass2> KDtree : register(u6);

[numthreads(CORETHREADSWIDTH, CORETHREADSHEIGHT, 1)]
void main(uint3 threadID : SV_DispatchThreadID)
{

	int workID = threadID;

	int2 data = ConsumeIndiceBuffer.Consume();
	while (data.x != 0)
	{
		IndiceBuffer[workID] = data;
		data = ConsumeIndiceBuffer.Consume();
		workID += NROFTHREADSCREATIONDISPATCHES;
	}

	DeviceMemoryBarrierWithGroupSync();

	//Isolate unique leafnode ids and store them in UnsortedList.x
	workID = threadID;
	while (workID < MAXSIZE)
	{
		UnsortedList[IndiceBuffer[workID].x].x = IndiceBuffer[workID].x;
		UnsortedList[IndiceBuffer[workID].x].y = 1;
		workID += NROFTHREADSCREATIONDISPATCHES;

	}

	UnsortedList[0] = 0; // Reset the false true

	DeviceMemoryBarrierWithGroupSync();

	//Sort the list of unique leafnode indexes
	workID = threadID;
	while (workID < MAXSIZE)
	{

		ParallelScan[workID][0] = UnsortedList[workID].y;
		ParallelScan[workID][1] = UnsortedList[workID].y;

		workID += NROFTHREADSCREATIONDISPATCHES;
	}

	
	int from = 0;
	int to = 1;
	int bitOffset = 1;
	while (bitOffset < (1 << MAXDEPTH) ) // needs to find the exiting condition
	{
		workID = threadID;

		while (workID < MAXSIZE)
		{
			ParallelScan[workID][to] = ParallelScan[workID][from];

			workID += NROFTHREADSCREATIONDISPATCHES;
		}

		workID = threadID + bitOffset;

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

	//// Place the Unique indexes on the correct indexes
	//while (workID < MAXSIZE)
	//{
	//	if (UnsortedList[workID].x > 0)
	//	{
	//		int leafIndex = UnsortedList[workID].x;
	//		UnsortedList[workID].x = 0;
	//		UnsortedList[workID].y = 0;

	//		UnsortedList[ParallelScan[workID][from] - 1].x = leafIndex;
	//	}

	//	workID += NROFTHREADSCREATIONDISPATCHES;
	//}

	//DeviceMemoryBarrierWithGroupSync();

	//// Calculate the final indice list start positions and assign them to the leaf nodes
	//workID = threadID;
	//while (workID < MAXSIZE) // Places the nr of aabbs next to the leafnode index thet holds them and resets ParallelScan
	//{
	//	UnsortedList[workID].y = splittSize[UnsortedList[workID].x].x;
	//	KDtree[UnsortedList[workID].x].nrOfTriangles = UnsortedList[workID].y;
	//	ParallelScan[workID] = 0;

	//	workID += NROFTHREADSCREATIONDISPATCHES;
	//}

	//DeviceMemoryBarrierWithGroupSync();

	//workID = threadID;
	//while (workID < MAXSIZE) // Makes a Scan operation on the nr of triangles to determine start index positions
	//{
	//	
	//	int loopStep = workID;
	//	while (loopStep < MAXSIZE)
	//	{
	//		InterlockedAdd(ParallelScan[loopStep], UnsortedList[workID].y);
	//		loopStep += 1;
	//	}

	//	workID += NROFTHREADSCREATIONDISPATCHES;
	//}

	//DeviceMemoryBarrierWithGroupSync();
	//workID = MAXSIZE - threadID;
	//while (workID > 1) // Move the start indexes so the the start index is 0;
	//{
	//	int index = UnsortedList[workID - 1].y;
	//	UnsortedList[workID].y = index;

	//	workID -= NROFTHREADSCREATIONDISPATCHES;
	//}
	//UnsortedList[0].y = 0;


	//DeviceMemoryBarrierWithGroupSync();
	//workID = threadID;
	//while (workID < MAXSIZE) // Assign the start possitions to the leaf nodes
	//{
	//	KDtree[UnsortedList[workID].x].index = UnsortedList[workID].y;

	//	workID += NROFTHREADSCREATIONDISPATCHES;
	//}

	//// Assign the aabb indexes to the correct leafnode index intervalls
	////(slow version)
	//DeviceMemoryBarrierWithGroupSync();
	//workID = threadID;

	//unsigned int i = 0;
	//if (UnsortedList[workID].x > 0)
	//{
	//	while (i < MAXSIZE)
	//	{
	//		if (IndiceBuffer[i].x == UnsortedList[workID].x)
	//		{
	//			IndiceFinal[UnsortedList[workID].y] = IndiceBuffer[i].x;
	//			InterlockedAdd(UnsortedList[workID].y,1);
	//		}
	//		i+=1;
	//	}
	//}

}