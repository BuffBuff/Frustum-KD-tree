#include "Collisions.fx"
#include "Light.fx"
#include "Debug.fx"

RWTexture2D<float4> output : register(u0);

Texture2D MeshTexture : register(t0);
StructuredBuffer<TriangleMat> triangles : register(t1);

RWStructuredBuffer<NodePass2> KDtree : register(u2);
RWStructuredBuffer<int> Indices : register(u3);

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

		//Setting up for the traversal of the kd-tree
		int node = 0;
	int depth = 0;
	int levelIndex = 0;
	int childIndex = 0;
	int missedAllTriangles = 0;
	int2 nextArray[20];
	int readFrom = 0;
	nextArray[0][0] = 0;
	nextArray[0][1] = 0;

	//super mega awesome iteration of doom and destruction!
	if (RayVSAABB(r, KDtree[0].aabb) == MAXDIST)
	{
		//outColor = float4(1, 0, 1, 1);
	}
	else
	{
		int j;
		for (j = 0; j < 40; )
		{
			missedAllTriangles = 0;


			


			//if leafnode
			if (KDtree[node].index != -1)
			{
				//check the triangles in the leafnode
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

						//if (depth > 3)
						//{
						//	return;
						//}

					}
				}
				//if all the triangles where missed
				if (missedAllTriangles < 1)
				{
					node = nextArray[readFrom][0];
					depth = nextArray[readFrom][1];
					readFrom--;

					int onePowDepth = (1 << depth) - 1;
					levelIndex = node - onePowDepth;
				}
				//hit a triangle in the leafnode
				else
				{
					//if (node == 1)
					//	hd.color = float4(0, 0, 1, 1);

					break;
				}
			}
			//if not a leafnode
			//step in the kd-tree
			else
			{
				//calculate the childIDs
				//(1^(depth+1)-1)+(levelIndex*2)					

				childIndex = ((1 << depth + 1) - 1) + (levelIndex * 2);
				float left = RayVSAABB(r, KDtree[childIndex].aabb);

				float right = RayVSAABB(r, KDtree[childIndex + 1].aabb);

				//modify the levelIndex
				levelIndex *= 2;

				//if both children are hit
				if (left != MAXDIST && right != MAXDIST)
				{
					//right child hit first
					if (left > right)
					{
						//add left node first
						readFrom++;
						nextArray[readFrom][0] = childIndex;
						nextArray[readFrom][1] = depth + 1;
						//add right node
						readFrom++;
						nextArray[readFrom][0] = childIndex + 1;
						nextArray[readFrom][1] = depth + 1;
						levelIndex++;
					}
					//left child hit first
					else
					{
						//add right node first
						readFrom++;
						nextArray[readFrom][0] = childIndex + 1;
						nextArray[readFrom][1] = depth + 1;
						//add left node
						readFrom++;
						nextArray[readFrom][0] = childIndex;
						nextArray[readFrom][1] = depth + 1;
					}
				}
				//only one child hit
				else
				{
					readFrom++;
					//left child
					if (left != MAXDIST)
					{
						nextArray[readFrom][0] = childIndex;
						nextArray[readFrom][1] = depth + 1;
					}
					//right child
					else
					{
						nextArray[readFrom][0] = childIndex + 1;
						nextArray[readFrom][1] = depth + 1;
						levelIndex++;
					}
				}
				//finish up for a new round in the loop

			/*	
				if (nextArray[readFrom][0] == 1)
				{
					readFrom--;
				}*/

				node = nextArray[readFrom][0];
				readFrom--;
				depth++;
				//hd.color = float4(1, 1, 0, 1);				
			}

			//check if going to read outside the array
			if (readFrom < 0)
			{
				break;
			}

		}
		//debug check if the loop got to a max
		//instead of crashing, add a color on the broken part
		if (j == 40)
			hd.color = float4(0.5f, 1, 0, 1);
	}


	//////////////////////////////////
	///Light
	/////////////////////////////////

	//resetting for light and setting new variables
	Ray lightRay;
	hitData lightHitData;

	lightHitData.t = -1.0f;
	lightHitData.pos = float4(0, 0, 0, 0);
	lightHitData.color = float4(0, 0, 0, 0);
	lightHitData.normal = float4(0, 0, 0, 0);
	lightHitData.ID = 0.f;
	lightHitData.bufferpos = float2(0, 0);

	node = 0;
	depth = 0;
	levelIndex = 0;
	childIndex = 0;
	missedAllTriangles = 0;
	readFrom = 0;
	nextArray[0][0] = 0;
	nextArray[0][1] = 0;

	hit = (-1.0f, -1.0f, -1.0f);

	for (int i = 0; i < NROFLIGHTS; i++)
	{

		float4 color = float4(0, 0, 0, 0);
		lightRay.origin = hd.pos;
		lightRay.dir = normalize(lightList[i].pos - hd.pos);
		float lightLength = length(lightList[i].pos.xyz - hd.pos.xyz);

		// the output picture
		if (RayVSAABB(lightRay, KDtree[0].aabb) == MAXDIST)
		{
			//outColor = float4(1, 0, 1, 1);
		}
		else
		{
			int j;
			for (j = 0; j < 40;)
			{
				missedAllTriangles = 0;

				//if leafnode
				if (KDtree[node].index != -1)
				{
					//check the triangles in the leafnode
					for (int i = KDtree[node].index; i < KDtree[node].nrOfTriangles + KDtree[node].index; i++)
					{
						hit = RayVSTriangleMat(triangles[Indices[i]], lightRay, lightHitData.t);
						if (hit.x > -1)
						{

							lightHitData.pos = lightRay.origin + lightRay.dir * hit.x;
							lightHitData.normal = triangles[Indices[i]].normal;
							lightHitData.color = MeshTexture[hit.yz*512.f] + triangles[Indices[i]].color;
							lightHitData.ID = triangles[Indices[i]].ID;
							lightHitData.t = hit.x;
							lightHitData.bufferpos = threadID.xy;
							missedAllTriangles++;

						}
					}
					//if all the triangles where missed
					if (missedAllTriangles < 1)
					{
						node = nextArray[readFrom][0];
						depth = nextArray[readFrom][1];
						readFrom--;

						int onePowDepth = (1 << depth) - 1;
						levelIndex = node - onePowDepth;
					}
					//hit a triangle in the leafnode
					else
					{
						//hd.color = float4(0, 0, 1, 1);
						break;
					}
				}
				//if not a leafnode
				//step in the kd-tree
				else
				{
					//calculate the childIDs
					//(1^(depth+1)-1)+(levelIndex*2)					

					childIndex = ((1 << depth + 1) - 1) + (levelIndex * 2);
					float left = RayVSAABB(lightRay, KDtree[childIndex].aabb);

					float right = RayVSAABB(lightRay, KDtree[childIndex + 1].aabb);

					//modify the levelIndex
					levelIndex *= 2;

					//if both children are hit
					if (left != MAXDIST && right != MAXDIST)
					{
						//right child hit first
						if (left > right)
						{
							//add left node first
							readFrom++;
							nextArray[readFrom][0] = childIndex;
							nextArray[readFrom][1] = depth + 1;
							//add right node
							readFrom++;
							nextArray[readFrom][0] = childIndex + 1;
							nextArray[readFrom][1] = depth + 1;
							levelIndex++;
						}
						//left child hit first
						else
						{
							//add right node first
							readFrom++;
							nextArray[readFrom][0] = childIndex + 1;
							nextArray[readFrom][1] = depth + 1;
							//add left node
							readFrom++;
							nextArray[readFrom][0] = childIndex;
							nextArray[readFrom][1] = depth + 1;
						}
					}
					//only one child hit
					else
					{
						readFrom++;
						//left child
						if (left != MAXDIST)
						{
							nextArray[readFrom][0] = childIndex;
							nextArray[readFrom][1] = depth + 1;
						}
						//right child
						else
						{
							nextArray[readFrom][0] = childIndex + 1;
							nextArray[readFrom][1] = depth + 1;
							levelIndex++;
						}
					}

					

					//finish up for a new round in the loop
					node = nextArray[readFrom][0];
					readFrom--;
					depth++;
					//hd.color = float4(1, 1, 0, 1);				
				}

				//check if going to read outside the array
				if (readFrom < 0)
				{
					break;
				}

			}
			//debug check if the loop got to a max
			//instead of crashing, add a color on the broken part
			if (j == 40)
				hd.color = float4(0.5f, 1, 0, 1);
		}

		// ## SHADOWS ## //
		if (lightHitData.t > EPSILON && lightLength > lightHitData.t)
		{
			color = (float4(PointLightR(hd.pos, hd.normal, hd.color, lightList[i]), 0) * 0.5f);
		}
		else
		{
			color = float4(PointLightR(hd.pos, hd.normal, hd.color, lightList[i]), 0);
		}

		outColor += color;
	}


	//outColor = float4( hd.color);

	//debug code
	if (lightSpheres > 0)
	{
		outColor += debugLightSpheres(r, hd.t);
	}

	output[threadID.xy] = saturate(outColor);
}