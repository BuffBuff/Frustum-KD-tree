#ifndef _STRUCTS_FX_
#define _STRUCTS_FX_


struct Sphere
{
	float4 origin;
	float4 color;
	float radie;
	float3 pad;
};

struct Ray
{
	float4 origin;
	float4 dir;
};

struct hitData
{
	float4	color; // color
	float4  normal;	// normal
	float4  pos;	// position
	float	t;		// inpact time
	float	ID;		// triangle id
	float2  bufferpos; // ?
};

struct Light
{
	float4 pos;
	float4 dir;
	float4 ambient;
	float4 diffuse;
	float4 spec;
	float4 att;
	float  spotPower;
	float  range;
	float2 pad;
};

struct TriangleMat
{
	float4	pos0;
	float4	pos1;
	float4	pos2;
	float2	tex0;
	float2	tex1;
	float2	tex2;
	int		ID;
	float	pad;
	float4	color;
	float4	normal;
};

struct ObjTriangle
{
	float4 pos[3];
	float4 normal;
	float2 texCx;
	float2 texCy;
	float2 texCz;
	int ID;
	float pad;
};



#endif