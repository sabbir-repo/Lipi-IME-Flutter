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
    else if (IsEqualIID(riid, IID_ITfKeyEventSink))
    {
        *ppvObj = (ITfKeyEventSink *)this;
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

    _InitKeyEventSink();
    _ipc.Connect();

    return S_OK;
}

STDMETHODIMP CLipiTSF::Deactivate()
{
    _UninitKeyEventSink();
    _ipc.Disconnect();

    if (_ptim)
    {
        _ptim->Release();
        _ptim = NULL;
    }
    _tid = TF_CLIENTID_NULL;
    return S_OK;
}

void CLipiTSF::_InitKeyEventSink()
{
    ITfKeystrokeMgr *pKeystrokeMgr = NULL;
    if (SUCCEEDED(_ptim->QueryInterface(IID_ITfKeystrokeMgr, (void **)&pKeystrokeMgr)))
    {
        pKeystrokeMgr->AdviseKeyEventSink(_tid, (ITfKeyEventSink *)this, TRUE);
        pKeystrokeMgr->Release();
    }
}

void CLipiTSF::_UninitKeyEventSink()
{
    ITfKeystrokeMgr *pKeystrokeMgr = NULL;
    if (SUCCEEDED(_ptim->QueryInterface(IID_ITfKeystrokeMgr, (void **)&pKeystrokeMgr)))
    {
        pKeystrokeMgr->UnadviseKeyEventSink(_tid);
        pKeystrokeMgr->Release();
    }
}

STDMETHODIMP CLipiTSF::OnSetFocus(BOOL fForeground)
{
    return S_OK;
}

STDMETHODIMP CLipiTSF::OnTestKeyDown(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten)
{
    if (pfEaten == NULL) return E_INVALIDARG;
    
    // Test if we should eat this key. 
    // We only care about A-Z for typing Bengali. Let's eat A-Z for now.
    if (wParam >= 'A' && wParam <= 'Z')
    {
        *pfEaten = TRUE;
        return S_OK;
    }

    *pfEaten = FALSE;
    return S_OK;
}

STDMETHODIMP CLipiTSF::OnKeyDown(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten)
{
    if (pfEaten == NULL) return E_INVALIDARG;

    if (wParam >= 'A' && wParam <= 'Z')
    {
        *pfEaten = TRUE;
        
        // Send key to Flutter
        std::wstring msg = L"KEY:";
        msg += (wchar_t)wParam;
        _ipc.SendMessage(msg);

        return S_OK;
    }

    *pfEaten = FALSE;
    return S_OK;
}

STDMETHODIMP CLipiTSF::OnTestKeyUp(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten)
{
    if (pfEaten == NULL) return E_INVALIDARG;
    *pfEaten = FALSE;
    return S_OK;
}

STDMETHODIMP CLipiTSF::OnKeyUp(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten)
{
    if (pfEaten == NULL) return E_INVALIDARG;
    *pfEaten = FALSE;
    return S_OK;
}

STDMETHODIMP CLipiTSF::OnPreservedKey(ITfContext *pic, REFGUID rguid, BOOL *pfEaten)
{
    if (pfEaten == NULL) return E_INVALIDARG;
    *pfEaten = FALSE;
    return S_OK;
}
