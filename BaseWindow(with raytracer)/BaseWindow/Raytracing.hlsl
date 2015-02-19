#include "Collisions.fx"

RWTexture2D<float4> output : register(u0);

Texture2D MeshTexture : register(t0);
StructuredBuffer<TriangleMat> triangles : register(t1);

StructuredBuffer<NodePass2> KDtree : register(t2);
StructuredBuffer<int> Indices : register(t3);

[numthreads(CORETHREADSWIDTH, CORETHREADSHEIGHT, 1)]
void main(uint3 threadID : SV_DispatchThreadID)
{
	// initiating the output color for the pixel computed
	float4 outColor = float4(0, 0, 0, 1);
	
	// index of the thread in 1D buffers
	int index = threadID.x + threadID.y * HEIGHT;

	// init hitData
	hitData hd;
	hd.t = -1;
	hd.color = outColor;
	hd.pos = float4(0, 0, 0, 0);
	hd.normal = float4(0, 0, 0, 0);
	hd.bufferpos = float2(0, 0);

	// xy dir of the primary ray
	float norm_X, norm_Y;
	norm_X = ((threadID.x / WIDTH) * 2) - 1.0f;
	norm_Y = ((1.0f - (threadID.y / HEIGHT)) * 2) - 1.0f;

	// init primary ray
	Ray r;
	float4 rayDir = float4(norm_X, norm_Y, 1, 1);
	rayDir = mul(rayDir, IP);
	rayDir = rayDir / rayDir.w;
	rayDir = mul(rayDir, IV);
	rayDir = rayDir - cameraPos;
	rayDir = normalize(rayDir);
	r.origin = cameraPos;
	r.dir = rayDir;

	int nodeIndex = 0;

	int nextNode = -1;
	int nodeStack[30];
	float3 hit = (-1.0f, -1.0f, -1.0f);


	while (true)
	{
		if (KDtree[nodeIndex].index == -1)
		{

			if (RayVSAABB(r, KDtree[KDtree[nodeIndex].left_right_nodeID[0]].aabb) != MAXDIST)
			{
				nextNode++;
				nodeStack[nextNode] = KDtree[nodeIndex].left_right_nodeID[0];

			}

			if (RayVSAABB(r, KDtree[KDtree[nodeIndex].left_right_nodeID[1]].aabb) != MAXDIST)
			{
				nextNode++;
				nodeStack[nextNode] = KDtree[nodeIndex].left_right_nodeID[1];

			}

		}
		else
		{
			// triangle intersect logic
			for (int i = KDtree[nodeIndex].index; i < KDtree[nodeIndex].nrOfTriangles + KDtree[nodeIndex].index; i++)
			{
				hit = RayVSTriangleMat(triangles[Indices[i]], r, hd.t);
				if (hit.x > -1)
				{

					hd.pos = r.origin + r.dir * hit.x;
					hd.normal = triangles[Indices[i]].normal;
					hd.color = MeshTexture[hit.yz*512.f] + triangles[Indices[i]].color;
					hd.ID = triangles[Indices[i]].ID;
					hd.t = hit.x;
					hd.bufferpos = threadID.xy;
					outColor = MeshTexture[hit.yz*512.f] + triangles[Indices[i]].color;
				}
			}

			outColor.x = 1;

		}

		if (nextNode > -1)
		{
			nodeIndex = nodeStack[nextNode];
			nextNode--;
			//outColor.y = 1;

		}
		else
		{
			break;
		}

	}

	// variable for testing the hit

	//for (int i = KDtree[nodeIndex].index; i < KDtree[nodeIndex].nrOfTriangles + KDtree[nodeIndex].index; i++)
	//{
	//	hit = RayVSTriangleMat(triangles[Indices[i]], r, hd.t);
	//	if (hit.x > -1)
	//	{

	//		hd.pos = r.origin + r.dir * hit.x;
	//		hd.normal = triangles[Indices[i]].normal;
	//		hd.color = MeshTexture[hit.yz*512.f] + triangles[Indices[i]].color;
	//		hd.ID = triangles[Indices[i]].ID;
	//		hd.t = hit.x;
	//		hd.bufferpos = threadID.xy;
	//		outColor = MeshTexture[hit.yz*512.f] + triangles[Indices[i]].color;
	//	}
	//}
	
	/*int testIndex = KDtree[nodeIndex].left_right_nodeID[0];

	if (RayVSAABB(r, KDtree[testIndex].aabb) != MAXDIST)
	{
		outColor.x += 1;
	}*/
	

	// the output picture
	output[threadID.xy] = outColor;
	//output[threadID.xy] = float4(1, 1, 0, 1);
}