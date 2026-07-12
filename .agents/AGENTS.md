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