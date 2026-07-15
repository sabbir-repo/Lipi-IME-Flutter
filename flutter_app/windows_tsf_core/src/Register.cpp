#include "Globals.h"
#include <strsafe.h>

const WCHAR c_szInfoKeyPrefix[] = L"CLSID\\";
const WCHAR c_szInProcSvr32[] = L"InProcServer32";
const WCHAR c_szModelName[] = L"ThreadingModel";

BOOL RegisterServer()
{
    WCHAR szModule[MAX_PATH];
    if (GetModuleFileName(g_hInst, szModule, ARRAYSIZE(szModule)) == 0) return FALSE;

    WCHAR szKey[256];
    StringCchPrintf(szKey, ARRAYSIZE(szKey), L"CLSID\\{8D68E2F2-AE02-4D6F-9C14-A2D0C545E445}");
    
    HKEY hKey;
    if (RegCreateKeyEx(HKEY_CLASSES_ROOT, szKey, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL, &hKey, NULL) != ERROR_SUCCESS)
    {
        return FALSE;
    }
    
    RegSetValueEx(hKey, NULL, 0, REG_SZ, (const BYTE*)L"Lipi IME TSF", sizeof(L"Lipi IME TSF"));

    HKEY hSubKey;
    if (RegCreateKeyEx(hKey, c_szInProcSvr32, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL, &hSubKey, NULL) == ERROR_SUCCESS)
    {
        RegSetValueEx(hSubKey, NULL, 0, REG_SZ, (const BYTE*)szModule, (DWORD)((wcslen(szModule) + 1) * sizeof(WCHAR)));
        RegSetValueEx(hSubKey, c_szModelName, 0, REG_SZ, (const BYTE*)L"Apartment", sizeof(L"Apartment"));
        RegCloseKey(hSubKey);
    }

    RegCloseKey(hKey);
    return TRUE;
}

BOOL UnregisterServer()
{
    WCHAR szKey[256];
    StringCchPrintf(szKey, ARRAYSIZE(szKey), L"CLSID\\{8D68E2F2-AE02-4D6F-9C14-A2D0C545E445}\\InProcServer32");
    RegDeleteKey(HKEY_CLASSES_ROOT, szKey);

    StringCchPrintf(szKey, ARRAYSIZE(szKey), L"CLSID\\{8D68E2F2-AE02-4D6F-9C14-A2D0C545E445}");
    RegDeleteKey(HKEY_CLASSES_ROOT, szKey);
    
    return TRUE;
}

STDAPI DllRegisterServer(void)
{
    if (!RegisterServer()) return E_FAIL;
    
    // TODO: Register with ITfInputProcessorProfiles to add it to Language Bar

    return S_OK;
}

STDAPI DllUnregisterServer(void)
{
    // TODO: Unregister from ITfInputProcessorProfiles
    
    if (!UnregisterServer()) return E_FAIL;
    return S_OK;
}
