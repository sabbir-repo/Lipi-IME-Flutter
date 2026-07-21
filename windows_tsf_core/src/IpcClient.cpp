#include "IpcClient.h"
#include <vector>
#include <fstream>

void LogDebug(const std::string& msg) {
    std::ofstream log("D:\\PortableDev\\Temp\\LipiTSF.log", std::ios_base::app);
    log << msg << "\n";
}

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
        LogDebug("Named pipe not found, attempting to start LipiService.exe...");
        STARTUPINFOW si = { sizeof(si) };
        PROCESS_INFORMATION pi = { 0 };
        // Hardcoded development path to LipiService executable
        std::wstring servicePath = L"E:\\Python Projects\\Google Input Tools to Flutter desktop\\LipiService\\bin\\Release\\net10.0\\LipiService.exe";
        
        if (CreateProcessW(
            servicePath.c_str(),
            NULL,
            NULL,
            NULL,
            FALSE,
            CREATE_NO_WINDOW,
            NULL,
            NULL,
            &si,
            &pi
        )) {
            LogDebug("CreateProcessW succeeded, waiting for service to initialize.");
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);
            
            // Wait for the C# service to start and create the named pipe
            Sleep(800);
            
            // Try waiting again for up to 2 seconds
            if (!WaitNamedPipe(PIPE_NAME.c_str(), 2000)) {
                LogDebug("WaitNamedPipe failed after launching service.");
                return false;
            }
        } else {
            LogDebug("CreateProcessW failed. Error: " + std::to_string(GetLastError()));
            return false;
        }
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

    // Pipe is in Byte mode


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

    LogDebug("Sending message...");
    DWORD cbWritten = 0;
    BOOL bSuccess = WriteFile(
        _hPipe,
        utf8Msg.c_str(),
        (DWORD)utf8Msg.length(),
        &cbWritten,
        NULL);

    LogDebug("WriteFile returned. bSuccess: " + std::to_string(bSuccess) + " cbWritten: " + std::to_string(cbWritten));

    if (!bSuccess || cbWritten != utf8Msg.length())
    {
        LogDebug("WriteFile failed, disconnecting.");
        Disconnect();
        return false;
    }

    LogDebug("SendMessage complete.");
    return true;
}

bool IpcClient::ReceiveMessage(std::wstring& outMsg)
{
    if (!IsConnected()) return false;

    char buffer[4096];
    DWORD cbRead = 0;

    LogDebug("Calling ReadFile...");
    BOOL bSuccess = ReadFile(
        _hPipe,
        buffer,
        sizeof(buffer) - 1,
        &cbRead,
        NULL);

    LogDebug("ReadFile returned. bSuccess: " + std::to_string(bSuccess) + " cbRead: " + std::to_string(cbRead));

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
