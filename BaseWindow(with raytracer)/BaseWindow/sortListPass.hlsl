

ConsumeStructuredBuffer<int2> AppendIndiceBuffer : register(u0);

RWStructuredBuffer<int2> IndiceBuffer : register(u1);

[numthreads(CORETHREADSWIDTH, CORETHREADSHEIGHT, 1)]
void main( uint3 DTid : SV_DispatchThreadID )
{


}