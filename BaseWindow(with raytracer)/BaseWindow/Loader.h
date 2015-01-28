#pragma once
#include "stdafx.h"
#include <sstream>
#include <fstream>
#include "Object.h"

class Loader
{
public:
	Loader(void);
	~Loader(void);
	void LoadObject(char file[256],float mx,float mz,float my,float scale,Object* objekt,float invertX,float invertY,float invertZ);
};

