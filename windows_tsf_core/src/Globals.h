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

// Preserved Key GUID for Alt+R (Force Fetch API)
// {C6F4B231-1B8A-4F81-8B90-D672F41E1C55}
DEFINE_GUID(GUID_PRESERVEDKEY_FORCEFETCH,
0xc6f4b231, 0x1b8a, 0x4f81, 0x8b, 0x90, 0xd6, 0x72, 0xf4, 0x1e, 0x1c, 0x55);

// Preserved Key GUID for Alt+T (Toggle IME)
// {F49B90D8-44A5-4C3D-B1A3-34827F6D43B1}
DEFINE_GUID(GUID_PRESERVEDKEY_TOGGLE,
0xf49b90d8, 0x44a5, 0x4c3d, 0xb1, 0xa3, 0x34, 0x82, 0x7f, 0x6d, 0x43, 0xb1);

extern HINSTANCE g_hInst;
extern LONG g_cRefDll;

void DllAddRef();
void DllRelease();

