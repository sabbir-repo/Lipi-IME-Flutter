#include "LipiTSF.h"

CLipiTSF::CLipiTSF() : _cRef(1), _ptim(NULL), _tid(TF_CLIENTID_NULL), _pComposition(NULL), _isActive(true), _selectedIndex(0)
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
    
    BYTE kbd[256];
    GetKeyboardState(kbd);

    if ((kbd[VK_MENU] & 0x80) && wParam == 0x54) { // Alt+T
        *pfEaten = TRUE;
        return S_OK;
    }

    if ((kbd[VK_CONTROL] & 0x80) || (kbd[VK_MENU] & 0x80) || (kbd[VK_LWIN] & 0x80) || (kbd[VK_RWIN] & 0x80)) {
        *pfEaten = FALSE;
        return S_OK;
    }
    
    if (!_isActive) {
        *pfEaten = FALSE;
        return S_OK;
    }

    if (!_suggestions.empty() && (wParam == VK_UP || wParam == VK_DOWN)) {
        *pfEaten = TRUE;
        return S_OK;
    }

    wchar_t ch[2] = {0};
    HKL hklEnglish = LoadKeyboardLayout(L"00000409", KLF_NOTELLSHELL);
    ToUnicodeEx(wParam, MapVirtualKeyEx(wParam, MAPVK_VK_TO_VSC, hklEnglish), kbd, ch, 2, 0, hklEnglish);
    
    wchar_t c = ch[0];
    bool isLetter = (c >= L'a' && c <= L'z') || (c >= L'A' && c <= L'Z');
    bool isNumber = (c >= L'0' && c <= L'9');
    bool isPunctuation = (c != 0 && !isLetter && !isNumber && wParam != VK_BACK && wParam != VK_SPACE && wParam != VK_RETURN);
    
    if (isLetter || isNumber || isPunctuation ||
        (!_currentWord.empty() && (wParam == VK_BACK || wParam == VK_SPACE || wParam == VK_RETURN)))
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

    BYTE kbd[256];
    GetKeyboardState(kbd);

    if ((kbd[VK_MENU] & 0x80) && wParam == 0x54) { // Alt+T
        *pfEaten = TRUE;
        _isActive = !_isActive;
        if (!_isActive && !_currentWord.empty()) {
            _currentWord.clear(); // just clear internal state to avoid ghost chars
            _suggestions.clear();
            _ipc.SendMessage(L"HIDE");
        }
        return S_OK;
    }

    if ((kbd[VK_CONTROL] & 0x80) || (kbd[VK_MENU] & 0x80) || (kbd[VK_LWIN] & 0x80) || (kbd[VK_RWIN] & 0x80)) {
        *pfEaten = FALSE;
        return S_OK;
    }
    
    if (!_isActive) {
        *pfEaten = FALSE;
        return S_OK;
    }

    if (!_suggestions.empty() && (wParam == VK_UP || wParam == VK_DOWN)) {
        *pfEaten = TRUE;
        if (wParam == VK_DOWN) {
            _selectedIndex = (_selectedIndex + 1) % _suggestions.size();
        } else {
            _selectedIndex = (_selectedIndex - 1 + _suggestions.size()) % _suggestions.size();
        }
        _HandleKeystroke(pic, 0); // Special token to update selection
        return S_OK;
    }

    wchar_t ch[2] = {0};
    HKL hklEnglish = LoadKeyboardLayout(L"00000409", KLF_NOTELLSHELL);
    ToUnicodeEx(wParam, MapVirtualKeyEx(wParam, MAPVK_VK_TO_VSC, hklEnglish), kbd, ch, 2, 0, hklEnglish);
    
    wchar_t c = ch[0];
    bool isLetter = (c >= L'a' && c <= L'z') || (c >= L'A' && c <= L'Z');
    bool isNumber = (c >= L'0' && c <= L'9');
    bool isPunctuation = (c != 0 && !isLetter && !isNumber && wParam != VK_BACK && wParam != VK_SPACE && wParam != VK_RETURN);

    if (isLetter || isNumber || isPunctuation ||
        (!_currentWord.empty() && (wParam == VK_BACK || wParam == VK_SPACE || wParam == VK_RETURN)))
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
    bool isTerminator = false;
    wchar_t termChar = 0;
    
    if (wParam != 0) {
        BYTE kbd[256];
        GetKeyboardState(kbd);
        wchar_t ch[2] = {0};
        HKL hklEnglish = LoadKeyboardLayout(L"00000409", KLF_NOTELLSHELL);
        ToUnicodeEx(wParam, MapVirtualKeyEx(wParam, MAPVK_VK_TO_VSC, hklEnglish), kbd, ch, 2, 0, hklEnglish);
        
        wchar_t c = ch[0];
        bool isLetter = (c >= L'a' && c <= L'z') || (c >= L'A' && c <= L'Z');
        bool isNumber = (c >= L'0' && c <= L'9');
        bool isPunctuation = (c != 0 && !isLetter && !isNumber && wParam != VK_BACK && wParam != VK_SPACE && wParam != VK_RETURN);
        isTerminator = (wParam == VK_SPACE || wParam == VK_RETURN || isPunctuation);

        if (wParam == VK_SPACE) termChar = L' ';
        else if (wParam == VK_RETURN) termChar = L'\n';
        else if (isPunctuation) {
            termChar = c;
            if (termChar == L'.') termChar = L'\x0964'; // Convert dot to Dari
        }

        if (wParam == VK_BACK) {
            if (!_currentWord.empty()) _currentWord.pop_back();
        } else if (!isTerminator) {
            if (c != 0) _currentWord += c;
        }
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

        if (wParam != 0 && termChar != 0 && termChar != L' ' && termChar != L'\n') {
            std::wstring punctStr(1, termChar);
            ITfInsertAtSelection *pInsert = NULL;
            if (SUCCEEDED(pic->QueryInterface(IID_ITfInsertAtSelection, (void **)&pInsert))) {
                ITfRange *pRangeInsert = NULL;
                pInsert->InsertTextAtSelection(ec, 0, punctStr.c_str(), punctStr.length(), &pRangeInsert);
                if (pRangeInsert) {
                    ITfRange *pSelectionRange = NULL;
                    if (SUCCEEDED(pRangeInsert->Clone(&pSelectionRange))) {
                        pSelectionRange->Collapse(ec, TF_ANCHOR_END);
                        TF_SELECTION tfSelection;
                        tfSelection.range = pSelectionRange;
                        tfSelection.style.ase = TF_AE_NONE;
                        tfSelection.style.fInterimChar = FALSE;
                        pic->SetSelection(ec, 1, &tfSelection);
                        pSelectionRange->Release();
                    }
                    pRangeInsert->Release();
                }
                pInsert->Release();
            }
        }
        
        _suggestions.clear();
        _selectedIndex = 0;
        _ipc.SendMessage(L"HIDE");
        return S_OK;
    }

    if (wParam != 0 && !isTerminator) {
        std::wstring request = L"bn-t-i0-und|" + _currentWord;
        std::wstring response;
        
        _suggestions.clear();
        _selectedIndex = 0;
        
        if (_ipc.SendMessage(request) && _ipc.ReceiveMessage(response)) {
            size_t pos = 0;
            while ((pos = response.find(L"|")) != std::wstring::npos) {
                std::wstring token = response.substr(0, pos);
                if (!token.empty()) _suggestions.push_back(token);
                response.erase(0, pos + 1);
            }
            if (!response.empty()) _suggestions.push_back(response);
        }
    }

    if (isTerminator && !_suggestions.empty()) {
        if (_selectedIndex < 0 || _selectedIndex >= (int)_suggestions.size()) _selectedIndex = 0;
        textToInsert = _suggestions[_selectedIndex];
    } else {
        textToInsert = _currentWord;
    }

    if (termChar != 0) {
        textToInsert += termChar;
    }

    ITfRange *pFinalRange = NULL;
    if (_pComposition == NULL) {
        ITfInsertAtSelection *pInsert = NULL;
        if (SUCCEEDED(pic->QueryInterface(IID_ITfInsertAtSelection, (void **)&pInsert))) {
            ITfRange *pRangeInsert = NULL;
            pInsert->InsertTextAtSelection(ec, 0, textToInsert.c_str(), textToInsert.length(), &pRangeInsert);
            if (pRangeInsert) {
                ITfContextComposition *pContextComp = NULL;
                if (SUCCEEDED(pic->QueryInterface(IID_ITfContextComposition, (void **)&pContextComp))) {
                    pContextComp->StartComposition(ec, pRangeInsert, this, &_pComposition);
                    pContextComp->Release();
                }

                ITfRange *pSelectionRange = NULL;
                if (SUCCEEDED(pRangeInsert->Clone(&pSelectionRange))) {
                    pSelectionRange->Collapse(ec, TF_ANCHOR_END);
                    TF_SELECTION tfSelection;
                    tfSelection.range = pSelectionRange;
                    tfSelection.style.ase = TF_AE_NONE;
                    tfSelection.style.fInterimChar = FALSE;
                    pic->SetSelection(ec, 1, &tfSelection);
                    pSelectionRange->Release();
                }

                pFinalRange = pRangeInsert;
            }
            pInsert->Release();
        }
    } else {
        ITfRange *pRange = NULL;
        if (SUCCEEDED(_pComposition->GetRange(&pRange))) {
            pRange->SetText(ec, 0, textToInsert.c_str(), textToInsert.length());
            
            ITfRange *pSelectionRange = NULL;
            if (SUCCEEDED(pRange->Clone(&pSelectionRange))) {
                pSelectionRange->Collapse(ec, TF_ANCHOR_END);
                TF_SELECTION tfSelection;
                tfSelection.range = pSelectionRange;
                tfSelection.style.ase = TF_AE_NONE;
                tfSelection.style.fInterimChar = FALSE;
                pic->SetSelection(ec, 1, &tfSelection);
                pSelectionRange->Release();
            }

            pFinalRange = pRange;
        }
    }

    if (isTerminator) {
        if (_pComposition) {
            ITfComposition *pComp = _pComposition;
            _pComposition = NULL;
            pComp->EndComposition(ec);
            pComp->Release();
        }
        _currentWord.clear();
        _suggestions.clear();
        _selectedIndex = 0;
        _ipc.SendMessage(L"HIDE");
    } else if (!_suggestions.empty() && pFinalRange) {
        // Calculate caret position and show UI
        int x = 0, y = 0;
        ITfContextView *pView = NULL;
        if (SUCCEEDED(pic->GetActiveView(&pView))) {
            RECT rc;
            BOOL fClipped;
            if (SUCCEEDED(pView->GetTextExt(ec, pFinalRange, &rc, &fClipped))) {
                x = rc.left;
                y = rc.bottom;
            }
            pView->Release();
        }

        std::wstring showReq = L"SHOW|" + std::to_wstring(x) + L"|" + std::to_wstring(y) + L"|" + std::to_wstring(_selectedIndex) + L"|" + _currentWord;
        for (const auto& s : _suggestions) {
            showReq += L"|" + s;
        }
        std::wstring showResp;
        _ipc.SendMessage(showReq);
        _ipc.ReceiveMessage(showResp);
    }
    
    if (pFinalRange) {
        if (_pComposition == NULL) { // only release if we didn't get it from GetRange
            pFinalRange->Release();
        }
    }

    return S_OK;
}
