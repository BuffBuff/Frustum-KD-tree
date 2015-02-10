#include "Camera.h"
Camera::Camera()
: m_lookAt(XMFLOAT3(0, 0, 1)), m_position(XMFLOAT3(0, 0, 0)), m_up(XMFLOAT3(0, 1, 0)),
m_roll(0.0f), m_pitch(0.0f), m_yaw(0.0f),
m_forward(0.0f, 0.0f, 1.0f), m_right(1.0f, 0.0f, 0.0f),
movementSpeed(10.0f)
{
	XMStoreFloat4x4(&m_viewMatrix, XMMatrixIdentity());
	XMStoreFloat4x4(&m_projectionMatrix, XMMatrixIdentity());
	XMStoreFloat4x4(&m_rotationMatrix, XMMatrixIdentity());

	movementToggles[0] = 0;
	movementToggles[1] = 0;
	movementToggles[2] = 0;
	movementToggles[3] = 0;
	movementToggles[4] = 0;
	movementToggles[5] = 0;
}

Camera::~Camera()
{

}

bool Camera::init(unsigned int clientWidth, unsigned int clientHeight)
{
	setPerspectiveProjectionLH(45.0f, static_cast<float>(clientWidth), static_cast<float>(clientHeight), 1.0f, 100000.0f);
	return true;
}

void Camera::setPositionAndView(float x, float y, float z, float hDeg, float pDeg)
{
	m_position.x = x;
	m_position.y = y;
	m_position.z = z;

	adjustHeadingPitch(hDeg * (float)DEG_TO_RAD, pDeg * (float)DEG_TO_RAD);

	updateView();
}

void Camera::setPerspectiveProjectionLH(float fov, float width, float height, float zNear, float zFar)
{
	// projection matrix
	XMStoreFloat4x4(&m_projectionMatrix, XMMatrixPerspectiveFovLH(fov * (float)DEG_TO_RAD, width / height, zNear, zFar));
	XMStoreFloat4x4(&m_viewMatrix, XMMatrixLookAtLH(XMLoadFloat3(&m_position), XMLoadFloat3(&m_lookAt), XMLoadFloat3(&m_up)));
	transposeMatrix(m_projectionMatrix);
	transposeMatrix(m_viewMatrix);
	adjustHeadingPitch(0, 0);
}

void Camera::transposeMatrix(XMFLOAT4X4& mat)
{
	XMMATRIX transpose = XMMatrixTranspose(XMLoadFloat4x4(&mat));
	XMStoreFloat4x4(&mat, transpose);
}

void Camera::updateView()
{
	//XMStoreFloat3(&m_lookAt, XMVector3Normalize(XMLoadFloat3(&m_lookAt)));
	// rotate
	XMStoreFloat4x4(&m_rotationMatrix, XMMatrixRotationRollPitchYaw(m_pitch, m_yaw, m_roll));

	// transform
	const XMFLOAT3 dV = XMFLOAT3(0, 0, 1);
	const XMFLOAT3 dU = XMFLOAT3(0, 1, 0);
	XMStoreFloat3(&m_lookAt, XMVector3TransformCoord(XMLoadFloat3(&dV), XMLoadFloat4x4(&m_rotationMatrix)));
	XMStoreFloat3(&m_up, XMVector3TransformCoord(XMLoadFloat3(&dU), XMLoadFloat4x4(&m_rotationMatrix)));

	// forward & right
	XMStoreFloat3(&m_forward, XMVector3Normalize(XMLoadFloat3(&m_lookAt)));
	XMStoreFloat3(&m_right, XMVector3Cross(XMLoadFloat3(&m_up), XMLoadFloat3(&m_lookAt)));
	XMStoreFloat3(&m_right, XMVector3Normalize(XMLoadFloat3(&m_right)));


	// update lookAt
	XMStoreFloat3(&m_lookAt, XMLoadFloat3(&m_position) + XMLoadFloat3(&m_lookAt));

	// update viewMatrix
	XMStoreFloat4x4(&m_viewMatrix, XMMatrixLookAtLH(XMLoadFloat3(&m_position), XMLoadFloat3(&m_lookAt), XMLoadFloat3(&m_up)));
	transposeMatrix(m_viewMatrix);
}

void Camera::update()
{
	float t = (float)m_camTimer.getElapsedTimeSeconds();

	XMVECTOR nPos = (float)t * (movementToggles[0] + movementToggles[1]) * movementSpeed * XMLoadFloat3(&m_forward) +
		(float)t * (movementToggles[2] + movementToggles[3]) * movementSpeed * XMLoadFloat3(&m_right) +
		(float)t * (movementToggles[4] + movementToggles[5]) * movementSpeed * XMLoadFloat3(&m_up);

	XMStoreFloat3(&m_position, nPos + XMLoadFloat3(&m_position));

	updateView();

	m_camTimer.reset();
}

void Camera::setMovementToggle(int i, int v)
{
	movementToggles[i] = v;
}

void Camera::adjustHeadingPitch(float hRad, float pRad)
{
	m_yaw += hRad;
	m_pitch += pRad;

	//value clamping - keep heading and pitch between 0 and 2 pi
	if (m_yaw > TWO_PI) m_yaw -= (float)TWO_PI;
	else if (m_yaw < 0) m_yaw = (float)TWO_PI + m_yaw;

	if (m_pitch > TWO_PI) m_pitch -= (float)TWO_PI;
	else if (m_pitch < 0) m_pitch = (float)TWO_PI + m_pitch;
}
