#include "GPURTGraphics.h"


GPURTGraphics::GPURTGraphics(HWND* _hwnd)
: m_mesh(Mesh()),
m_meshTexture(nullptr),
m_time(0.f),
m_fps(0.f)
{
	HRESULT hr = S_OK;
	g_timer = new D3D11Timer(g_Device, g_DeviceContext);

	m_Hwnd = nullptr;
	m_Hwnd = _hwnd;
	m_SwapStructure[0] = NULL;
	m_SwapStructure[1] = NULL;

	g_cBuffer		= nullptr;
	backbuffer		= nullptr;
	m_meshBuffer	= nullptr;
	m_NodeBuffer	= nullptr;
	m_Indices		= nullptr;
	m_lightcBuffer	= nullptr;

	computeWrap = nullptr;
	computeWrap = new ComputeWrap(g_Device,g_DeviceContext);

	raytracer = computeWrap->CreateComputeShader("Raytracing");

	createKDtree = nullptr;
	createKDtree = computeWrap->CreateComputeShader("createKDtree");

	createKDtreeAppend = nullptr;
	createKDtreeAppend = computeWrap->CreateComputeShader("createKDtreeAppend");

	createAABBs = computeWrap->CreateComputeShader("createAABBs");


	splitCalcKDtree = computeWrap->CreateComputeShader("splitCalcKDtree");
	moveKDtree = computeWrap->CreateComputeShader("moveKDtree");
	prepKDtree = computeWrap->CreateComputeShader("prepKDtree");



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

	if (sizeof(depthcBuffer) % 16 > 0)
	{
		cbDesc.ByteWidth = (int)((sizeof(depthcBuffer) / 16) + 1) * 16;
	}
	else
	{
		cbDesc.ByteWidth = sizeof(depthcBuffer);
	}

	hr = g_Device->CreateBuffer(&cbDesc, NULL, &m_depthcBuffer);
	if (FAILED(hr))
	{
		MessageBox(NULL, "Failed Making Constant Buffer lightcBuffer", "Create Buffer", MB_OK);
	}
	g_DeviceContext->CSSetConstantBuffers(4, 1, &m_depthcBuffer);
}

void GPURTGraphics::createTriangleTexture()
{
	///////////////////////////////////////////////////////////////////////////////////////////
	//Mesh
	///////////////////////////////////////////////////////////////////////////////////////////
	std::string inputfile = "Meshi/kub.obj";
	//std::string inputfile = "Meshi/cornell_box.obj";

	std::vector<tinyobj::shape_t> shapes;
	std::vector<tinyobj::material_t> materials;

	std::string err = tinyobj::LoadObj(shapes, materials, inputfile.c_str());

	if (!err.empty())
	{
		MessageBox(NULL, "Failed reading the OBJ-file", inputfile.c_str(), MB_OK);
	}

	fillMesh(&shapes, &materials, &m_mesh);


	//////////////////OLD////////////////
	//Load OBJ-file
	//m_mesh.loadObj("Meshi/kub.obj");
	m_mesh.setColor(XMFLOAT4(1, 1, 1, 1));
	//m_mesh.scaleMesh(XMFLOAT3(0.10, 0.10, 0.10));
	m_mesh.scaleMesh(XMFLOAT3(10,10,10));
	//m_mesh.rotateMesh(XMFLOAT3(PI*0.2f,PI*0.5f,PI));
	//m_mesh.rotateMesh(XMFLOAT3(0.1f*PI, 0.1f * PI, 0.1f*PI));

	createKdTree(&m_mesh);

	m_meshBuffer = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
											 sizeof(TriangleMat),
											 m_mesh.getNrOfFaces(),
											 true,
											 false,
											 false,
											 m_mesh.getTriangles(),
											 false,
											 "Structured Buffer: Mesh Texture");


	m_aabbBuffer = computeWrap->CreateBuffer(	STRUCTURED_BUFFER,
												sizeof(AABB),
												m_mesh.getNrOfFaces(),
												false,
												true,
												false,
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


void GPURTGraphics::fillMesh(std::vector<tinyobj::shape_t>* _shapes, std::vector<tinyobj::material_t>* _materials, Mesh* _mesh)
{
	std::vector<TriangleMat> temp;

	for (int i = 0; i < _shapes->size(); i++)
	{
		std::vector<XMFLOAT4> pos;
		std::vector<XMFLOAT4> normal;
		for (int j = 0; j < _shapes->at(i).mesh.indices.size(); j++)
		{
			XMFLOAT4 tempPos;
			tempPos.x = _shapes->at(i).mesh.positions.at(_shapes->at(i).mesh.indices.at(j) * 3);
			tempPos.y = _shapes->at(i).mesh.positions.at(_shapes->at(i).mesh.indices.at(j) * 3 + 1);
			tempPos.z = _shapes->at(i).mesh.positions.at(_shapes->at(i).mesh.indices.at(j) * 3 + 2);
			tempPos.w = 0;

			pos.push_back(tempPos);

			if (_shapes->at(i).mesh.normals.size() > 0)
			{
				XMFLOAT4 tempNormal;
				//Normals
				tempNormal.x = _shapes->at(i).mesh.normals.at(_shapes->at(i).mesh.indices.at(j) * 3);
				tempNormal.y = _shapes->at(i).mesh.normals.at(_shapes->at(i).mesh.indices.at(j) * 3 + 1);
				tempNormal.z = _shapes->at(i).mesh.normals.at(_shapes->at(i).mesh.indices.at(j) * 3 + 2);
				tempNormal.w = 0;

				normal.push_back(tempNormal);
			}

		}

		for (int j = 0; j < pos.size(); j += 3)
		{
			TriangleMat tempPush;
			tempPush.pos0 = pos.at(j);
			tempPush.pos1 = pos.at(j + 1);
			tempPush.pos2 = pos.at(j + 2);

			tempPush.ID = temp.size();
			tempPush.pad = 0;

			if (_shapes->at(i).mesh.normals.size() > 0)
			{
				tempPush.normal = normal.at(j);
			}

			temp.push_back(tempPush);
		}


		int k = 0;
		for (int j = 0; j < _shapes->at(i).mesh.texcoords.size(); j += 6)
		{
			//Textcoordinats
			temp.at(k).textureCoordinate0.x = _shapes->at(i).mesh.texcoords.at(j);
			temp.at(k).textureCoordinate0.y = _shapes->at(i).mesh.texcoords.at(j + 1);

			temp.at(k).textureCoordinate1.x = _shapes->at(i).mesh.texcoords.at(j + 2);
			temp.at(k).textureCoordinate1.y = _shapes->at(i).mesh.texcoords.at(j + 3);

			temp.at(k).textureCoordinate2.x = _shapes->at(i).mesh.texcoords.at(j + 4);
			temp.at(k).textureCoordinate2.y = _shapes->at(i).mesh.texcoords.at(j + 5);
			k++;
		}


	}

	for (int i = 0; i < temp.size(); i++)
	{
		_mesh->m_meshTriangles.push_back(temp.at(i));
	}

	_mesh->m_nrOfFaces = _mesh->m_meshTriangles.size();

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
											 false,
											 initdata->data(),
											 false,
											 "Structed Buffer: Node Buffer");

	m_Indices = computeWrap->CreateBuffer(APPEND_BUFFER,
											 sizeof(int),
											 MAXSIZE,
											 false,
											 false,
											 true,
											 indiceList->data(),
											 false,
											 "Structed Buffer: Indice Buffer");

}

void GPURTGraphics::createLightBuffer()
{
	std::srand(LIGHT_RANDOM_SEED);
	for (int i = 0; i < NROFLIGHTS; i++)
	{
		float rx = ((float)(std::rand() % LIGHT_POSITION_RANGEMODIFIER)) - LIGHT_POSITION_RANGEMODIFIER / 2;
		float ry = ((float)(std::rand() % LIGHT_POSITION_RANGEMODIFIER)) - LIGHT_POSITION_RANGEMODIFIER / 2;
		float rz = ((float)(std::rand() % LIGHT_POSITION_RANGEMODIFIER)) - LIGHT_POSITION_RANGEMODIFIER / 2;
		lightcb.lightList[i].pos = XMFLOAT4(rx, ry, rz, 1.f);
		lightcb.lightList[i].ambient = XMFLOAT4(LIGHT_AMBIENT_MOD, LIGHT_AMBIENT_MOD, LIGHT_AMBIENT_MOD, 1.f);
		lightcb.lightList[i].diffuse = XMFLOAT4(LIGHT_DIFFUSE_MOD, LIGHT_DIFFUSE_MOD, LIGHT_DIFFUSE_MOD, 1.f);
		lightcb.lightList[i].range = LIGHT_RANGE;
		lightcb.lightList[i].pad = XMFLOAT3(0.f, 0.f, 0.f);

		//extra debug spheres
		//create lightsphere
		spherecb.sphereList[i].pos = lightcb.lightList[i].pos;
		spherecb.sphereList[i].color = XMFLOAT4(1, 0, 0, 1);
		spherecb.sphereList[i].radie = 4.f;
		spherecb.sphereList[i].pad = XMFLOAT3(0, 0, 0);
	}
}

void GPURTGraphics::createSwapStructures()
{
	m_SwapStructure[0] = computeWrap->CreateBuffer(APPEND_BUFFER,
		sizeof(int)*4,
		MAXSIZE,
		false,
		false,
		true,
		NULL,
		false,
		"Structured Buffer: Swap Structure");

	m_SwapStructure[1] = computeWrap->CreateBuffer(APPEND_BUFFER,
		sizeof(int)*4,
		MAXSIZE,
		false,
		false,
		true,
		NULL,
		false,
		"Structured Buffer: Swap Structure");

	m_SwapSize = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
		sizeof(int)*2,
		MAXSIZE,
		false,
		true,
		false,
		NULL,
		false,
		"Structured Buffer: Swap size Structure");

	m_IndiceBuffer = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
		sizeof(int),
		MAXSIZE,
		false,
		true,
		false,
		NULL,
		false,
		"Structured Buffer: Swap size Structure");

	m_AppendIndiceBuffer = computeWrap->CreateBuffer(APPEND_BUFFER,
		sizeof(int)*2,
		MAXSIZE,
		false,
		false,
		true,
		NULL,
		false,
		"Structured Buffer: Swap size Structure");

	m_KDTreeBuffer = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
		sizeof(NodePass2),
		MAXSIZE,
		false,
		true,
		false,
		NULL,
		false,
		"Structured Buffer: Swap size Structure");

	m_indexingCountBuffer = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
		sizeof(int),
		100,
		false,
		true,
		false,
		NULL,
		false,
		"Structured Buffer: Swap size Structure");

	
	m_mutex = computeWrap->CreateBuffer(STRUCTURED_BUFFER,
		sizeof(float),
		MAXSIZE,
		false,
		true,
		false,
		NULL,
		false,
		"Structured Buffer: Swap size Structure");

}

GPURTGraphics::~GPURTGraphics()
{
}

void GPURTGraphics::UpdateCamera(float _dt)
{
	// updating the constant buffer holding the camera transforms
	XMFLOAT4X4 temp, viewInv, projInv;
	XMFLOAT3 tempp = Cam->getCameraPosition(); // w ska va 1
	XMStoreFloat4x4(&temp, XMMatrixIdentity());

	XMStoreFloat4x4(&temp, XMMatrixTranslation(tempp.x, tempp.y, tempp.z));

	XMStoreFloat4x4(&temp, XMMatrixTranspose(XMLoadFloat4x4(&temp)));

	XMStoreFloat4x4(&viewInv, XMMatrixInverse(&XMMatrixDeterminant(
		XMLoadFloat4x4(&Cam->getViewMatrix())), XMLoadFloat4x4(&Cam->getViewMatrix())));

	XMStoreFloat4x4(&projInv, XMMatrixInverse(&XMMatrixDeterminant(
		XMLoadFloat4x4(&Cam->getProjectionMatrix())), XMLoadFloat4x4(&Cam->getProjectionMatrix())));


	cb.IV = viewInv;
	cb.IP = projInv;
	cb.cameraPos = XMFLOAT4(tempp.x, tempp.y, tempp.z, 1);
	cb.nrOfTriangles = m_mesh.getNrOfFaces();

	cb.pad.x = 0;
	cb.pad.y = 1;

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
}


void GPURTGraphics::Update(float _dt)
{



	// fill the aabb buffer


	ID3D11ShaderResourceView *srv[] = {  m_meshBuffer->GetResourceView()};
	g_DeviceContext->CSSetShaderResources(1, 1, srv);

	

	ID3D11UnorderedAccessView* uav1[] = { m_aabbBuffer->GetUnorderedAccessView(), m_KDTreeBuffer->GetUnorderedAccessView(), m_AppendIndiceBuffer->GetUnorderedAccessView() };
	g_DeviceContext->CSSetUnorderedAccessViews(0, 3, uav1, NULL);

	ID3D11UnorderedAccessView* uav2[] = { m_SwapStructure[0]->GetUnorderedAccessView(), m_SwapStructure[1]->GetUnorderedAccessView() };
	g_DeviceContext->CSSetUnorderedAccessViews(3, 2, uav2,NULL);

	ID3D11UnorderedAccessView* uav3[] = { m_SwapSize->GetUnorderedAccessView()};
	g_DeviceContext->CSSetUnorderedAccessViews(5, 1, uav3, NULL);

	ID3D11UnorderedAccessView* uav4[] = { m_indexingCountBuffer->GetUnorderedAccessView() };
	g_DeviceContext->CSSetUnorderedAccessViews(6, 1, uav4, NULL);
	
	ID3D11UnorderedAccessView* uav5[] = { m_mutex->GetUnorderedAccessView() };
	g_DeviceContext->CSSetUnorderedAccessViews(7, 1, uav5, NULL);

	// create the AABB list --------------------------------------
	createAABBs->Set();
	g_timer->Start();
	g_DeviceContext->Dispatch(NROFTREADSKDTREECREATION, 1, 1);
	g_DeviceContext->Flush();
	g_timer->Stop();

	float getTime = g_timer->GetTime();

	//	create the full KD tree ----------------------------------------
	createKDtree->Set();
	g_timer->Start();
	g_DeviceContext->Dispatch(NROFTREADSKDTREECREATION, 1, 1);
	g_DeviceContext->Flush();
	g_timer->Stop();






	depthcb.depth = 0;
	depthcb.padDepth.x = 0;
	depthcb.padDepth.y = 0;
	depthcb.padDepth.z = 1;

	//for (int i = 0; i < MAXDEPTH; i++)
	//{
	//	//g_DeviceContext->UpdateSubresource(m_depthcBuffer, 0, NULL, &depthcb, 0, 0);

	//	g_DeviceContext->UpdateSubresource(g_cBuffer, 0, NULL, &cb, 0, 0);

	//	//// the split calculation
	//	//splitCalcKDtree->Set();
	//	//g_DeviceContext->Dispatch(NROFTREADSKDTREECREATION, 1, 1);

	//	//// moving the split
	//	//splitCalcKDtree->Set();
	//	//g_DeviceContext->Dispatch(NROFTREADSKDTREECREATION, 1, 1);

	//	//// next depth prep
	//	//splitCalcKDtree->Set();
	//	g_DeviceContext->Dispatch(NROFTREADSKDTREECREATION, 1, 1);


	//	cb.pad.x++;

	//}


	//g_DeviceContext->Flush();


	getTime = g_timer->GetTime();

	//unset buffers
	ID3D11UnorderedAccessView* nulluav[] = { NULL, NULL, NULL, NULL, NULL, NULL, NULL };
	g_DeviceContext->CSSetUnorderedAccessViews(0, 7, nulluav, NULL);

	ID3D11ShaderResourceView* nullsrv[] = { NULL, NULL, NULL, NULL };
	g_DeviceContext->CSSetShaderResources(0, 4, nullsrv);


	//for (int i = 0; i < MAXDEPTH; i++)
	//{

	//	splitCalcKDtree->Set();
	//	g_DeviceContext->Dispatch(NROFTREADSKDTREECREATION, 1, 1);

	//	moveKDtree->Set();
	//	g_DeviceContext->Dispatch(NROFTREADSKDTREECREATION, 1, 1);

	//	prepKDtree->Set();
	//	g_DeviceContext->Dispatch(NROFTREADSKDTREECREATION, 1, 1);
	//}



}

void GPURTGraphics::Render(float _dt)
{
	//set shader
	raytracer->Set();

	//set buffers
	g_DeviceContext->CSSetUnorderedAccessViews(0,1,&backbuffer,NULL);

	//set textures
	ID3D11ShaderResourceView *srv[] = { m_meshTexture, m_meshBuffer->GetResourceView() };
	g_DeviceContext->CSSetShaderResources(0, 2, srv);

	ID3D11UnorderedAccessView* uav1[] = { m_KDTreeBuffer->GetUnorderedAccessView(), m_IndiceBuffer->GetUnorderedAccessView() };
	g_DeviceContext->CSSetUnorderedAccessViews(2, 2, uav1, NULL);

	//dispatch
	//g_DeviceContext->Dispatch(NROFTHREADSWIDTH, NROFTHREADSHEIGHT, 1);

	//unset buffers
	ID3D11UnorderedAccessView* nulluav[] = { NULL, NULL, NULL, NULL };
	g_DeviceContext->CSSetUnorderedAccessViews(0, 4, nulluav, NULL);

	ID3D11ShaderResourceView* nullsrv[] = { NULL, NULL, NULL, NULL };
	g_DeviceContext->CSSetShaderResources(0, 4, nullsrv);

	//unset shader
	raytracer->Unset();

	//present scene
	if (FAILED(g_SwapChain->Present(0, 0)))
		MessageBox(NULL,"Failed to present the swapchain","GPURT Render Error",S_OK);

	//Title text and FPS counter
	char title[256];
	sprintf_s(
		title,
		sizeof(title),
		"Realtime - fps: %f - aabb: %f",
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
	SAFE_RELEASE(m_aabbBuffer);
	SAFE_RELEASE(m_NodeBuffer);
	SAFE_RELEASE(m_Indices);
	SAFE_RELEASE(m_lightcBuffer);

	SAFE_DELETE(m_meshBuffer);
	SAFE_DELETE(raytracer);
	SAFE_DELETE(computeWrap);
	//SAFE_DELETE(g_timer);
}

void GPURTGraphics::createKdTree(Mesh *_mesh)
{

}

void GPURTGraphics::updateTogglecb(int _lightSpheres, int _placeHolder1, int _placeHolder2)
{
	//togglescb.lightSpheres = _lightSpheres;

	//togglescb.togglePad = XMFLOAT3(0, 0, 0);
}
