## Project Overview

This project uses the following architecture:

- Native C++ TSF IME Core
- C# WinUI 3 Dashboard
- C# Suggestion / Cache Service

The goal is to minimize writes to the Windows system drive (C:) whenever possible.

---

# Development Environment

Always load the portable development environment before executing build-related commands.

Use:

```cmd
call D:\PortableDev\portableNative.bat && <command>
```

Never execute build commands directly without loading the portable environment first.

---

# Commands that MUST use portableNative.bat

```cmd
dotnet restore
dotnet build
dotnet publish

cmake -S . -B build
cmake --build build

msbuild

cl
link
rc

vcpkg

python
pip

```

Always execute them like this:

```cmd
call D:\PortableDev\portableNative.bat && dotnet build
```

Example:

```cmd
call D:\PortableDev\portableNative.bat && dotnet restore

call D:\PortableDev\portableNative.bat && cmake -S . -B build

call D:\PortableDev\portableNative.bat && cmake --build build --config Debug

call D:\PortableDev\portableNative.bat && msbuild Project.sln
```

---

# Commands that DO NOT require portableNative.bat

These commands may be executed normally.

```
git status
git diff
git add
git commit
git checkout
git branch

powershell

copy
move
rename
del
dir
tree

notepad
code .
```

---

# Before Running Build Commands

Verify:

- TEMP is redirected
- TMP is redirected
- NUGET_PACKAGES is redirected
- DOTNET_CLI_HOME is redirected

Do not assume global environment variables.

---

# Build Output

Always keep generated files inside the project.

Examples:

```
build/
bin/
obj/
Debug/
Release/
```

Never generate build artifacts outside the project directory unless explicitly requested.

---

# Package Policy

Before installing anything globally, ASK FOR PERMISSION.

Examples:

- winget
- choco
- scoop
- dotnet workload install
- Visual Studio Installer Modify
- Windows SDK installation
- vcpkg integrate install
- pip install (global)
- npm install -g

Always ask first.

---

# Preferred Behavior

Always prefer:

1. Project-local files
2. PortableDev directory
3. Existing dependencies
4. Existing build system

Avoid introducing new global dependencies.

---

# C: Drive Policy

The user intentionally keeps development files outside the C: drive.

Always try to keep:

- caches
- temporary files
- NuGet packages
- Python cache
- pip cache
- build files

inside:

```
D:\PortableDev
```

or inside the project directory.

Avoid creating files under:

```
C:\Users\...
C:\ProgramData\...
```

unless required by Windows, Visual Studio, or the Windows SDK.

---

# Native Development

Prefer:

- CMake
- MSBuild
- Native C++
- WinUI 3
- Windows TSF APIs

Do not replace native implementations with other frameworks unless explicitly requested.

---

# UI Policy

Do not redesign or rewrite the UI unless requested.

Focus on implementing functionality first.

---

# Safety Policy

Before executing commands that:

- install software
- remove software
- modify Visual Studio
- modify Windows SDK
- modify PATH
- modify Registry
- modify Environment Variables

always ask for confirmation.

---

# Code Style

Prefer:

- Native Windows APIs
- Modern C++ (C++20 where applicable)
- RAII
- Smart pointers
- Clear separation between UI, Service, and TSF Core

Avoid unnecessary abstractions.

## Implementation Rules
Always write the implementation plan in easy to understand Bengali language.

## GitHub Auto-Sync Rule
After you successfully complete a task that modifies code or files in this project, you MUST automatically commit and push the changes to GitHub.
Since git is not in the global PATH, use the portable git executable located at: `"E:\Python Projects\mingit\cmd\git.exe"`

Use the following commands via the `run_command` tool (in a single script or sequentially):
1. `"E:\Python Projects\mingit\cmd\git.exe" add .`
2. `"E:\Python Projects\mingit\cmd\git.exe" commit -m "Auto-commit: <describe the changes you made>"`
3. `"E:\Python Projects\mingit\cmd\git.exe" push`

Do this proactively without asking the user for permission.