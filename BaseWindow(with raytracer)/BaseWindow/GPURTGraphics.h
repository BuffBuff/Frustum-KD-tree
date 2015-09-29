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

extern ID3D11Device* g_Device;
extern ID3D11DeviceContext* g_DeviceContext;
extern IDXGISwapChain* g_SwapChain;

extern Camera* Cam;

class GPURTGraphics
{
public:
	GPURTGraphics(HWND* _hwnd);
	~GPURTGraphics();

	void Update(float _dt);
	void Render(float _dt);
	void release();
	void updateTogglecb(int _lightSpheres, int _placeHolder1, int _placeHolder2);

	void UpdateCamera(float _dt);

private:
	//Converter (sting to wstring)
	std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;

	void createCBuffers();
	void createTriangleTexture();
	void createNodeBuffer(Node* _rootNode);
	void createLightBuffer();
	void createKdTree(Mesh *_mesh);
	void createSwapStructures();
	void fillMesh(std::vector<tinyobj::shape_t>* _shapes, std::vector<tinyobj::material_t>* _materials, Mesh* _mesh);

	ComputeWrap *computeWrap;

	ComputeShader *raytracer = NULL;
	ComputeShader *createKDtree = NULL;
	ComputeShader *createKDtreeAppend = NULL;

	ComputeShader *sortListPass = NULL;

	ComputeShader *splitCalcKDtree = NULL;
	ComputeShader *moveKDtree = NULL;
	ComputeShader *prepKDtree = NULL;

	ComputeShader *createAABBs = NULL;

	ComputeBuffer *m_aabbBuffer = NULL; // buffern för aabbs för alla trianglar

	ID3D11Buffer *g_cBuffer;
	cBuffer cb;

	ID3D11UnorderedAccessView *backbuffer;

	//MESH
	Mesh						m_mesh;
	ComputeBuffer				*m_meshBuffer = NULL;
	ID3D11ShaderResourceView	*m_meshTexture = NULL;
	
	//blululululu
	ComputeBuffer				*m_NodeBuffer = NULL;
	ComputeBuffer				*m_Indices = NULL;
	ComputeBuffer				*m_SwapStructure[2];
	ComputeBuffer				*m_SwapSize = NULL;
	ComputeBuffer				*m_KDTreeBuffer = NULL;
	ComputeBuffer				*m_indexingCountBuffer = NULL;
	ComputeBuffer				*m_mutex = NULL;

	//in
	ComputeBuffer				*m_AppendIndiceBuffer = NULL;
	//ut
	ComputeBuffer				*m_IndiceBuffer = NULL;

	Node						m_rootNode;
	
	//HWND
	HWND*						m_Hwnd = NULL;

	//Timers
	float						m_time;
	float						m_fps;

	//Light
	ID3D11Buffer				*m_lightcBuffer;
	cLightBuffer				lightcb;

	//Light sphere
	ID3D11Buffer				*m_spherecBuffer;
	cSphereBuffer				spherecb;

	ID3D11Buffer				*m_depthcBuffer;
	depthcBuffer				depthcb;


	D3D11Timer					*g_timer = NULL;

};

