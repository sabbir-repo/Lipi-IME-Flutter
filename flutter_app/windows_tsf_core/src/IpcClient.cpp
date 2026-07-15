#include "IpcClient.h"

const std::wstring IpcClient::PIPE_NAME = L"\\\\.\\pipe\\LipiImeIpcPipe";

IpcClient::IpcClient() : _hPipe(INVALID_HANDLE_VALUE)
{
}

IpcClient::~IpcClient()
{
    Disconnect();
}

bool IpcClient::Connect()
{
    if (IsConnected()) return true;

    // Try to connect to the named pipe
    // We use WaitNamedPipe to wait for the server (Flutter app) to create the pipe
    if (!WaitNamedPipe(PIPE_NAME.c_str(), 100)) 
    {
        return false; // Pipe is not available
    }

    _hPipe = CreateFile(
        PIPE_NAME.c_str(),
        GENERIC_READ | GENERIC_WRITE,
        0,
        NULL,
        OPEN_EXISTING,
        0,
        NULL);

    if (_hPipe == INVALID_HANDLE_VALUE)
    {
        return false;
    }

    return true;
}

void IpcClient::Disconnect()
{
    if (_hPipe != INVALID_HANDLE_VALUE)
    {
        CloseHandle(_hPipe);
        _hPipe = INVALID_HANDLE_VALUE;
    }
}

bool IpcClient::SendMessage(const std::wstring& msg)
{
    if (!IsConnected())
    {
        if (!Connect()) return false;
    }

    DWORD cbWritten = 0;
    // We send the size of the string in bytes first, then the string itself
    // However, to keep it simple, we can just send null-terminated string.
    DWORD sizeInBytes = (DWORD)((msg.length() + 1) * sizeof(wchar_t));

    BOOL bSuccess = WriteFile(
        _hPipe,
        msg.c_str(),
        sizeInBytes,
        &cbWritten,
        NULL);

    if (!bSuccess || sizeInBytes != cbWritten)
    {
        Disconnect(); // Disconnect on error
        return false;
    }

    return true;
}

bool IpcClient::ReceiveMessage(std::wstring& outMsg)
{
    if (!IsConnected()) return false;

    wchar_t buffer[1024];
    DWORD cbRead = 0;

    BOOL bSuccess = ReadFile(
        _hPipe,
        buffer,
        sizeof(buffer) - sizeof(wchar_t),
        &cbRead,
        NULL);

    if (!bSuccess || cbRead == 0)
    {
        Disconnect();
        return false;
    }

    // Ensure null termination just in case
    buffer[cbRead / sizeof(wchar_t)] = L'\0';
    outMsg = buffer;

    return true;
}
