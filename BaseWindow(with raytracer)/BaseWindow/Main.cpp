#include "stdafx.h"

#include "InputManager.h"
#include "ButtonInput.h"
#include <vector>
#include "Graphics.h"

//#define standardrender
#define raytracing
//#define gpuraytracing

#ifdef raytracing
#include "RTGraphics.h"
#endif

#ifdef gpuraytracing
#include "GPURTGraphics.h"
#endif

#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>

//--------------------------------------------------------------------------------------
// Forward declarations
//--------------------------------------------------------------------------------------
HRESULT             InitWindow(HINSTANCE hInstance, int nCmdShow);
LRESULT CALLBACK    WndProc(HWND, UINT, WPARAM, LPARAM);
HRESULT				Render(float deltaTime);
HRESULT				Update(float deltaTime);
void				release();

HINSTANCE				g_hInst = NULL;
HWND					g_hWnd = NULL;

IDXGISwapChain*         g_SwapChain = NULL;
ID3D11Device*			g_Device = NULL;
ID3D11DeviceContext*	g_DeviceContext = NULL;

Camera* Cam = new Camera();
ButtonInput* buttonInput = new ButtonInput();

int g_Width, g_Height;



#ifdef raytracing

RTGraphics *graphics;

#endif

#ifdef gpuraytracing

GPURTGraphics *graphics;

#endif

#ifdef standardrender

Graphics *graphics;

#endif



char* FeatureLevelToString(D3D_FEATURE_LEVEL featureLevel)
{
	if (featureLevel == D3D_FEATURE_LEVEL_11_0)
		return "11.0";
	if (featureLevel == D3D_FEATURE_LEVEL_10_1)
		return "10.1";
	if (featureLevel == D3D_FEATURE_LEVEL_10_0)
		return "10.0";

	return "Unknown";
}

void toggle()
{
	graphics->updateTogglecb(buttonInput->GetMPressed(), buttonInput->GetIsVPressed(), buttonInput->GetBPressed() );
}


HRESULT Init()
{
	HRESULT hr = S_OK;;

	RECT rc;
	GetClientRect(g_hWnd, &rc);
	g_Width = rc.right - rc.left;
	g_Height = rc.bottom - rc.top;


	UINT createDeviceFlags = 0;
#ifdef _DEBUG
	createDeviceFlags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

	D3D_DRIVER_TYPE driverType;

	D3D_DRIVER_TYPE driverTypes[] =
	{
		D3D_DRIVER_TYPE_HARDWARE,
		D3D_DRIVER_TYPE_REFERENCE,
	};
	UINT numDriverTypes = sizeof(driverTypes) / sizeof(driverTypes[0]);

	DXGI_SWAP_CHAIN_DESC sd;
	ZeroMemory(&sd, sizeof(sd));
	sd.BufferCount = 1;
	sd.BufferDesc.Width = g_Width;
	sd.BufferDesc.Height = g_Height;
	sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
	sd.BufferDesc.RefreshRate.Numerator = 60;
	sd.BufferDesc.RefreshRate.Denominator = 1;
	sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT | DXGI_USAGE_UNORDERED_ACCESS;
	sd.OutputWindow = g_hWnd;
	sd.SampleDesc.Count = 1;
	sd.SampleDesc.Quality = 0;
	sd.Windowed = TRUE;
	sd.BufferDesc.ScanlineOrdering = DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;
	sd.BufferDesc.Scaling = DXGI_MODE_SCALING_UNSPECIFIED;

	D3D_FEATURE_LEVEL featureLevelsToTry[] = {
		D3D_FEATURE_LEVEL_11_0,
		D3D_FEATURE_LEVEL_10_1,
		D3D_FEATURE_LEVEL_10_0
	};
	D3D_FEATURE_LEVEL initiatedFeatureLevel;

	for (UINT driverTypeIndex = 0; driverTypeIndex < numDriverTypes; driverTypeIndex++)
	{
		driverType = driverTypes[driverTypeIndex];
		hr = D3D11CreateDeviceAndSwapChain(
			NULL,
			driverType,
			NULL,
			createDeviceFlags,
			featureLevelsToTry,
			ARRAYSIZE(featureLevelsToTry),
			D3D11_SDK_VERSION,
			&sd,
			&g_SwapChain,
			&g_Device,
			&initiatedFeatureLevel,
			&g_DeviceContext);

		if (SUCCEEDED(hr))
		{
			char title[256];
			sprintf_s(
				title,
				sizeof(title),
				"Basic d3d%s window",
				FeatureLevelToString(initiatedFeatureLevel)
				);
			SetWindowText(g_hWnd, title);

			break;
		}
	}
	if (FAILED(hr))
		return hr;

#ifdef raytracing
	graphics = new RTGraphics(&g_hWnd);
#endif

#ifdef gpuraytracing
	graphics = new GPURTGraphics(&g_hWnd);
#endif

#ifdef standardrender
	graphics = new Graphics();
#endif

	return S_OK;
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPWSTR lpCmdLine, int nCmdShow)
{
	///Fixing with memory leaks
	_CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);

	_CrtDumpMemoryLeaks();

	//Change the number to find a specific 
	//_crtBreakAlloc = 1585;
	///
	if (FAILED(InitWindow(hInstance, nCmdShow)))
		return 0;

	if (FAILED(Init()))
		return 0;

	if (RegisterInputDevices(g_hWnd) == false)
	{
		return 0;
	}

	
	__int64 cntsPerSec = 0;
	QueryPerformanceFrequency((LARGE_INTEGER*)&cntsPerSec);
	float secsPerCnt = 1.0f / (float)cntsPerSec;

	__int64 prevTimeStamp = 0;
	QueryPerformanceCounter((LARGE_INTEGER*)&prevTimeStamp);

	Cam->setPerspectiveProjectionLH(90.0f, (float)g_Width, (float)g_Height, 1.0f, 1000.0f);

	Cam->setPositionAndView(0.0f, 0.0f, -20.0f, 0.0f, 0.0f);

	// Main message loop
	MSG msg = { 0 };
	while (WM_QUIT != msg.message)
	{
		if (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
		{
			TranslateMessage(&msg);
			DispatchMessage(&msg);
		}
		else
		{
			__int64 currTimeStamp = 0;
			QueryPerformanceCounter((LARGE_INTEGER*)&currTimeStamp);
			float dt = (currTimeStamp - prevTimeStamp) * secsPerCnt;

			toggle();

			//render
			graphics->Update(dt);
			graphics->Render(dt);

			Cam->update();

			prevTimeStamp = currTimeStamp;
		}
	}

	release();

	return (int)msg.wParam;
}


//--------------------------------------------------------------------------------------
// Register class and create window
//--------------------------------------------------------------------------------------
HRESULT InitWindow(HINSTANCE hInstance, int nCmdShow)
{
	// Register class
	WNDCLASSEX wcex;
	wcex.cbSize = sizeof(WNDCLASSEX);
	wcex.style = CS_HREDRAW | CS_VREDRAW;
	wcex.lpfnWndProc = WndProc;
	wcex.cbClsExtra = 0;
	wcex.cbWndExtra = 0;
	wcex.hInstance = hInstance;
	wcex.hIcon = 0;
	wcex.hCursor = LoadCursor(NULL, IDC_ARROW);
	wcex.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
	wcex.lpszMenuName = NULL;
	wcex.lpszClassName = "Base d3dx window";
	wcex.hIconSm = 0;
	if (!RegisterClassEx(&wcex))
		return E_FAIL;

	// Create window
	g_hInst = hInstance;
	RECT rc = { 0, 0, WIDTH, HEIGHT };
	AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);

	if (!(g_hWnd = CreateWindow(
		"Base d3dx window",
		"Basic d3dx window",
		WS_OVERLAPPEDWINDOW,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		rc.right - rc.left,
		rc.bottom - rc.top,
		NULL,
		NULL,
		hInstance,
		NULL)))
	{
		return E_FAIL;
	}

	ShowWindow(g_hWnd, nCmdShow);

	return S_OK;
}


//--------------------------------------------------------------------------------------
// Called every time the application receives a message
//--------------------------------------------------------------------------------------

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	PAINTSTRUCT ps;
	HDC hdc;

	switch (message)
	{
	case WM_PAINT:
		hdc = BeginPaint(hWnd, &ps);
		EndPaint(hWnd, &ps);
		break;

	case WM_DESTROY:
		PostQuitMessage(0);
		break;


	case WM_INPUT:
	{
		HandleRawInput(hWnd, (HRAWINPUT&)lParam);
	}
		break;

	default:
		return DefWindowProc(hWnd, message, wParam, lParam);
	}

	return 0;
}

void release()
{
	graphics->release();

	SAFE_DELETE(graphics);

	SAFE_RELEASE(g_Device);
	SAFE_RELEASE(g_DeviceContext);
	SAFE_RELEASE(g_SwapChain);
	
	Cam->~Camera();
}