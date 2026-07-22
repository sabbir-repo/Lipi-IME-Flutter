#pragma once
#include "Globals.h"
#include "IpcClient.h"
#include <vector>

class CLipiTSF : public ITfTextInputProcessor,
                 public ITfKeyEventSink,
                 public ITfCompositionSink
{
public:
    CLipiTSF();
    ~CLipiTSF();

    // IUnknown methods
    STDMETHODIMP QueryInterface(REFIID riid, void **ppvObj);
    STDMETHODIMP_(ULONG) AddRef(void);
    STDMETHODIMP_(ULONG) Release(void);

    // ITfTextInputProcessor methods
    STDMETHODIMP Activate(ITfThreadMgr *ptim, TfClientId tid);
    STDMETHODIMP Deactivate();

    // ITfKeyEventSink methods
    STDMETHODIMP OnSetFocus(BOOL fForeground);
    STDMETHODIMP OnTestKeyDown(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten);
    STDMETHODIMP OnKeyDown(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten);
    STDMETHODIMP OnTestKeyUp(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten);
    STDMETHODIMP OnKeyUp(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten);
    STDMETHODIMP OnPreservedKey(ITfContext *pic, REFGUID rguid, BOOL *pfEaten);

    // ITfCompositionSink methods
    STDMETHODIMP OnCompositionTerminated(TfEditCookie ecWrite, ITfComposition *pComposition);

private:
    void _InitKeyEventSink();
    void _UninitKeyEventSink();
    void _HandleKeystroke(ITfContext *pic, WPARAM wParam);
    
public:
    HRESULT _DoEditSession(TfEditCookie ec, ITfContext *pic, WPARAM wParam);
    
private:
    LONG _cRef;
    ITfThreadMgr *_ptim;
    TfClientId _tid;
    IpcClient _ipc;

    std::wstring _currentWord;
    ITfComposition* _pComposition;
    bool _isActive;
    
    std::vector<std::wstring> _suggestions;
    int _selectedIndex;
    
    bool _browserBypassEnabled;
    ULONGLONG _lastConfigCheckTime;
    
    bool _ShouldBypass();
};
