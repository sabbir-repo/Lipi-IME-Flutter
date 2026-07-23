#pragma once
#include <windows.h>
#include <string>

class IpcClient
{
public:
    IpcClient();
    ~IpcClient();

    bool Connect();
    void Disconnect();
    bool IsConnected() const { return _hPipe != INVALID_HANDLE_VALUE; }

    bool SendMessage(const std::wstring& msg);
    bool ReceiveMessage(std::wstring& outMsg);

private:
    HANDLE _hPipe;
    static const std::wstring PIPE_NAME;
    std::string _readBuffer;
};
