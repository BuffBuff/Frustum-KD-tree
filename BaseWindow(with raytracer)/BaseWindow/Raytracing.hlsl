#include "Collisions.fx"
#include "Light.fx"
#include "Debug.fx"

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

	float3 hit = (-1.0f, -1.0f, -1.0f);

	//int nodeIndex = 0;
	//int nextNode = 0;
	//int nodeStack[30];

	//int levelStart = 1;
	//int swapMask = 0;
	
	int node = 0;	
	int depth = 0;
	int levelIndex = 0;
	int childIndex = 0;
	int missedAllTriangles = 0;
	int lastVisitedNode = 0;
	int wasRightChildNode = 0;
	int nextArray[20];
	int readFrom = 0;
	nextArray[0] = 0;
	
	//super mega awesome iteration of doom and destruction!
	if (RayVSAABB(r, KDtree[0].aabb) == MAXDIST)
	{
		outColor = float4(1, 0, 1, 1);
	}
	else
	{
		int i;
		for (i = 0; i < 100; i++)
		{
			missedAllTriangles = 0;
			//lövnode?
			//ja-> gör träff beräkning
			//nej-> gå vidare
			if (KDtree[node].index != -1)
			{

				for (int i = KDtree[node].index; i < KDtree[node].nrOfTriangles + KDtree[node].index; i++)
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
						missedAllTriangles++;

					}
				}
				//outColor = float4(1, 1, 0, 1);
				
				//back up one more level and check a new node
				if (missedAllTriangles < 1)
				{
					//outColor = float4(0, 0, 1, 1);
					//break;
					int childNodeOffset = 1 - node % 2;
					levelIndex = levelIndex - childNodeOffset;
					levelIndex = levelIndex * 0.5f;
					depth--;
					lastVisitedNode = node;
					childIndex = node;
					wasRightChildNode = 0;
					if (childNodeOffset == 1)
					{
						wasRightChildNode = 1;
					}
					//Set to the parentnode
					node = ((1 << depth) - 1) + levelIndex;
				}
				//hit a triangle in the leafnode
				else
				{
					//outColor = float4(0, 0, 1, 1);
					break;
				}
			}
			else
			{
				if (wasRightChildNode == 1)
				{
					if (node == 0)
						break;
					int childNodeOffset = 1 - node % 2;
					levelIndex = levelIndex - childNodeOffset;
					levelIndex = levelIndex * 0.5f;
					depth--;
					lastVisitedNode = node;
					childIndex = node;
					wasRightChildNode = 0;
					if (childNodeOffset == 1)
					{
						wasRightChildNode = 1;
					}
					//Set to the parentnode
					node = ((1 << depth) - 1) + levelIndex;
				}
				else
				{
					//ta fram childIDs

					// childIndex = (currentDepth * 2) + (levelIndex * 2)

					//childIndex = (depth * 2) + (levelIndex * 2);
					childIndex = ((1 << depth + 1) - 1) + (levelIndex * 2);
					float left = RayVSAABB(r, KDtree[childIndex].aabb);

					float right = RayVSAABB(r, KDtree[childIndex + 1].aabb);

					if (left != MAXDIST && right != MAXDIST)
					{
						if (left > right)
						{
							nextArray[readFrom] = childIndex;
							//pilla med readFrom
						}
					}
					

					//vilket barn träffar vi?
					//vänster, höger eller båda
					//ja-> gå till vänster
					//sätt ny node
					levelIndex *= 2;

					if (left != MAXDIST && lastVisitedNode != childIndex)
					{
						
					}	
					//nej-> gå till den som vi träffade
					//sätt ny node
					else
					{
						childIndex++;
						levelIndex++;
					}

					node = childIndex;
					depth++;
					//outColor = float4(1, 1, 0, 1);

				}
			}
		}
		if (i == 100)
			hd.color = float4(0.5f, 1, 0, 1);
	}


	//////////////////////////////////
	///Light
	/////////////////////////////////
	/*
	//resetting for light and seting new variables
	Ray lightRay;
	hitData lightHit;

	lightHit.t = -1.0f;
	lightHit.pos = float4(0,0,0,0);
	lightHit.color = float4(0,0,0,0);
	lightHit.normal = float4(0,0,0,0);
	lightHit.ID = 0.f;
	lightHit.bufferpos = float2(0,0);

	nodeIndex = 0;
	nextNode = 0;
	hit = (-1.0f, -1.0f, -1.0f);

	// the output picture
	[unroll]for (int i = 0; i < NROFLIGHTS; i++)
	{
		float4 color = float4(0, 0, 0, 0);
		lightRay.origin = hd.pos;
		lightRay.dir = normalize(lightList[i].pos - hd.pos);
		float lightLength = length(lightList[i].pos.xyz - hd.pos.xyz);

		// ## MESH ## //
		while (nextNode > -1)
		{
			if (KDtree[nodeIndex].index == -1)
			{
				if (RayVSAABB(lightRay, KDtree[KDtree[nodeIndex].left_right_nodeID[0]].aabb) != MAXDIST)
				{
					nodeStack[nextNode] = KDtree[nodeIndex].left_right_nodeID[0];
					nextNode++;
				}																							// 380 fps kub

				if (RayVSAABB(lightRay, KDtree[KDtree[nodeIndex].left_right_nodeID[1]].aabb) != MAXDIST)
				{
					nodeStack[nextNode] = KDtree[nodeIndex].left_right_nodeID[1];
					nextNode++;
				}

			}
			else
			{
				// triangle intersect logic
				for (int i = KDtree[nodeIndex].index; i < KDtree[nodeIndex].nrOfTriangles + KDtree[nodeIndex].index; i++)
				{
					hit = RayVSTriangleMat(triangles[Indices[i]], lightRay, hd.t);
					if (hit.x > -1)
					{
						lightHit.t = hit.x;
					}
				}
			}

			nextNode--;
			nodeIndex = nodeStack[nextNode];

		}
		
		// ## SHADOWS ## //
		if (lightHit.t > EPSILON && lightLength > lightHit.t)
		{
			color = (float4(PointLightR(hd.pos, hd.normal, hd.color, lightList[i]), 0) * 0.5f);
		}
		else
		{
			color = float4(PointLightR(hd.pos, hd.normal, hd.color, lightList[i]), 0);
		}

		outColor += color;
	}
	*/
	outColor = float4( hd.color);
	//outColor = float4(1,0,0,1) * lol;
	//debug code
	if (lightSpheres > 0)
	{
		outColor += debugLightSpheres(r, hd.t);
	}

	output[threadID.xy] = saturate(outColor);
	//output[threadID.xy] = float4(1, 1, 0, 1);
}