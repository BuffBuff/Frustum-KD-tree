#pragma once
#include "stdafx.h"
#include "Camera.h"
#include "Mesh.h"
#include "ComputeHelp.h"
#include <locale>
#include <codecvt>
#include <string>
#include "D3D11Timer.h"
#include "tinyobjloader\tiny_obj_loader.h"
#include <fstream>

extern ID3D11Device* g_Device;
extern ID3D11DeviceContext* g_DeviceContext;
extern IDXGISwapChain* g_SwapChain;

extern Camera* Cam;

using namespace DirectX;

class RTGraphics
{
public:
	RTGraphics(HWND* _hwnd);
	~RTGraphics();

	void Update(float _dt);
	void Render(float _dt);
	void release();

	void updateTogglecb(int _lightSpheres, int _placeHolder1, int _placeHolder2);

private:
	//Converter (sting to wstring)
	std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;

	void createCBuffers();
	void createTriangleTexture();
	void createNodeBuffer(Node* _rootNode);
	void createLightBuffer();
	void createKdTree(Mesh *_mesh);
	void fillMesh(std::vector<tinyobj::shape_t>* _shapes, std::vector<tinyobj::material_t>* _materials, Mesh* _mesh);
	void createKDNodeSplit(std::vector<AABB>* _aabbList, Node* _node, int _depth);

	void splitAABBList(Node* _node, std::vector<AABB>* _AABBList, int splitAxis, int _depth);
	int nodeAABBSplit(Node* _node);
	void optimFillKDBuffers(Node* _rootNode, std::vector<int> *_indiceList);


	int nrOfNodes = 0;

	NodePass2 initData[MAXSIZE];

	ComputeWrap *computeWrap;

	ComputeShader *raytracer = NULL;
	
	ID3D11Buffer *g_cBuffer;
	cBuffer cb;

	ID3D11UnorderedAccessView *backbuffer;

	//MESH
	Mesh						m_mesh;
	ComputeBuffer				*m_meshBuffer;
	ID3D11ShaderResourceView	*m_meshTexture;
	
	//tiny mesh
//	std::vector<tinyobj::shape_t> shapes;
//	std::vector<tinyobj::material_t> materials;

	//blululululu
	ComputeBuffer				*m_NodeBuffer;
	ComputeBuffer				*m_Indices;
	Node						m_rootNode;
	
	//HWND
	HWND						*m_Hwnd;

	//Timers
	float						m_time;
	float						m_fps;

	float						m_gentime1;
	float						m_gentime2;
	float						m_gentime3;
	float						m_gentime4;



	float						m_kdGenTime;
	float						m_gpuTextureGenTime;
	D3D11Timer					*g_timer = NULL;



	//constant buffers
	//Light
	ID3D11Buffer				*m_lightcBuffer;
	cLightBuffer				lightcb;

	//Light sphere
	ID3D11Buffer				*m_spherecBuffer;
	cSphereBuffer				spherecb;

	//Toggles
	ID3D11Buffer				*m_togglecBuffer;
	cToggles					togglescb;
};

