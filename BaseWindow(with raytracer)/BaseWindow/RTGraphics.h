#pragma once
#include "stdafx.h"
#include "Camera.h"
#include "Mesh.h"
#include "ComputeHelp.h"

extern ID3D11Device* g_Device;
extern ID3D11DeviceContext* g_DeviceContext;
extern IDXGISwapChain* g_SwapChain;

extern Camera* Cam;

class RTGraphics
{
public:
	RTGraphics();
	~RTGraphics();

	void Update(float _dt);
	void Render(float _dt);

private:

	void createCBuffers();
	void createTriangleTexture();
	void createKdTree(Mesh *_mesh);
	void createKDNodeSplit(std::vector<AABB>* _aabbList, Node _node, int _split);

	ComputeWrap *computeWrap;

	ComputeShader *raytracer = NULL;

	ComputeBuffer *triangleBuffer = NULL;

	ID3D11Buffer *g_cBuffer;
	cBuffer cb;

	ID3D11UnorderedAccessView *backbuffer;

	//MESH
	Mesh						m_mesh;
	ComputeBuffer				*m_meshBuffer;
	ID3D11ShaderResourceView	*m_meshTexture;
	Node						m_rootNode;
};

