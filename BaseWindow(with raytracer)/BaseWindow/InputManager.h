#ifndef _RAWINPUT
#define _RAWINPUT
#include "Camera.h"  //Gillar inte detta då det inte behövdes tidigare
#include "ButtonInput.h"

extern Camera* Cam;
extern ButtonInput* buttonInput;

//register keyboard mouse as input devices!
bool RegisterInputDevices( HWND &hWnd )
{
	RAWINPUTDEVICE inputDevices[2];
        
	//adds mouse and allow legacy messages
	inputDevices[0].usUsagePage = 0x01; 
	inputDevices[0].usUsage = 0x02; 
	inputDevices[0].dwFlags = 0;   
	inputDevices[0].hwndTarget = 0;

	//adds keyboard and allow legacy messages
	inputDevices[1].usUsagePage = 0x01; 
	inputDevices[1].usUsage = 0x06; 
	inputDevices[1].dwFlags = 0;   
	inputDevices[1].hwndTarget = 0;

	if ( RegisterRawInputDevices(inputDevices, 2, sizeof(inputDevices[0]) ) == FALSE ) 
	{
		return false;
	}

	return true;
}

void inline HandleRawInput( HWND &hWnd, HRAWINPUT &lParam )
{
	//get raw input data buffer size
	UINT dbSize;
	GetRawInputData( lParam, RID_INPUT, NULL, &dbSize,sizeof(RAWINPUTHEADER) );
    

	//allocate memory for raw input data and get data
	BYTE* buffer = new BYTE[dbSize];    
	GetRawInputData((HRAWINPUT)lParam, RID_INPUT, buffer, &dbSize, sizeof(RAWINPUTHEADER) );
	RAWINPUT* raw = (RAWINPUT*)buffer;
	
	// Handle Keyboard Input
	//---------------------------------------------------------------------------
	if (raw->header.dwType == RIM_TYPEKEYBOARD) 
	{
		switch( raw->data.keyboard.Message )
		{
			//key up
			case WM_KEYUP : 
				switch ( raw->data.keyboard.VKey )
				{
					case 'W' : Cam->setMovementToggle( 0, 0 );
					break;

					case 'S' : Cam->setMovementToggle( 1, 0 );
					break;

					case 'A' : Cam->setMovementToggle( 2, 0 );
					break;

					case 'D' : Cam->setMovementToggle( 3, 0 );
					break;

					case 'M' : buttonInput->SetMPressed(false);
					break;
					
					case 'N' : buttonInput->SetNPressed(false);
					break;
					
					case 'B' : buttonInput->SetBPressed(false);
					break;

					case 'V' : buttonInput->SetVPressed(false);
					break;

					case 'C' : buttonInput->SetCPressed(false);
					break;
				}
			break;

			//key down
			case WM_KEYDOWN : 
				switch ( raw->data.keyboard.VKey )
				{
					case VK_ESCAPE : PostQuitMessage(0);
					break;

					case 'W' : Cam->setMovementToggle( 0, 1 );
					break;

					case 'S' : Cam->setMovementToggle( 1, -1 );
					break;

					case 'A' : Cam->setMovementToggle( 2, -1 );
					break;

					case 'D' : Cam->setMovementToggle( 3, 1 );
					break;

					case 'M' : buttonInput->SetMPressed(true);
					break;

					case 'N' : buttonInput->SetNPressed(true);
					break;
					
					case 'B' : buttonInput->SetBPressed(true);
					break;

					case 'V' : buttonInput->SetVPressed(true);
					break;

					case 'C' : buttonInput->SetCPressed(true);
					break;
				}
			break;
		}
	}
	
	// Handle Mouse Input
	//---------------------------------------------------------------------------
	else if (raw->header.dwType == RIM_TYPEMOUSE) 
	{
		//mouse camera control
		Cam->adjustHeadingPitch( 0.0025f * raw->data.mouse.lLastX, 0.0025f * raw->data.mouse.lLastY );				
		
	}

	//free allocated memory
	delete[] buffer;

}

#endif