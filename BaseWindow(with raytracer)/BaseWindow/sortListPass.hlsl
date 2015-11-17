#include "Collisions.fx"

ConsumeStructuredBuffer<int2> ConsumeIndiceBuffer : register(u0);

RWStructuredBuffer<int2> IndiceBuffer : register(u1);

RWStructuredBuffer<int> IndiceFinal : register(u2);

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

}