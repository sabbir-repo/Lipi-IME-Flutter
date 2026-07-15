#include "Globals.h"
#include "ClassFactory.h"

BOOL WINAPI DllMain(HINSTANCE hInstance, DWORD dwReason, LPVOID pvReserved)
{
    switch (dwReason)
    {
    case DLL_PROCESS_ATTACH:
        g_hInst = hInstance;
        DisableThreadLibraryCalls(hInstance);
        break;
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}

STDAPI DllGetClassObject(REFCLSID rclsid, REFIID riid, void **ppvObj)
{
    if (ppvObj == NULL) return E_INVALIDARG;
    *ppvObj = NULL;

    if (IsEqualIID(rclsid, CLSID_LipiTSF))
    {
        CClassFactory *pcf = new CClassFactory();
        if (pcf == NULL) return E_OUTOFMEMORY;
        HRESULT hr = pcf->QueryInterface(riid, ppvObj);
        pcf->Release();
        return hr;
    }

    return CLASS_E_CLASSNOTAVAILABLE;
}

STDAPI DllCanUnloadNow()
{
    if (g_cRefDll == 0) return S_OK;
    return S_FALSE;
}
