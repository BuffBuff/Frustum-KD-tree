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
	XMFLOAT4	pos0;
	XMFLOAT4	pos1;
	XMFLOAT4	pos2;
	XMFLOAT2	textureCoordinate0;
	XMFLOAT2	textureCoordinate1;
	XMFLOAT2	textureCoordinate2;
	int			ID;
	float		pad;
	XMFLOAT4	color;
	XMFLOAT4	normal;
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