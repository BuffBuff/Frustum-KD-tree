#include "Collisions.fx"

ConsumeStructuredBuffer<int4> ConsumeIndiceBuffer : register(u0);
//RWStructuredBuffer<int4> ConsumeIndiceBuffer : register(u0);

RWStructuredBuffer<int2> IndiceBuffer : register(u1); // x: kdtree index - y: aabb index

RWStructuredBuffer<int> IndiceFinal : register(u2); // The final output list of 

RWStructuredBuffer<int2> UnsortedList : register(u3);

RWStructuredBuffer<int2> ParallelScan : register(u4);

RWStructuredBuffer<int2> splittSize : register(u5); // used for storing the size of every split and then the start values of the split 0 = size of previus split, 1 = offset in current split

RWStructuredBuffer<NodePass2> KDtree : register(u6);

static int threadJump = 0;

[numthreads(1, 1, 1)]
void main(uint3 threadID : SV_DispatchThreadID)
{
	int threadIndex = threadID.x + threadID.y * CREATIONHEIGHT;

	int workID = threadIndex;

	//while (workID < MAXSIZE)
	//{
	//	IndiceBuffer[workID].x = -1;
	//	IndiceBuffer[workID].y = -1;

	//	UnsortedList[workID][0] = -1;
	//	UnsortedList[workID][1] = -1;

	//	workID += NROFTREADSKDTREECREATION;
	//}
	//
	//DeviceMemoryBarrierWithGroupSync();

	//workID = threadIndex;

	//if (workID == 0)
	{

		int4 data = ConsumeIndiceBuffer.Consume();

		while (data.z == -1)
		{
			IndiceBuffer[workID] = data.xy;

			//IndiceFinal[data.y] = data.y + 1;


			data = ConsumeIndiceBuffer.Consume();
			//if (data.y > 0 || data.x > 0 || data.z > 0 || data.w > 0)

			//workID += NROFTHREADSCREATIONDISPATCHES;
		}
	}


}