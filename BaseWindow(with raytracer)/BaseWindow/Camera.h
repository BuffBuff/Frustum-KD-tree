#ifndef _XCAMERA
#define _XCAMERA

#include "stdafx.h"
#include "hrTimer.h"
#include <d3d.h>
#include <d3d11.h>
#include <DirectXMath.h>
#include <DirectXPackedVector.h>

#define TWO_PI 6.283185307179586476925286766559
#define DEG_TO_RAD 0.01745329251994329576923690768489

using namespace DirectX;

class Camera
{
private:
	XMFLOAT3	m_position;
	XMFLOAT3	m_lookAt;
	XMFLOAT3	m_up;
	XMFLOAT3	m_forward;
	XMFLOAT3	m_right;

	XMFLOAT4X4	m_viewMatrix;
	XMFLOAT4X4	m_projectionMatrix;
	XMFLOAT4X4	m_rotationMatrix;

	float m_roll;
	float m_pitch;
	float m_yaw;

	int movementToggles[6];	//forward:back:left:right:up:down
	float movementSpeed;

	timer m_camTimer;

protected:
public:
	void setPerspectiveProjectionLH(float fov, float width, float height, float zNear, float zFar);
	
private:
	void updateView();

protected:
public:
	Camera();
	~Camera();

	void update() ;

	bool init(unsigned int clientWidth, unsigned int clientHeight)				;
	void setPositionAndView(float x, float y, float z, float hDeg, float pDeg)	;
	void transposeMatrix(XMFLOAT4X4& _mat4x4);

	void setMovementToggle(int i, int v)			;
	void adjustHeadingPitch(float hRad, float pRad) ;

	XMFLOAT4X4	getViewMatrix(){ return m_viewMatrix; }
	XMFLOAT4X4	getProjectionMatrix(){ return m_projectionMatrix; }
	XMFLOAT3		getCameraPosition(){ return m_position; }
};

#endif