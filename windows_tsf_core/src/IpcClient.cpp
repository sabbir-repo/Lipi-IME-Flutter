#include "IpcClient.h"
#include <vector>

const std::wstring IpcClient::PIPE_NAME = L"\\\\.\\pipe\\LipiImePipe";

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

    if (!WaitNamedPipe(PIPE_NAME.c_str(), 100)) 
    {
        return false;
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

    // Since server is in Message mode, we can optionally set client to Message mode
    DWORD dwMode = PIPE_READMODE_MESSAGE;
    SetNamedPipeHandleState(_hPipe, &dwMode, NULL, NULL);

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

    // Convert UTF-16 to UTF-8
    int utf8Size = WideCharToMultiByte(CP_UTF8, 0, msg.c_str(), -1, NULL, 0, NULL, NULL);
    if (utf8Size <= 0) return false;

    std::string utf8Msg(utf8Size, 0);
    WideCharToMultiByte(CP_UTF8, 0, msg.c_str(), -1, &utf8Msg[0], utf8Size, NULL, NULL);
    
    // Remove the null terminator added by WideCharToMultiByte, we don't send it.
    if (utf8Msg.back() == '\0') utf8Msg.pop_back();

    // Append newline for C# StreamReader.ReadLineAsync()
    utf8Msg += "\n";

    DWORD cbWritten = 0;
    BOOL bSuccess = WriteFile(
        _hPipe,
        utf8Msg.c_str(),
        (DWORD)utf8Msg.length(),
        &cbWritten,
        NULL);

    if (!bSuccess || cbWritten != utf8Msg.length())
    {
        Disconnect();
        return false;
    }

    return true;
}

bool IpcClient::ReceiveMessage(std::wstring& outMsg)
{
    if (!IsConnected()) return false;

    char buffer[4096];
    DWORD cbRead = 0;

    BOOL bSuccess = ReadFile(
        _hPipe,
        buffer,
        sizeof(buffer) - 1,
        &cbRead,
        NULL);

    if (!bSuccess || cbRead == 0)
    {
        Disconnect();
        return false;
    }

    buffer[cbRead] = '\0';

    // Convert UTF-8 back to UTF-16
    int utf16Size = MultiByteToWideChar(CP_UTF8, 0, buffer, -1, NULL, 0);
    if (utf16Size <= 0) return false;

    std::wstring utf16Msg(utf16Size, 0);
    MultiByteToWideChar(CP_UTF8, 0, buffer, -1, &utf16Msg[0], utf16Size);

    // Remove the null terminator
    if (utf16Msg.back() == L'\0') utf16Msg.pop_back();
    
    // Trim potential trailing newline from C# WriteLineAsync
    if (!utf16Msg.empty() && utf16Msg.back() == L'\n') utf16Msg.pop_back();
    if (!utf16Msg.empty() && utf16Msg.back() == L'\r') utf16Msg.pop_back();

    outMsg = utf16Msg;
    return true;
}
