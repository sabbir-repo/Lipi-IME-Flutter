@echo off
title Portable Flutter Development Environment

echo ============================================
echo      Portable Flutter Development Setup
echo ============================================
echo.

:: ==============================
:: Java
:: ==============================
set JAVA_HOME=D:\PortableDev\OpenJDK25U-jdk_x64_windows_hotspot_25.0.3_9\jdk-25.0.3+9

:: ==============================
:: Android SDK
:: ==============================
set ANDROID_HOME=D:\PortableDev\AndroidSDK
set ANDROID_SDK_ROOT=%ANDROID_HOME%

:: ==============================
:: Flutter Cache
:: ==============================
set PUB_CACHE=D:\PortableDev\.pub-cache

:: Optional Generic Cache
set XDG_CACHE_HOME=D:\PortableDev\.cache

:: ==============================
:: Gradle Cache
:: ==============================
set GRADLE_USER_HOME=D:\PortableDev\.gradle

:: ==============================
:: Android User Config
:: ==============================
set ANDROID_USER_HOME=D:\PortableDev\.android

:: ==============================
:: Temporary Files
:: ==============================
set TEMP=D:\PortableDev\Temp
set TMP=D:\PortableDev\Temp

:: ==============================
:: PATH
:: ==============================
set PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\cmdline-tools\latest\bin;D:\PortableDev\flutter_windows_3.44.2-stable\flutter\bin;%PATH%

:: ==============================
:: Create folders if missing
:: ==============================
if not exist D:\PortableDev\.gradle mkdir D:\PortableDev\.gradle
if not exist D:\PortableDev\.pub-cache mkdir D:\PortableDev\.pub-cache
if not exist D:\PortableDev\.android mkdir D:\PortableDev\.android
if not exist D:\PortableDev\Temp mkdir D:\PortableDev\Temp
if not exist D:\PortableDev\.cache mkdir D:\PortableDev\.cache

echo.
echo Java:
java -version

echo.
echo Flutter:
flutter --version

echo.
echo Environment Ready.
echo.


cmd