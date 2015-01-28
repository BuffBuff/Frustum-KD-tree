#pragma once


class ButtonInput
{
private:
	bool mPressed, nPressed, bPressed, vPressed, cPressed, ismPressed, isnPressed, isbPressed, isvPressed, iscPressed;

public:
	//ButtonInput();

	void SetMPressed(bool pressed){if(pressed){if(ismPressed == false){mPressed = !mPressed;}ismPressed = true;}else{ismPressed = false;}}//{mPressed = pressed;}
	void SetNPressed(bool pressed){if(pressed){if(isnPressed == false){nPressed = !nPressed;}isnPressed = true;}else{isnPressed = false;}}
	void SetBPressed(bool pressed){if(pressed){if(isbPressed == false){bPressed = !bPressed;}isbPressed = true;}else{isbPressed = false;}}
	void SetVPressed(bool pressed){if(pressed){if(isvPressed == false){vPressed = !vPressed;}isvPressed = true;}else{isvPressed = false;}}
	void SetCPressed(bool pressed){if(pressed){if(iscPressed == false){cPressed = !cPressed;}iscPressed = true;}else{iscPressed = false;}}
	bool GetMPressed() {return mPressed;}
	bool GetNPressed() {return nPressed;}
	bool GetBPressed() {return bPressed;}
	bool GetIsVPressed() {return isvPressed;}
	bool GetIsCPressed() {return iscPressed;}

};

