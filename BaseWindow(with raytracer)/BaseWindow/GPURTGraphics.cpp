#include "GPURTGraphics.h"


GPURTGraphics::GPURTGraphics(HWND* _hwnd)
: m_mesh(Mesh()),
m_meshTexture(nullptr),
m_time(0.f),
m_fps(0.f)
{
	HRESULT hr = S_OK;
	g_timer = new D3D11Timer(g_Device, g_DeviceContext);

	m_Hwnd = _hwnd;
	m_SwapStructure[0] = NULL;
	m_SwapStructure[1] = NULL;

	computeWrap = new ComputeWrap(g_Device,g_DeviceContext);

	raytracer = computeWrap->CreateComputeShader("Raytracing");

	createKDtree = computeWrap->CreateComputeShader("createKDtree");

	createAABBs = computeWrap->CreateComputeShader("createAABBs");

	ID3D11Texture2D* pBackBuffer;
	hr = g_SwapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (LPVOID*)&pBackBuffer);
	if (FAILED(hr))
		MessageBox(NULL, "failed getting the backbuffer", "RTRenderDX11 Error", S_OK);

	// create shader unordered access view on back buffer for compute shader to write into texture
	hr = g_Device->CreateUnorderedAccessView(pBackBuffer, NULL, &backbuffer);

	//creating constant buffers
	createCBuffers();

	//creating triangle texture
	createTriangleTexture();

	//creating node buffer
	createNodeBuffer(&m_rootNode);

	//creating swap buffer
	createSwapStructures();

	//create lights
	createLightBuffer();
}

void GPURTGraphics::createCBuffers()
{
	HRESULT hr = S_OK;

	D3D11_BUFFER_DESC cbDesc;
	cbDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	cbDesc.Usage = D3D11_USAGE_DEFAULT;
	// CPU writable, should be updated per frame
	cbDesc.CPUAccessFlags = 0;
	cbDesc.MiscFlags = 0;

	if (sizeof(cBuffer) % 16 > 0)
	{
		cbDesc.ByteWidth = (int)((sizeof(cBuffer) / 16) + 1) * 16;
	}
	else
	{
		cbDesc.ByteWidth = sizeof(cBuffer);
	}

	hr = g_Device->CreateBuffer(&cbDesc, NULL, &g_cBuffer);
	if (FAILED(hr))
	{
		MessageBox(NULL, "Failed Making Constant Buffer cBuffer", "Create Buffer", MB_OK);
	}
	g_DeviceContext->CSSetConstantBuffers(0, 1, &g_cBuffer);

	if (sizeof(cLightBuffer) % 16 > 0)
	{
		cbDesc.ByteWidth = (int)((sizeof(cLightBuffer) / 16) + 1) * 16;
	}
	else
	{
		cbDesc.ByteWidth = sizeof(cLightBuffer);
	}

	hr = g_Device->CreateBuffer(&cbDesc, NULL, &m_lightcBuffer);
	if (FAILED(hr))
	{
		MessageBox(NULL, "Failed Making Constant Buffer lightcBuffer", "Create Buffer", MB_OK);
	}
	g_DeviceContext->CSSetConstantBuffers(1, 1, &m_lightcBuffer);

}

void GPURTGraphics::createTriangleTexture()
{
	///////////////////////////////////////////////////////////////////////////////////////////
	//Mesh
	///////////////////////////////////////////////////////////////////////////////////////////

	//Load OBJ-file
	m_mesh.loadObj("Meshi/kub.obj");
	m_mesh.setColor(XMFLOAT4(1,0,0,1));
	m_mesh.scaleMesh(XMFLOAT3(10,10,10));
	//m_mesh.rotateMesh(XMFLOAT3(PI*0.2f,PI*0.5f,PI));

	createKdTree(&m_mesh);

	m_meshBuffer = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
											 sizeof(TriangleMat),
											 m_mesh.getNrOfFaces(),
											 true,
											 false,
											 m_mesh.getTriangles(),
											 false,
											 "Structured Buffer: Mesh Texture");


	m_aabbBuffer = computeWrap->CreateBuffer(	STRUCTURED_BUFFER,
												sizeof(AABB),
												m_mesh.getNrOfFaces(),
												false,
												true,
												NULL,
												false,
												"Structured Buffer: Mesh Texture");
	//from wchat_t to string
	//std::string narrow = converter.to_bytes(wide_utf16_source_string);
	//from string to wchar_t
	std::wstring meshTextureWstring = converter.from_bytes(m_mesh.getTextureString());


	//TEXTURE STUFF
	CreateWICTextureFromFile(g_Device, 
							 g_DeviceContext,
							 meshTextureWstring.c_str(),
							 NULL, 
							 &m_meshTexture);

}

void GPURTGraphics::createNodeBuffer(Node* _rootNode)
{
	std::vector<NodePass2> *initdata = new std::vector<NodePass2>();
	std::vector<int> *indiceList = new std::vector<int>();


	NodePass2 node;
	node.aabb = _rootNode->aabb;
	node.index = -1;
	node.nrOfTriangles = 0;

	initdata->push_back(node);

	//fillKDBuffers(_rootNode, initdata, indiceList, 0);


	m_NodeBuffer = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
											 sizeof(NodePass2),
											 initdata->size(),
											 true,
											 false,
											 initdata->data(),
											 false,
											 "Structed Buffer: Node Buffer");

	m_Indices = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
											 sizeof(int),
											 indiceList->size(),
											 true,
											 false,
											 indiceList->data(),
											 false,
											 "Structed Buffer: Indice Buffer");

}

void GPURTGraphics::createLightBuffer()
{

	int rangeModifier = 15;
	float lightRange = 30.f;
	float ambientMod = 0.25f;
	float diffuseMod = 0.55f;
	std::srand(10);
	for (int i = 0; i < NROFLIGHTS; i++)
	{
		float rx = ((float)(std::rand() % rangeModifier)) - rangeModifier / 2;
		float ry = ((float)(std::rand() % rangeModifier)) - rangeModifier / 2;
		float rz = ((float)(std::rand() % rangeModifier)) - rangeModifier / 2;
		lightcb.lightList[i].pos = XMFLOAT4(rx, ry, rz, 1.f);
		lightcb.lightList[i].ambient = XMFLOAT4(ambientMod, ambientMod, ambientMod, 1.f);
		lightcb.lightList[i].diffuse = XMFLOAT4(diffuseMod, diffuseMod, diffuseMod, 1.f);
		lightcb.lightList[i].range = lightRange;
		lightcb.lightList[i].pad = XMFLOAT3(0.f, 0.f, 0.f);
	}
}

void GPURTGraphics::createSwapStructures()
{
	m_SwapStructure[0] = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
		sizeof(int)*4,
		3000000,
		false,
		true,
		NULL,
		false,
		"Structured Buffer: Swap Structure");

	m_SwapStructure[1] = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
		sizeof(int)*4,
		3000000,
		false,
		true,
		NULL,
		false,
		"Structured Buffer: Swap Structure");

	m_SwapSize = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
		sizeof(int)*2,
		3000000,
		false,
		true,
		NULL,
		false,
		"Structured Buffer: Swap size Structure");

	m_IndiceBuffer = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
		sizeof(int),
		3000000,
		false,
		true,
		NULL,
		false,
		"Structured Buffer: Swap size Structure");

	m_KDTreeBuffer = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
		sizeof(NodePass2),
		3000000,
		false,
		true,
		NULL,
		false,
		"Structured Buffer: Swap size Structure");

}

GPURTGraphics::~GPURTGraphics()
{
}

void GPURTGraphics::Update(float _dt)
{
	// updating the constant buffer holding the camera transforms
	XMFLOAT4X4 temp, viewInv, projInv;
	XMFLOAT3 tempp = Cam->getCameraPosition(); // w ska va 1
	XMStoreFloat4x4(&temp, XMMatrixIdentity());

	XMStoreFloat4x4(&temp, XMMatrixTranslation(tempp.x,tempp.y,tempp.z));

	XMStoreFloat4x4(&temp, XMMatrixTranspose(XMLoadFloat4x4(&temp)));

	XMStoreFloat4x4(&viewInv, XMMatrixInverse(&XMMatrixDeterminant(
		XMLoadFloat4x4(&Cam->getViewMatrix())), XMLoadFloat4x4(&Cam->getViewMatrix())));

	XMStoreFloat4x4(&projInv, XMMatrixInverse(&XMMatrixDeterminant(
		XMLoadFloat4x4(&Cam->getProjectionMatrix())), XMLoadFloat4x4(&Cam->getProjectionMatrix())));


	cb.IV = viewInv;
	cb.IP = projInv;
	cb.cameraPos = XMFLOAT4(tempp.x, tempp.y, tempp.z, 1);
	cb.nrOfTriangles = m_mesh.getNrOfFaces();
	g_DeviceContext->UpdateSubresource(g_cBuffer, 0, NULL, &cb, 0, 0);

	g_DeviceContext->UpdateSubresource(m_lightcBuffer, 0, NULL, &lightcb, 0, 0);

	m_time += _dt;
	static float frameCnt = 0;
	static float t_base = 0.f;
	frameCnt++;

	if (m_time - t_base >= 1.f)
	{
		frameCnt /= 1;
		m_fps = (float)frameCnt;
		frameCnt = 0;
		t_base += 1.f;
	}


	// fill the aabb buffer


	ID3D11ShaderResourceView *srv[] = {  m_meshBuffer->GetResourceView()};
	g_DeviceContext->CSSetShaderResources(1, 1, srv);

	

	ID3D11UnorderedAccessView* uav1[] = { m_aabbBuffer->GetUnorderedAccessView(), m_KDTreeBuffer->GetUnorderedAccessView(), m_IndiceBuffer->GetUnorderedAccessView() };
	g_DeviceContext->CSSetUnorderedAccessViews(0, 3, uav1, NULL);

	ID3D11UnorderedAccessView* uav2[] = { m_SwapStructure[0]->GetUnorderedAccessView(), m_SwapStructure[1]->GetUnorderedAccessView() };
	g_DeviceContext->CSSetUnorderedAccessViews(3, 2, uav2,NULL);

	ID3D11UnorderedAccessView* uav3[] = { m_SwapSize->GetUnorderedAccessView()};
	g_DeviceContext->CSSetUnorderedAccessViews(5, 1, uav3, NULL);


	// create the AABB list

	createAABBs->Set();

	g_timer->Start();
	g_DeviceContext->Dispatch(NROFTREADSKDTREECREATION, 1, 1);
	g_DeviceContext->Flush();
	g_timer->Stop();

	//	create the KD tree 
	createKDtree->Set();

	//g_timer->Start();
	g_DeviceContext->Dispatch(NROFTREADSKDTREECREATION, 1, 1);
	g_DeviceContext->Flush();
	//g_timer->Stop();
}

void GPURTGraphics::Render(float _dt)
{
	//set shader
	raytracer->Set();

	//set buffers
	g_DeviceContext->CSSetUnorderedAccessViews(0,1,&backbuffer,NULL);

	//set textures
	ID3D11ShaderResourceView *srv[] = { m_meshTexture, m_meshBuffer->GetResourceView(),
										m_NodeBuffer->GetResourceView(), m_Indices->GetResourceView()};
	g_DeviceContext->CSSetShaderResources(0, 4, srv);

	//dispatch
	g_DeviceContext->Dispatch(NROFTHREADSWIDTH, NROFTHREADSHEIGHT, 1);

	//unset buffers
	ID3D11UnorderedAccessView* nulluav[] = { NULL, NULL, NULL, NULL };
	g_DeviceContext->CSSetUnorderedAccessViews(0, 4, nulluav, NULL);

	ID3D11ShaderResourceView* nullsrv[] = { NULL, NULL, NULL, NULL };
	g_DeviceContext->CSSetShaderResources(0, 4, nullsrv);

	//unset shader
	raytracer->Unset();

	//present scene
	if (FAILED(g_SwapChain->Present(0, 0)))
		MessageBox(NULL,"Failed to present the swapchain","RT Render Error",S_OK);

	//Title text and FPS counter
	char title[256];
	sprintf_s(
		title,
		sizeof(title),
		"FCKDT Project - fps: %f - aabb: %f",
		m_fps,
		g_timer->GetTime()
		);
	SetWindowText(*m_Hwnd, title);
}

void GPURTGraphics::release()
{

	SAFE_RELEASE(m_meshTexture);
	SAFE_RELEASE(g_cBuffer);
	SAFE_RELEASE(backbuffer);

	SAFE_DELETE(m_meshBuffer);
	SAFE_DELETE(raytracer);
	SAFE_DELETE(computeWrap);
	SAFE_DELETE(triangleBuffer);

}

void GPURTGraphics::createKdTree(Mesh *_mesh)
{

}

void GPURTGraphics::updateTogglecb(int _lightSpheres, int _placeHolder1, int _placeHolder2)
{
	//togglescb.lightSpheres = _lightSpheres;

	//togglescb.togglePad = XMFLOAT3(0, 0, 0);
}
