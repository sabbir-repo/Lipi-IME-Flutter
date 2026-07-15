#include "LipiTSF.h"

CLipiTSF::CLipiTSF() : _cRef(1), _ptim(NULL), _tid(TF_CLIENTID_NULL)
{
    DllAddRef();
}

CLipiTSF::~CLipiTSF()
{
    DllRelease();
}

STDMETHODIMP CLipiTSF::QueryInterface(REFIID riid, void **ppvObj)
{
    if (ppvObj == NULL) return E_INVALIDARG;
    *ppvObj = NULL;

    if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_ITfTextInputProcessor))
    {
        *ppvObj = (ITfTextInputProcessor *)this;
    }
    else
    {
        return E_NOINTERFACE;
    }

    AddRef();
    return S_OK;
}

STDMETHODIMP_(ULONG) CLipiTSF::AddRef(void)
{
    return InterlockedIncrement(&_cRef);
}

STDMETHODIMP_(ULONG) CLipiTSF::Release(void)
{
    ULONG cRef = InterlockedDecrement(&_cRef);
    if (0 == cRef)
    {
        delete this;
    }
    return cRef;
}

STDMETHODIMP CLipiTSF::Activate(ITfThreadMgr *ptim, TfClientId tid)
{
    _ptim = ptim;
    _ptim->AddRef();
    _tid = tid;

    // TODO: Init event sinks, set up named pipe client here

    return S_OK;
}

STDMETHODIMP CLipiTSF::Deactivate()
{
    // TODO: Cleanup event sinks, disconnect named pipe

    if (_ptim)
    {
        _ptim->Release();
        _ptim = NULL;
    }
    _tid = TF_CLIENTID_NULL;
    return S_OK;
}
