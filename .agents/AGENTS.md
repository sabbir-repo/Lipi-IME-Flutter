# Flutter Portable Development Environment

When working in this project, do NOT assume Flutter, Dart, Java, Android SDK, or Gradle are installed globally.
This project uses a portable Flutter development environment.

## IMPORTANT RULE

Before running ANY Flutter or Dart related command in the terminal, you MUST first load the portable environment using `D:\PortableDev\portableDev.bat`.

Use this format:
`call D:\PortableDev\portableDev.bat && <command>`

Examples:
- `call D:\PortableDev\portableDev.bat && flutter doctor`
- `call D:\PortableDev\portableDev.bat && flutter pub get`
- `call D:\PortableDev\portableDev.bat && flutter run`
- `call D:\PortableDev\portableDev.bat && flutter build windows`
- `call D:\PortableDev\portableDev.bat && dart analyze`

Do NOT run these commands directly: `flutter ...`, `dart ...`, `adb ...`, `sdkmanager ...`, `gradlew ...`

Always prefix them with: `call D:\PortableDev\portableDev.bat &&`

This project stores all development caches outside the C: drive using environment variables configured by `portableDev.bat` (e.g., JAVA_HOME, ANDROID_HOME, PUB_CACHE, PATH, etc.). Never assume these variables exist globally. Always load the portable environment first.


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