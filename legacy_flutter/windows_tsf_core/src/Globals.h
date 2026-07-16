#pragma once
#include <windows.h>
#include <initguid.h>
#include <msctf.h>

// CLSID for our Text Input Processor
// {8D68E2F2-AE02-4D6F-9C14-A2D0C545E445}
DEFINE_GUID(CLSID_LipiTSF, 
0x8d68e2f2, 0xae02, 0x4d6f, 0x9c, 0x14, 0xa2, 0xd0, 0xc5, 0x45, 0xe4, 0x45);

// Language Profile GUID
// {D2765A2C-9E40-41BC-A5BA-F1352A9D6A6A}
DEFINE_GUID(GUID_PROFILE_LipiTSF, 
0xd2765a2c, 0x9e40, 0x41bc, 0xa5, 0xba, 0xf1, 0x35, 0x2a, 0x9d, 0x6a, 0x6a);

extern HINSTANCE g_hInst;
extern LONG g_cRefDll;

void DllAddRef();
void DllRelease();
