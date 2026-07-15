#include "ClassFactory.h"
#include "LipiTSF.h"

CClassFactory::CClassFactory() : _cRef(1)
{
    DllAddRef();
}

CClassFactory::~CClassFactory()
{
    DllRelease();
}

STDMETHODIMP CClassFactory::QueryInterface(REFIID riid, void **ppvObj)
{
    if (ppvObj == NULL) return E_INVALIDARG;
    *ppvObj = NULL;

    if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_IClassFactory))
    {
        *ppvObj = (IClassFactory *)this;
    }
    else
    {
        return E_NOINTERFACE;
    }
    AddRef();
    return S_OK;
}

STDMETHODIMP_(ULONG) CClassFactory::AddRef(void)
{
    return InterlockedIncrement(&_cRef);
}

STDMETHODIMP_(ULONG) CClassFactory::Release(void)
{
    ULONG cRef = InterlockedDecrement(&_cRef);
    if (0 == cRef)
    {
        delete this;
    }
    return cRef;
}

STDMETHODIMP CClassFactory::CreateInstance(IUnknown *pUnkOuter, REFIID riid, void **ppvObj)
{
    if (ppvObj == NULL) return E_INVALIDARG;
    *ppvObj = NULL;

    if (NULL != pUnkOuter) return CLASS_E_NOAGGREGATION;

    CLipiTSF *pLipiTSF = new CLipiTSF();
    if (pLipiTSF == NULL) return E_OUTOFMEMORY;

    HRESULT hr = pLipiTSF->QueryInterface(riid, ppvObj);
    pLipiTSF->Release();
    return hr;
}

STDMETHODIMP CClassFactory::LockServer(BOOL fLock)
{
    if (fLock)
        DllAddRef();
    else
        DllRelease();
    return S_OK;
}
