#include "RTGraphics.h"


 RTGraphics::RTGraphics(HWND* _hwnd)
: m_mesh(Mesh()),
m_meshTexture(nullptr),
m_time(0.f),
m_fps(0.f)
{
	HRESULT hr = S_OK;

	m_Hwnd = _hwnd;

	computeWrap = new ComputeWrap(g_Device,g_DeviceContext);

	raytracer = computeWrap->CreateComputeShader("Raytracing");

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

	//create lights
	createLightBuffer();


}

void RTGraphics::createCBuffers()
{
	HRESULT hr = S_OK;

	D3D11_BUFFER_DESC cbDesc;
	cbDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	cbDesc.Usage = D3D11_USAGE_DEFAULT;
	// CPU writable, should be updated per frame
	cbDesc.CPUAccessFlags = 0;
	cbDesc.MiscFlags = 0;

	///Mesh cbuffer
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

	///Light cbuffer
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

	///Light sphere cbuffer
	if (sizeof(cSphereBuffer) % 16 > 0)
	{
		cbDesc.ByteWidth = (int)((sizeof(cSphereBuffer) / 16) + 1) * 16;
	}
	else
	{
		cbDesc.ByteWidth = sizeof(cSphereBuffer);
	}

	hr = g_Device->CreateBuffer(&cbDesc, NULL, &m_spherecBuffer);
	if (FAILED(hr))
	{
		MessageBox(NULL, "Failed Making Constant Buffer spherecBuffer", "Create Buffer", MB_OK);
	}
	g_DeviceContext->CSSetConstantBuffers(2, 1, &m_spherecBuffer);
}

void RTGraphics::createTriangleTexture()
{
	///////////////////////////////////////////////////////////////////////////////////////////
	//Mesh
	///////////////////////////////////////////////////////////////////////////////////////////

	//Load OBJ-file
	m_mesh.loadObj("Meshi/kub.obj");
	m_mesh.setColor(XMFLOAT4(1,1,1,1));
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

void fillKDBuffers(Node* _node, std::vector<NodePass2> *_initdata, std::vector<int> *_indiceList, int _index)
{

	if (_node->left == NULL && _node->right == NULL)
	{
		_initdata->at(_index).left_right_nodeID[0] = -1;
		_initdata->at(_index).left_right_nodeID[1] = -1;
		_initdata->at(_index).index = _indiceList->size();
		_initdata->at(_index).nrOfTriangles = _node->index->size();

		for (int i = 0; i < _node->index->size(); i++)
		{
			_indiceList->push_back(_node->index->at(i));
		}

	}
	else
	{
		NodePass2 nodeRight;
		NodePass2 nodeLeft;

		nodeLeft.aabb = _node->left->aabb;
		nodeLeft.index = -1;
		nodeLeft.nrOfTriangles = 0;
		nodeRight.aabb = _node->right->aabb;
		nodeRight.index = -1;
		nodeRight.nrOfTriangles = 0;

		_initdata->push_back(nodeLeft);
		_initdata->at(_index).left_right_nodeID[0] = _initdata->size() - 1;

		_initdata->push_back(nodeRight);
		_initdata->at(_index).left_right_nodeID[1] = _initdata->size() - 1;

		fillKDBuffers(_node->left, _initdata, _indiceList, _initdata->at(_index).left_right_nodeID[0]);
		fillKDBuffers(_node->right, _initdata, _indiceList, _initdata->at(_index).left_right_nodeID[1]);
	}

}

void RTGraphics::createNodeBuffer(Node* _rootNode)
{
	std::vector<NodePass2> *initdata = new std::vector<NodePass2>();
	std::vector<int> *indiceList = new std::vector<int>();


	NodePass2 node;
	node.aabb = _rootNode->aabb;
	node.index = -1;
	node.nrOfTriangles = 0;

	initdata->push_back(node);

	fillKDBuffers(_rootNode, initdata, indiceList, 0);


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

void RTGraphics::createLightBuffer()
{
	std::srand(10);
	for (int i = 0; i < NROFLIGHTS; i++)
	{
		float rx = ((float)(std::rand() % LIGHT_POSITION_RANGEMODIFIER)) - LIGHT_POSITION_RANGEMODIFIER / 2;
		float ry = ((float)(std::rand() % LIGHT_POSITION_RANGEMODIFIER)) - LIGHT_POSITION_RANGEMODIFIER / 2;
		float rz = ((float)(std::rand() % LIGHT_POSITION_RANGEMODIFIER)) - LIGHT_POSITION_RANGEMODIFIER / 2;
		lightcb.lightList[i].pos = XMFLOAT4(rx, ry, rz, 1.f);
		lightcb.lightList[i].ambient = XMFLOAT4(0.1f, 0.1f, 0.1f, 1.f);
		lightcb.lightList[i].diffuse = XMFLOAT4(0.5f, 0.5f, 0.5f, 1.f);
		lightcb.lightList[i].range = LIGHT_RANGE;
		lightcb.lightList[i].pad = XMFLOAT3(0.f, 0.f, 0.f);

		//extra debug spheres
		//create lightsphere
		spherecb.sphereList[i].pos = lightcb.lightList[i].pos;
		spherecb.sphereList[i].pos = XMFLOAT4(0,0,0,0);
		spherecb.sphereList[i].color = XMFLOAT4(1, 0, 0, 1);
		spherecb.sphereList[i].radie = 4.f;
		spherecb.sphereList[i].pad = XMFLOAT3(0, 0, 0);
	}
}

RTGraphics::~RTGraphics()
{
}

void RTGraphics::Update(float _dt)
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

	g_DeviceContext->UpdateSubresource(m_spherecBuffer, 0, NULL, &spherecb, 0, 0);

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

void RTGraphics::Render(float _dt)
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
		"FCKDT Project - fps: %f",
		m_fps
		);
	SetWindowText(*m_Hwnd, title);
}

void releaseKdTree(Node *_node)
{
	if (_node->left != NULL)
	{
		releaseKdTree(_node->left);
		SAFE_DELETE(_node->left);
	}
	else
	{
		_node->index->clear();
	}
	if (_node->right != NULL)
	{
		releaseKdTree(_node->right);
		SAFE_DELETE(_node->right);
	}
	else
	{
		_node->index->clear();
	}
}

void RTGraphics::release()
{
	releaseKdTree(&m_rootNode);

	SAFE_RELEASE(m_meshTexture);
	SAFE_RELEASE(g_cBuffer);
	SAFE_RELEASE(backbuffer);
	SAFE_RELEASE(m_lightcBuffer);
	SAFE_RELEASE(m_spherecBuffer);

	SAFE_DELETE(m_meshBuffer);
	SAFE_DELETE(raytracer);
	SAFE_DELETE(computeWrap);
	SAFE_DELETE(triangleBuffer);

}

void RTGraphics::createKdTree(Mesh *_mesh)
{
	std::vector<TriangleMat> *triangleList = _mesh->getTriangleList();
	std::vector<AABB> aabbList;


	// CREATION OF AABB LIST
	for (int i = 0; i < triangleList->size(); i++)
	{
		float min = INFINITY;
		float max = -INFINITY;

		TriangleMat tri = triangleList->at(i);
		AABB aabb;

		aabb.maxPoint.x = (tri.pos0.x > tri.pos1.x) ? tri.pos0.x : tri.pos1.x;
		aabb.maxPoint.x = (aabb.maxPoint.x > tri.pos2.x) ? aabb.maxPoint.x : tri.pos2.x;

		aabb.maxPoint.y = (tri.pos0.y > tri.pos1.y) ? tri.pos0.y : tri.pos1.y;
		aabb.maxPoint.y = (aabb.maxPoint.y > tri.pos2.y) ? aabb.maxPoint.y : tri.pos2.y;

		aabb.maxPoint.z = (tri.pos0.z > tri.pos1.z) ? tri.pos0.z : tri.pos1.z;
		aabb.maxPoint.z = (aabb.maxPoint.z > tri.pos2.z) ? aabb.maxPoint.z : tri.pos2.z;

		aabb.minPoint.x = (tri.pos0.x < tri.pos1.x) ? tri.pos0.x : tri.pos1.x;
		aabb.minPoint.x = (aabb.minPoint.x < tri.pos2.x) ? aabb.minPoint.x : tri.pos2.x;

		aabb.minPoint.y = (tri.pos0.y < tri.pos1.y) ? tri.pos0.y : tri.pos1.y;
		aabb.minPoint.y = (aabb.minPoint.y < tri.pos2.y) ? aabb.minPoint.y : tri.pos2.y;

		aabb.minPoint.z = (tri.pos0.z < tri.pos1.z) ? tri.pos0.z : tri.pos1.z;
		aabb.minPoint.z = (aabb.minPoint.z < tri.pos2.z) ? aabb.minPoint.z : tri.pos2.z;

		aabb.triangleIndex = i;

		aabbList.push_back(aabb);
	}

	createKDNodeSplit(&aabbList,&m_rootNode,1);

	int breakStop = 0;
}

void assignTriangles(Node* _node, std::vector<AABB>* _AABBList)
{
	_node->index = new std::vector<int>();

	for (int i = 0; i < _AABBList->size(); i++)
	{
		_node->index->push_back(_AABBList->at(i).triangleIndex);
	}
}

void sortAABBX(std::vector<AABB>* _AABBList, int _lowIndex, int _highIndex)
{
	float pivotValue;
	int pivotIndex;

	int highIndex = _highIndex;
	int lowIndex = _lowIndex;

	pivotValue = (_AABBList->at(_highIndex).minPoint.x + _AABBList->at(_highIndex).maxPoint.x) * 0.5f;
	pivotIndex = _highIndex;

	_highIndex--;

	while (lowIndex < highIndex)
	{
		float highValue = (_AABBList->at(highIndex).minPoint.x + _AABBList->at(highIndex).maxPoint.x) * 0.5f;
		float lowValue = (_AABBList->at(lowIndex).minPoint.x + _AABBList->at(lowIndex).maxPoint.x) * 0.5f;

		if (highValue < pivotValue && lowValue > pivotValue) //Time to swap = highIndex value lower than pivotValue and lowIndex value higher than pivotValue
		{
			AABB temp = _AABBList->at(lowIndex);
			_AABBList->at(lowIndex) = _AABBList->at(highIndex);
			_AABBList->at(highIndex) = temp;
			lowIndex++;
		}
		else if (lowValue <= pivotValue) //lowIndex value smaler than pivotValue
		{
			lowIndex++;
		}
		else if (highValue >= pivotValue) //highIndex value higher than pivotValue
		{
			highIndex--;
		}
	}

	AABB temp = _AABBList->at(highIndex);
	_AABBList->at(highIndex) = _AABBList->at(pivotIndex);  //swapping the pivot element to the right place
	_AABBList->at(pivotIndex) = temp;

	if (lowIndex - 1 - _lowIndex > 2)
	{
		sortAABBX(_AABBList, _lowIndex, lowIndex - 1); // left sub sort
	}
	if (_highIndex - lowIndex > 2)
	{
		sortAABBX(_AABBList, lowIndex, _highIndex); // right sub sort
	}
}

void sortAABBY(std::vector<AABB>* _AABBList, int _lowIndex, int _highIndex)
{
	float pivotValue;
	int pivotIndex;

	int highIndex = _highIndex;
	int lowIndex = _lowIndex;

	pivotValue = (_AABBList->at(_highIndex).minPoint.y + _AABBList->at(_highIndex).maxPoint.y) * 0.5f;
	pivotIndex = _highIndex;

	_highIndex--;

	while (lowIndex < highIndex)
	{
		float highValue = (_AABBList->at(highIndex).minPoint.y + _AABBList->at(highIndex).maxPoint.y) * 0.5f;
		float lowValue = (_AABBList->at(lowIndex).minPoint.y + _AABBList->at(lowIndex).maxPoint.y) * 0.5f;

		if (highValue < pivotValue && lowValue > pivotValue) //Time to swap = highIndex value lower than pivotValue and lowIndex value higher than pivotValue
		{
			AABB temp = _AABBList->at(lowIndex);
			_AABBList->at(lowIndex) = _AABBList->at(highIndex);
			_AABBList->at(highIndex) = temp;
			lowIndex++;
		}
		else if (lowValue <= pivotValue) //lowIndex value smaler than pivotValue
		{
			lowIndex++;
		}
		else if (highValue >= pivotValue) //highIndex value higher than pivotValue
		{
			highIndex--;
		}
	}

	AABB temp = _AABBList->at(highIndex);
	_AABBList->at(highIndex) = _AABBList->at(pivotIndex);  //swapping the pivot element to the right place
	_AABBList->at(pivotIndex) = temp;

	if (lowIndex - 1 - _lowIndex > 2)
	{
		sortAABBY(_AABBList, _lowIndex, lowIndex - 1); // left sub sort
	}
	if (_highIndex - lowIndex > 2)
	{
		sortAABBY(_AABBList, lowIndex, _highIndex); // right sub sort
	}
}

void sortAABBZ(std::vector<AABB>* _AABBList, int _lowIndex, int _highIndex)
{
	float pivotValue;
	int pivotIndex;

	int highIndex = _highIndex;
	int lowIndex = _lowIndex;

	pivotValue = (_AABBList->at(_highIndex).minPoint.z + _AABBList->at(_highIndex).maxPoint.z) * 0.5f;
	pivotIndex = _highIndex;

	_highIndex--;

	while (lowIndex < highIndex)
	{
		float highValue = (_AABBList->at(highIndex).minPoint.z + _AABBList->at(highIndex).maxPoint.z) * 0.5f;
		float lowValue = (_AABBList->at(lowIndex).minPoint.z + _AABBList->at(lowIndex).maxPoint.z) * 0.5f;

		if (highValue < pivotValue && lowValue > pivotValue) //Time to swap = highIndex value lower than pivotValue and lowIndex value higher than pivotValue
		{
			AABB temp = _AABBList->at(lowIndex);
			_AABBList->at(lowIndex) = _AABBList->at(highIndex);
			_AABBList->at(highIndex) = temp;
			lowIndex++;
		}
		else if (lowValue <= pivotValue) //lowIndex value smaler than pivotValue
		{
			lowIndex++;
		}
		else if (highValue >= pivotValue) //highIndex value higher than pivotValue
		{
			highIndex--;
		}
	}

	AABB temp = _AABBList->at(highIndex);
	_AABBList->at(highIndex) = _AABBList->at(pivotIndex);  //swapping the pivot element to the right place
	_AABBList->at(pivotIndex) = temp;

	if (lowIndex - 1 - _lowIndex > 1)
	{
		sortAABBZ(_AABBList, _lowIndex, lowIndex - 1); // left sub sort
	}
	if (_highIndex - lowIndex > 1)
	{
		sortAABBZ(_AABBList, lowIndex, _highIndex); // right sub sort
	}
}

void createNodeAABB(Node* _node, std::vector<AABB>* _AABBList)
{
	XMFLOAT4 max = _AABBList->at(0).maxPoint;
	XMFLOAT4 min = _AABBList->at(0).minPoint;;
	
	for (int i = 1; i < _AABBList->size(); i++)
	{
		max.x = (_AABBList->at(i).maxPoint.x > max.x) ? _AABBList->at(i).maxPoint.x : max.x;
		max.y = (_AABBList->at(i).maxPoint.y > max.y) ? _AABBList->at(i).maxPoint.y : max.y;
		max.z = (_AABBList->at(i).maxPoint.z > max.z) ? _AABBList->at(i).maxPoint.z : max.z;

		min.x = (_AABBList->at(i).minPoint.x < min.x) ? _AABBList->at(i).minPoint.x : min.x;
		min.y = (_AABBList->at(i).minPoint.y < min.y) ? _AABBList->at(i).minPoint.y : min.y;
		min.z = (_AABBList->at(i).minPoint.z < min.z) ? _AABBList->at(i).minPoint.z : min.z;
	}

	_node->aabb.maxPoint = max;
	_node->aabb.minPoint = min;

}

void RTGraphics::splitListX(Node* _node, std::vector<AABB>* _AABBList)
{
	int medianIndex = _AABBList->size() / 2;
	float medianValue = (_AABBList->at(medianIndex).maxPoint.x + _AABBList->at(medianIndex).minPoint.x)*0.5f;

	std::vector<AABB>* AABBListLeft = new std::vector<AABB>();
	std::vector<AABB>* AABBListRight = new std::vector<AABB>();

	for (int i = 0; i < _AABBList->size(); i++)
	{
		if (_AABBList->at(i).maxPoint.x < medianValue)
		{
			AABBListLeft->push_back(_AABBList->at(i));
		}
		else if (_AABBList->at(i).minPoint.x > medianValue)
		{
			AABBListRight->push_back(_AABBList->at(i));
		}
		else
		{
			AABBListLeft->push_back(_AABBList->at(i));
			AABBListRight->push_back(_AABBList->at(i));
		}
	}

	// SPLITT LIST OR CREATE LEAF NODE
	if (AABBListLeft->size() < _AABBList->size() && AABBListLeft->size() > 0)
	{
		_node->left = new Node();

		createKDNodeSplit(AABBListLeft, _node->left, 2);
	}
	else if (AABBListLeft->size() == _AABBList->size() && AABBListRight->size() == _AABBList->size())
	{
		return;
	}
	else if (AABBListLeft->size() == _AABBList->size() || AABBListLeft->size() == 0)
	{
		_node->left = new Node();
		_node->left->aabb = _node->aabb;
		assignTriangles(_node->left, _AABBList);
	}

	if (AABBListRight->size() < _AABBList->size() && AABBListRight->size() > 0)
	{
		_node->right = new Node();

		createKDNodeSplit(AABBListRight, _node->right, 2);
	}
	else if (AABBListRight->size() == _AABBList->size() || AABBListRight->size() == 0)
	{
		_node->right = new Node();
		_node->right->aabb = _node->aabb;
		assignTriangles(_node->right, _AABBList);
	}
}

void RTGraphics::splitListY(Node* _node, std::vector<AABB>* _AABBList)
{
	int medianIndex = _AABBList->size() / 2;
	float medianValue = (_AABBList->at(medianIndex).maxPoint.y + _AABBList->at(medianIndex).minPoint.y)*0.5f;

	std::vector<AABB>* AABBListLeft = new std::vector<AABB>();
	std::vector<AABB>* AABBListRight = new std::vector<AABB>();

	for (int i = 0; i < _AABBList->size(); i++)
	{
		if (_AABBList->at(i).maxPoint.y < medianValue)
		{
			AABBListLeft->push_back(_AABBList->at(i));
		}
		else if (_AABBList->at(i).minPoint.y > medianValue)
		{
			AABBListRight->push_back(_AABBList->at(i));
		}
		else
		{
			AABBListLeft->push_back(_AABBList->at(i));
			AABBListRight->push_back(_AABBList->at(i));
		}
	}

	// SPLITT LIST OR CREATE LEAF NODE
	if (AABBListLeft->size() < _AABBList->size() && AABBListLeft->size() > 0)
	{
		_node->left = new Node();

		createKDNodeSplit(AABBListLeft, _node->left, 3);
	}
	else if (AABBListLeft->size() == _AABBList->size() && AABBListRight->size() == _AABBList->size())
	{
		return;
	}
	else if (AABBListLeft->size() == _AABBList->size() || AABBListLeft->size() == 0)
	{
		_node->left = new Node();
		_node->left->aabb = _node->aabb;
		assignTriangles(_node->left, _AABBList);
	}

	if (AABBListRight->size() < _AABBList->size() && AABBListRight->size() > 0)
	{
		_node->right = new Node();

		createKDNodeSplit(AABBListRight, _node->right, 3);
	}
	else if (AABBListRight->size() == _AABBList->size() || AABBListRight->size() == 0)
	{
		_node->right = new Node();
		_node->right->aabb = _node->aabb;
		assignTriangles(_node->right, _AABBList);
	}
}

void RTGraphics::splitListZ(Node* _node, std::vector<AABB>* _AABBList)
{
	int medianIndex = _AABBList->size() / 2;
	float medianValue = (_AABBList->at(medianIndex).maxPoint.z + _AABBList->at(medianIndex).minPoint.z)*0.5f;

	std::vector<AABB>* AABBListLeft = new std::vector<AABB>();
	std::vector<AABB>* AABBListRight = new std::vector<AABB>();

	for (int i = 0; i < _AABBList->size(); i++)
	{
		if (_AABBList->at(i).maxPoint.z < medianValue)
		{
			AABBListLeft->push_back(_AABBList->at(i));
		}
		else if (_AABBList->at(i).minPoint.z > medianValue)
		{
			AABBListRight->push_back(_AABBList->at(i));
		}
		else
		{
			AABBListLeft->push_back(_AABBList->at(i));
			AABBListRight->push_back(_AABBList->at(i));
		}
	}

	// SPLITT LIST OR CREATE LEAF NODE
	if (AABBListLeft->size() < _AABBList->size() && AABBListLeft->size() > 0)
	{
		_node->left = new Node();

		createKDNodeSplit(AABBListLeft, _node->left, 1);
	}
	else if (AABBListLeft->size() == _AABBList->size() && AABBListRight->size() == _AABBList->size())
	{
		return;
	}
	else if (AABBListLeft->size() == _AABBList->size() || AABBListLeft->size() == 0)
	{
		_node->left = new Node();
		_node->left->aabb = _node->aabb;
		assignTriangles(_node->left, _AABBList);
	}

	if (AABBListRight->size() < _AABBList->size() && AABBListRight->size() > 0)
	{
		_node->right = new Node();

		createKDNodeSplit(AABBListRight, _node->right, 1);
	}
	else if (AABBListRight->size() == _AABBList->size() || AABBListRight->size() == 0)
	{
		_node->right = new Node();
		_node->right->aabb = _node->aabb;
		assignTriangles(_node->right, _AABBList);
	}
}

void RTGraphics::createKDNodeSplit(std::vector<AABB>* _AABBList, Node* _node, int _split)
{
	
	switch (_split)
	{
	case 1:		// SPLITT IN X

		sortAABBX(_AABBList, 0, _AABBList->size() - 1);
		createNodeAABB(_node, _AABBList);
		splitListX(_node, _AABBList);
		assignTriangles(_node, _AABBList);
		break;
	case 2:		// SPLITT IN Y

		sortAABBY(_AABBList, 0, _AABBList->size() - 1);
		createNodeAABB(_node, _AABBList);
		splitListY(_node, _AABBList);
		assignTriangles(_node, _AABBList);
		break;
	case 3:		// SPLITT IN Z

		sortAABBZ(_AABBList, 0, _AABBList->size() - 1);
		createNodeAABB(_node, _AABBList);
		splitListZ(_node, _AABBList);
		assignTriangles(_node, _AABBList);
		break;
	}


}


