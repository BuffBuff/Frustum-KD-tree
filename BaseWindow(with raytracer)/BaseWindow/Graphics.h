#pragma once
#include "stdafx.h"
#include "Camera.h"
#include "Mesh.h"
#include "WICTextureLoader.h"

extern ID3D11Device* g_Device;
extern ID3D11DeviceContext* g_DeviceContext;
extern IDXGISwapChain* g_SwapChain;

extern Camera* Cam;

class Graphics
{
public:
	Graphics();
	~Graphics();
	HRESULT Update(float _deltaTime);
	HRESULT Render(float _deltaTime);
	void release();


	//---------------------------------- temporary variables for testing
	Vertex wall[6];

	XMFLOAT4X4 view;
	XMFLOAT4X4 proj;


	//----------------------------------

private:

	void createBackBuffer();
	void createShader(std::string _shader, std::string _shaderModel);
	void createInputLayout(ID3DBlob *_vertexBlob, ID3D11InputLayout* _layout);
	void createSampler();
	void createBuffers();
	void createRasterState();
	void createViewport();
	void createBlendState();

	cbWorld cbWorld;
	ID3D11Buffer* g_cbWorld = NULL;
	ID3D11Buffer* g_vertexBuffer;

	ID3D11RenderTargetView*  g_backBuffer = NULL;
	ID3D11VertexShader* g_vertexShader = NULL;
	ID3D11InputLayout* g_vertexLayout = NULL;
	ID3D11GeometryShader* g_geometryShader = NULL;
	ID3D11InputLayout* g_geometryLayout = NULL;
	ID3D11PixelShader* g_pixelShader = NULL;
	ID3D11InputLayout* g_pixelLayout = NULL;
	ID3D11SamplerState *samLinear = NULL;
	D3D11_VIEWPORT viewport;
	ID3D11BlendState* g_blendState = NULL;



	ID3D11RasterizerState *rasterState = NULL;

	//MESH
	Mesh						m_mesh;
	ID3D11Buffer				*m_meshBuffer;
	ID3D11ShaderResourceView	*m_meshTexture;

};

