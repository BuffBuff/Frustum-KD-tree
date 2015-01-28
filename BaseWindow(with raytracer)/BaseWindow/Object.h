#pragma once
#include "stdafx.h"
#include "Camera.h"


extern Camera* Cam;

extern ID3D11Device* g_Device;
extern ID3D11DeviceContext* g_DeviceContext;

static ID3D11ShaderResourceView*	object_mfxDiffuseMapVar;

class Object
{
private:

	ID3D11ShaderResourceView*	pObjectTexture[2];



	Vertex* fData;
	float rotX,rotY,rotZ;
	float* pos;
	VECTOR3 frameMove;
	std::vector<Vertex> Data;
	ID3D11Buffer* Buffer;
	ID3D11ShaderResourceView* Texture;
	MATRIX4X4 world;
	MATRIX4X4 translation;
	//D3DXQUATERNION Rotation;
	
	float rectangleSize[3]; //( x, y, z)

	
	int tick;
public:
	Object();
	~Object(void);
	//Lägger till ett nytt värde i slutet på data
	void addData(Vertex iData);
	//Lägger till den sista vertex facet till Data
	void lastFace();
	//Returnerar Data
	void getData(std::vector<Vertex> *in);
	//Inverts the objects vector positions
	void InvertObject();
	//Initsierar Buffers
	void InitBuffers(char file1[256],char file2[256]  );
	//Returnerar buffer storleken storleken på Data antal vertexes
	int getBufferSize();
	//Uppdate returns true if object is to be destroyed
	bool Update(float dt,float mx,float my,float mz);
	//Sätter World matrisen
	void setWorld();
	//Flyttar roterar och skalar objektet
	void setData(float moveX,float moveY,float moveZ,float scale);
	//Sets the objects center position
	void setPos(float* in);
	//Returns the position of the object
	float* getPos(){return pos;};
	//returns the boundingbox
	float* getRectangle(){return rectangleSize;};
	//returns the buffer
	ID3D11Buffer** getBuffer(){ return &Buffer; };

};

