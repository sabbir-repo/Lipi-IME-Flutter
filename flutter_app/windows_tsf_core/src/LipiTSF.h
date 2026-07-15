#pragma once
#include "Globals.h"
#include "IpcClient.h"

class CLipiTSF : public ITfTextInputProcessor
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

private:
    LONG _cRef;
    ITfThreadMgr *_ptim;
    TfClientId _tid;
    IpcClient _ipc;
};
