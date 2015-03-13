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

	int nodeIndex = 0;
	int nextNode = 0;
	int nodeStack[30];

	int levelStart = 1;
	int levelIndex = 0;
	int swapMask = 0;
	
	int depthIndex = 1;

	//new stackless traversing 
	while (levelStart >= 1)
	{
		int node = levelStart + levelIndex - 1 + swapMask - 2 * (levelIndex & swapMask);	//bitwise AND

		if (KDtree[node].index == -1)
		{
			//Leaf node found, DO SHIT!
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
				}
			}
		}
		else
		{
			//test aganist both childs
			int childIndex = (levelStart - 1) * 2 + levelIndex;
			float left = RayVSAABB(r, KDtree[childIndex].aabb);

			float right = RayVSAABB(r, KDtree[childIndex+1].aabb);
			
			//if any hit
			if (left != MAXDIST || right != MAXDIST)
			{
				levelStart = levelStart << 1;	//bitwise shift left
				levelIndex = levelIndex << 1;	//bitwise shift left
				swapMask = swapMask << 1;		//bitwise shift left


				//right child first
				if (right < left )
				{
					swapMask = swapMask | 1;		//bitwise OR
				}
				//reject one child
				if (right == MAXDIST && left != MAXDIST || left == MAXDIST && right != MAXDIST)
				{
					levelIndex = levelIndex + 1;
					swapMask = swapMask ^ 1;		//bitwise XOR
				}
				break;
			}
		}


		levelIndex = levelIndex + 1;

		///////////////experiment area/////////////////

		int up = 0;
		for (int i = 5; levelIndex / i >= 1; i *= 5)
		{
			up += levelIndex / i;
		}

		///////////////experiment area/////////////////
		
		//int up = ctz(levelIndex);		//up <- ctz(levelIndex)
		levelStart = levelStart >> up;	//bitwise shift right
		levelIndex = levelIndex >> up;	//bitwise shift right
		swapMask = swapMask >> up;		//bitwise shift right
	}



	/*
	while (nextNode > -1)
	{
		if (KDtree[nodeIndex].index == -1)
		{

			///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			if (RayVSAABB(r, KDtree[KDtree[nodeIndex].left_right_nodeID[0]].aabb) != MAXDIST)
			{
				nodeStack[nextNode] = KDtree[nodeIndex].left_right_nodeID[0];
				nextNode++;
			}																							// 380 fps kub

			if (RayVSAABB(r, KDtree[KDtree[nodeIndex].left_right_nodeID[1]].aabb) != MAXDIST)
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
				hit = RayVSTriangleMat(triangles[Indices[i]], r, hd.t);
				if (hit.x > -1)
				{

					hd.pos = r.origin + r.dir * hit.x;
					hd.normal = triangles[Indices[i]].normal;
					hd.color = MeshTexture[hit.yz*512.f] + triangles[Indices[i]].color;
					hd.ID = triangles[Indices[i]].ID;
					hd.t = hit.x;
					hd.bufferpos = threadID.xy;
				}
			}


		}
		
		nextNode--;
		nodeIndex = nodeStack[nextNode];

	}
	*/

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

	//debug code
	if (lightSpheres > 0)
	{
		outColor += debugLightSpheres(r, hd.t);
	}

	output[threadID.xy] = saturate(outColor);
	//output[threadID.xy] = float4(1, 1, 0, 1);
}