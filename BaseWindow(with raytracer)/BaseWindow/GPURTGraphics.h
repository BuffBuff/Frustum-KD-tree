#pragma once
#include "stdafx.h"
#include "Camera.h"
#include "Mesh.h"
#include "ComputeHelp.h"
#include <locale>
#include <codecvt>
#include <string>
#include "D3D11Timer.h"

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

private:
	//Converter (sting to wstring)
	std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;

	void createCBuffers();
	void createTriangleTexture();
	void createNodeBuffer(Node* _rootNode);
	void createLightBuffer();
	void createKdTree(Mesh *_mesh);

	ComputeWrap *computeWrap;

	ComputeShader *raytracer = NULL;
	ComputeShader *createKDtree = NULL;

	ComputeBuffer *m_aabbBuffer = NULL; // buffern för aabbs för alla trianglar

	ID3D11Buffer *g_cBuffer;
	cBuffer cb;

	ID3D11UnorderedAccessView *backbuffer;

	//MESH
	Mesh						m_mesh;
	ComputeBuffer				*m_meshBuffer;
	ID3D11ShaderResourceView	*m_meshTexture;
	
	//blululululu
	ComputeBuffer				*m_NodeBuffer;
	ComputeBuffer				*m_Indices;

	Node						m_rootNode;
	
	//HWND
	HWND						*m_Hwnd;

	//Timers
	float						m_time;
	float						m_fps;

	//Light
	ID3D11Buffer				*m_lightcBuffer;
	cLightBuffer				lightcb;

	D3D11Timer					*g_timer = NULL;

};

