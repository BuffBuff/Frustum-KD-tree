#include "Object.h"


Object::Object()
{
	D3DXQuaternionIdentity(&Rotation);
	D3DXMatrixIdentity(&world);
	D3DXMatrixIdentity(&translation);
	tick = 0;
	
	rectangleSize[0] = 0.2f;//x
	rectangleSize[1] = 0.2f;//y
	rectangleSize[2] = 0.2f;//z
}


Object::~Object(void)
{
}

void Object::addData(Vertex iData)
{
	Data.push_back(iData);
}

void Object::lastFace()
{
	Data.push_back(Data.at(Data.size()-3));								
	Data.push_back(Data.at(Data.size()-2));
}

void Object::getData(std::vector<Vertex> *in)
{
	for(int i = 0;i < Data.size();i++)
	{
		in->push_back(Data.at(i));
	}
}

void Object::InitBuffers(char file1[256],char file2[256] )
{

	D3D11_BUFFER_DESC bd;

	bd.Usage = D3D11_USAGE_DYNAMIC;
	bd.ByteWidth = sizeof(Vertex) * Data.size();
	bd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
	bd.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
	bd.MiscFlags = 0;

	if( FAILED( g_Device->CreateBuffer( &bd, 0, &Buffer ) ) )
		MessageBox( 0, "Unable to create Vertex Buffer", "VB Error", 0 );

	D3DX11_IMAGE_LOAD_INFO loadInfo;
	ZeroMemory( &loadInfo, sizeof(D3DX11_IMAGE_LOAD_INFO) );
	loadInfo.BindFlags = D3D11_BIND_SHADER_RESOURCE;
	loadInfo.Format = DXGI_FORMAT_BC1_UNORM;
	D3DX11CreateShaderResourceViewFromFile( g_Device, file1, &loadInfo, NULL, &pObjectTexture[0], NULL);
	D3DX11CreateShaderResourceViewFromFile( g_Device, file2, &loadInfo, NULL, &pObjectTexture[1], NULL);

	D3D11_MAPPED_SUBRESOURCE updateData;
	ZeroMemory(&updateData, sizeof(updateData));

	int tempSize = Data.size();
	Vertex temp[3000];
	for (int i = 0; i < 3000; i++)
	{
		temp[i] = Data.at(i);
	}

	if (!FAILED(g_DeviceContext->Map(Buffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &updateData)))
		memcpy(updateData.pData, temp, sizeof(Vertex) * 3000);

	g_DeviceContext->Unmap(Buffer, 0);
}

int Object::getBufferSize()
{
	return Data.size();
}

bool Object::Update(float dt,float mx,float my,float mz)
{
	D3DXMatrixIdentity(&world);

	pos[0] += mx*dt;
	pos[1] += my*dt;
	pos[2] += mz*dt;

	D3DXMatrixTranslation(&translation,pos[0],pos[1],pos[2]);

	world = world *translation;
	return false;
}

void Object::setWorld()
{
	world = translation;
}

void Object::setData(float moveX,float moveY,float moveZ,float scale)
	{
		for(int i = 0;i < Data.size();i++)
		{
			Data.at(i).pos.x = Data.at(i).pos.x*scale;// + moveX*10;
			Data.at(i).pos.y = Data.at(i).pos.y*scale;// + moveY*10;
			Data.at(i).pos.z = Data.at(i).pos.z*scale;// + moveZ*10;
		}
		
		D3DXMatrixTranslation(&translation,moveX*10,moveY*10,moveZ*10);
		
		frameMove = D3DXVECTOR3(moveX*10,moveY*10,moveZ*10);
		rotX = (rand() % 100) ;
		rotY = (rand() % 100) ;
		rotZ = (rand() % 100) ;
		rotX /= 1000000;
		rotY /= 1000000;
		rotZ /= 1000000;
	}

void Object::setPos(float* in)
{
	this->pos = new float[3];
	this->pos[0] = in[0];
	this->pos[1] = in[1];
	this->pos[2] = in[2];
}