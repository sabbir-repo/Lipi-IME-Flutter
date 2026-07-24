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

BOOL RegisterCategories()
{
    ITfCategoryMgr *pCategoryMgr;
    HRESULT hr = CoCreateInstance(CLSID_TF_CategoryMgr, NULL, CLSCTX_INPROC_SERVER, IID_ITfCategoryMgr, (void**)&pCategoryMgr);
    if (FAILED(hr)) return FALSE;

    hr = pCategoryMgr->RegisterCategory(CLSID_LipiTSF, GUID_TFCAT_TIP_KEYBOARD, CLSID_LipiTSF);
    
    pCategoryMgr->Release();
    return SUCCEEDED(hr);
}

BOOL UnregisterCategories()
{
    ITfCategoryMgr *pCategoryMgr;
    HRESULT hr = CoCreateInstance(CLSID_TF_CategoryMgr, NULL, CLSCTX_INPROC_SERVER, IID_ITfCategoryMgr, (void**)&pCategoryMgr);
    if (FAILED(hr)) return FALSE;

    hr = pCategoryMgr->UnregisterCategory(CLSID_LipiTSF, GUID_TFCAT_TIP_KEYBOARD, CLSID_LipiTSF);
    
    pCategoryMgr->Release();
    return SUCCEEDED(hr);
}

BOOL RegisterProfiles()
{
    ITfInputProcessorProfileMgr *pProfileMgr;
    HRESULT hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, NULL, CLSCTX_INPROC_SERVER, IID_ITfInputProcessorProfileMgr, (void**)&pProfileMgr);
    if (FAILED(hr)) return FALSE;

    const WCHAR c_szProfileName[] = L"Lipi IME (Bengali)";
    
    hr = pProfileMgr->RegisterProfile(
        CLSID_LipiTSF,
        MAKELANGID(LANG_BENGALI, SUBLANG_BENGALI_BANGLADESH),
        GUID_PROFILE_LipiTSF,
        c_szProfileName,
        (ULONG)wcslen(c_szProfileName),
        L"", // icon file
        0, // icon length
        0, 0, 0, 1, 0);

    if (SUCCEEDED(hr))
    {
        // Substitute keyboard layout = English (US).
        // Without this, when the TIP does not eat keys (excluded apps or
        // IME toggled off), Windows falls back to the default Bengali
        // layout and Bangla characters get typed instead of English.
        HKEY hSubstKey;
        const WCHAR c_szSubstPath[] =
            L"SOFTWARE\\Microsoft\\CTF\\TIP\\{8D68E2F2-AE02-4D6F-9C14-A2D0C545E445}"
            L"\\LanguageProfile\\0x00000845\\{D2765A2C-9E40-41BC-A5BA-F1352A9D6A6A}";
        if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, c_szSubstPath, 0, KEY_SET_VALUE, &hSubstKey) == ERROR_SUCCESS)
        {
            DWORD dwLayout = 0x00000409; // en-US keyboard layout
            RegSetValueEx(hSubstKey, L"SubstituteLayout", 0, REG_DWORD, (const BYTE*)&dwLayout, sizeof(dwLayout));
            RegCloseKey(hSubstKey);
        }
    }

    pProfileMgr->Release();
    return SUCCEEDED(hr);
}

BOOL UnregisterProfiles()
{
    ITfInputProcessorProfileMgr *pProfileMgr;
    HRESULT hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, NULL, CLSCTX_INPROC_SERVER, IID_ITfInputProcessorProfileMgr, (void**)&pProfileMgr);
    if (FAILED(hr)) return FALSE;

    hr = pProfileMgr->UnregisterProfile(CLSID_LipiTSF, MAKELANGID(LANG_BENGALI, SUBLANG_BENGALI_BANGLADESH), GUID_PROFILE_LipiTSF, 0);

    pProfileMgr->Release();
    return SUCCEEDED(hr);
}

STDAPI DllRegisterServer(void)
{
    if (!RegisterServer()) return E_FAIL;
    if (!RegisterCategories()) return E_FAIL;
    if (!RegisterProfiles()) return E_FAIL;

    return S_OK;
}

STDAPI DllUnregisterServer(void)
{
    UnregisterProfiles();
    UnregisterCategories();
    if (!UnregisterServer()) return E_FAIL;
    return S_OK;
}
