#include "LipiTSF.h"

CLipiTSF::CLipiTSF() : _cRef(1), _ptim(NULL), _tid(TF_CLIENTID_NULL), _pComposition(NULL)
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
    else if (IsEqualIID(riid, IID_ITfCompositionSink))
    {
        *ppvObj = (ITfCompositionSink *)this;
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
    
    bool isLetter = (wParam >= 'A' && wParam <= 'Z');
    if (isLetter || (!_currentWord.empty() && (wParam == VK_BACK || wParam == VK_SPACE || wParam == VK_RETURN)))
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

    bool isLetter = (wParam >= 'A' && wParam <= 'Z');
    if (isLetter || (!_currentWord.empty() && (wParam == VK_BACK || wParam == VK_SPACE || wParam == VK_RETURN)))
    {
        *pfEaten = TRUE;
        _HandleKeystroke(pic, wParam);
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

STDMETHODIMP CLipiTSF::OnCompositionTerminated(TfEditCookie ecWrite, ITfComposition *pComposition)
{
    if (_pComposition == pComposition)
    {
        _pComposition->Release();
        _pComposition = NULL;
    }
    _currentWord.clear();
    return S_OK;
}

class CLipiEditSession : public ITfEditSession {
public:
    CLipiEditSession(CLipiTSF *pTsf, ITfContext *pic, WPARAM wParam) 
        : _cRef(1), _pTsf(pTsf), _pic(pic), _wParam(wParam) {
        _pic->AddRef();
        _pTsf->AddRef();
    }
    ~CLipiEditSession() {
        _pic->Release();
        _pTsf->Release();
    }

    STDMETHODIMP QueryInterface(REFIID riid, void **ppvObj) {
        if (ppvObj == NULL) return E_INVALIDARG;
        *ppvObj = NULL;
        if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_ITfEditSession)) {
            *ppvObj = (ITfEditSession *)this;
        } else {
            return E_NOINTERFACE;
        }
        AddRef();
        return S_OK;
    }
    STDMETHODIMP_(ULONG) AddRef(void) { return InterlockedIncrement(&_cRef); }
    STDMETHODIMP_(ULONG) Release(void) {
        ULONG cRef = InterlockedDecrement(&_cRef);
        if (0 == cRef) delete this;
        return cRef;
    }

    STDMETHODIMP DoEditSession(TfEditCookie ec) {
        return _pTsf->_DoEditSession(ec, _pic, _wParam);
    }
private:
    LONG _cRef;
    CLipiTSF *_pTsf;
    ITfContext *_pic;
    WPARAM _wParam;
};

void CLipiTSF::_HandleKeystroke(ITfContext *pic, WPARAM wParam) {
    CLipiEditSession *pEditSession = new CLipiEditSession(this, pic, wParam);
    HRESULT hrSession;
    pic->RequestEditSession(_tid, pEditSession, TF_ES_SYNC | TF_ES_READWRITE, &hrSession);
    pEditSession->Release();
}

HRESULT CLipiTSF::_DoEditSession(TfEditCookie ec, ITfContext *pic, WPARAM wParam) {
    if (wParam == VK_BACK) {
        if (!_currentWord.empty()) _currentWord.pop_back();
    } else if (wParam != VK_SPACE && wParam != VK_RETURN) {
        BYTE kbd[256];
        GetKeyboardState(kbd);
        wchar_t ch[2] = {0};
        ToUnicode(wParam, MapVirtualKey(wParam, MAPVK_VK_TO_VSC), kbd, ch, 2, 0);
        if (ch[0] != 0) _currentWord += ch[0];
    }

    std::wstring textToInsert;

    if (_currentWord.empty()) {
        if (_pComposition) {
            ITfRange *pRange = NULL;
            if (SUCCEEDED(_pComposition->GetRange(&pRange))) {
                pRange->SetText(ec, 0, L"", 0);
                pRange->Release();
            }
            ITfComposition *pComp = _pComposition;
            _pComposition = NULL;
            pComp->EndComposition(ec);
            pComp->Release();
        }
        return S_OK;
    }

    std::wstring request = L"bn-t-i0-und|" + _currentWord;
    std::wstring response;
    
    if (_ipc.SendMessage(request) && _ipc.ReceiveMessage(response)) {
        size_t firstQuote = response.find(L"\"");
        if (firstQuote != std::wstring::npos) {
            size_t secondQuote = response.find(L"\"", firstQuote + 1);
            if (secondQuote != std::wstring::npos) {
                textToInsert = response.substr(firstQuote + 1, secondQuote - firstQuote - 1);
            }
        }
    }

    if (textToInsert.empty()) {
        textToInsert = _currentWord; // fallback
    }

    if (wParam == VK_SPACE) textToInsert += L" ";
    else if (wParam == VK_RETURN) textToInsert += L"\n";

    if (_pComposition == NULL) {
        ITfInsertAtSelection *pInsert = NULL;
        if (SUCCEEDED(pic->QueryInterface(IID_ITfInsertAtSelection, (void **)&pInsert))) {
            ITfRange *pRangeInsert = NULL;
            pInsert->InsertTextAtSelection(ec, TF_IAS_NOQUERY, textToInsert.c_str(), textToInsert.length(), &pRangeInsert);
            
            if (pRangeInsert) {
                ITfContextComposition *pContextComp = NULL;
                if (SUCCEEDED(pic->QueryInterface(IID_ITfContextComposition, (void **)&pContextComp))) {
                    pContextComp->StartComposition(ec, pRangeInsert, this, &_pComposition);
                    pContextComp->Release();
                }
                pRangeInsert->Release();
            }
            pInsert->Release();
        }
    } else {
        ITfRange *pRange = NULL;
        if (SUCCEEDED(_pComposition->GetRange(&pRange))) {
            pRange->SetText(ec, 0, textToInsert.c_str(), textToInsert.length());
            pRange->Release();
        }
    }

    if (wParam == VK_SPACE || wParam == VK_RETURN) {
        if (_pComposition) {
            ITfComposition *pComp = _pComposition;
            _pComposition = NULL;
            pComp->EndComposition(ec);
            pComp->Release();
        }
        _currentWord.clear();
    }

    return S_OK;
}
