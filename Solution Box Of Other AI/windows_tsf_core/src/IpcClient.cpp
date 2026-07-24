#include "IpcClient.h"
#include <vector>
#include <fstream>
#include <algorithm>

void LogDebug(const std::string& msg) {
#ifdef _DEBUG
    std::ofstream log("D:\\PortableDev\\Temp\\LipiTSF.log", std::ios_base::app);
    log << msg << "\n";
#else
    (void)msg; // no-op in Release builds
#endif
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
        std::wstring servicePath = L"E:\\Python Projects\\Google Input Tools to Flutter desktop\\LipiService\\bin\\Debug\\net10.0-windows\\LipiService.exe";
        
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
    _readBuffer.clear();
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

    std::string utf8Msg;

    LogDebug("Calling ReadFile loop...");
    // Hard deadline so a busy/hung service can never freeze the host application.
    const ULONGLONG deadline = GetTickCount64() + 1500;
    while (true)
    {
        size_t newlinePos = _readBuffer.find('\n');
        if (newlinePos != std::string::npos)
        {
            utf8Msg = _readBuffer.substr(0, newlinePos);
            _readBuffer.erase(0, newlinePos + 1);
            break;
        }

        // Wait for data without blocking forever: poll with PeekNamedPipe until the deadline.
        DWORD bytesAvail = 0;
        if (!PeekNamedPipe(_hPipe, NULL, 0, NULL, &bytesAvail, NULL))
        {
            LogDebug("PeekNamedPipe failed or disconnected.");
            Disconnect();
            return false;
        }
        if (bytesAvail == 0)
        {
            if (GetTickCount64() >= deadline)
            {
                // Timed out: disconnect fully so a late reply can never desync the next request.
                LogDebug("ReceiveMessage timed out; disconnecting.");
                Disconnect();
                return false;
            }
            Sleep(2);
            continue;
        }

        char chunk[512];
        DWORD cbRead = 0;
        BOOL bSuccess = ReadFile(_hPipe, chunk, sizeof(chunk), &cbRead, NULL);
        if (!bSuccess || cbRead == 0)
        {
            LogDebug("ReadFile failed or disconnected.");
            Disconnect();
            return false;
        }
        _readBuffer.append(chunk, cbRead);
    }

    // Remove trailing \r if present
    if (!utf8Msg.empty() && utf8Msg.back() == '\r') {
        utf8Msg.pop_back();
    }

    if (utf8Msg.empty()) {
        outMsg = L"";
        return true;
    }

    // Convert UTF-8 back to UTF-16
    int utf16Size = MultiByteToWideChar(CP_UTF8, 0, utf8Msg.c_str(), -1, NULL, 0);
    if (utf16Size <= 0) return false;

    std::wstring utf16Msg(utf16Size, 0);
    MultiByteToWideChar(CP_UTF8, 0, utf8Msg.c_str(), -1, &utf16Msg[0], utf16Size);

    // Remove the null terminator if present
    if (!utf16Msg.empty() && utf16Msg.back() == L'\0') utf16Msg.pop_back();

    // Strip BOM (\uFEFF) and Zero-Width Space (\u200B) if present
    utf16Msg.erase(std::remove(utf16Msg.begin(), utf16Msg.end(), L'\xFEFF'), utf16Msg.end());
    utf16Msg.erase(std::remove(utf16Msg.begin(), utf16Msg.end(), L'\x200B'), utf16Msg.end());

    outMsg = utf16Msg;
    return true;
}
