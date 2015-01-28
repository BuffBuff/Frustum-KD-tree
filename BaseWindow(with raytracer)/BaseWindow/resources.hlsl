#define PI 3.14159265f

//SamplerState samLinear	: register(s1);

cbuffer cbWorld			: register(b0)
{
	matrix	world;			//world matrix
	matrix	view;
	matrix	projection;
};

//cbuffer cbEveryFrame	: register(b3)
//{
//	float	timeStep;
//	float	gameTime;
//};