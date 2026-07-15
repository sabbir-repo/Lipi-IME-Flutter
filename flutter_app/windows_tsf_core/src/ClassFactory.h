#pragma once
#include "Globals.h"

class CClassFactory : public IClassFactory
{
public:
    CClassFactory();
    ~CClassFactory();

    // IUnknown methods
    STDMETHODIMP QueryInterface(REFIID riid, void **ppvObj);
    STDMETHODIMP_(ULONG) AddRef(void);
    STDMETHODIMP_(ULONG) Release(void);

    // IClassFactory methods
    STDMETHODIMP CreateInstance(IUnknown *pUnkOuter, REFIID riid, void **ppvObj);
    STDMETHODIMP LockServer(BOOL fLock);

private:
    LONG _cRef;
};
