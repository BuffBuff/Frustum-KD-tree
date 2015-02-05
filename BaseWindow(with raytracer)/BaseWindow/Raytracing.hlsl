#include "Collisions.fx"

RWTexture2D<float4> output : register(u0);

Texture2D MeshTexture : register(t0);
StructuredBuffer<TriangleMat> triangles : register(t1);

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

	// variable for testing the hit
	float3 hit = (-1.0f, -1.0f, -1.0f);

	for (int i = 0; i < nrOfTriangles; i++)
	{
		hit = RayVSTriangleMat(triangles[i], r, hd.t);
		if (hit.x > -1)
		{
		outColor -= float4(1, 0, 0, 0);
			hd.pos = r.origin + r.dir * hit.x;
			hd.normal = triangles[i].normal;
			hd.color = MeshTexture[hit.yz*512.f]; //triangles[i].color;
			hd.ID = triangles[i].ID;
			hd.t = hit.x;
			hd.bufferpos = threadID.xy;
			outColor = hd.color;
		}
	}

	//outColor = triangles[0].color;

	//  basic triangle collision
	/*for (int i = 0; i < NRTRIANGLES; i++)		
	{
		float3 nopp = tri[i].pad;
			hit = RayVSTriangle(tri[i], r, hd.t);

		if (hit > -1)
		{
			hd.pos = r.origin + r.dir * hit;
			hd.normal = tri[i].normal;
			hd.color = tri[i].color;
			hd.ID = tri[i].ID;
			hd.t = hit;
			hd.bufferpos = threadID.xy;

		}
	}*/

	// the output picture
	output[threadID.xy] = outColor;
	//output[threadID.xy] = float4(1, 1, 0, 1);
}