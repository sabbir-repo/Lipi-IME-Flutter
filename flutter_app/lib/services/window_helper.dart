import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'win32_ffi.dart';
import 'package:flutter/material.dart';

void setAsSuggestionWindow() {
  final titlePtr = "Lipi IME".toNativeUtf16();
  int hwnd = myFindWindow(nullptr, titlePtr);
  calloc.free(titlePtr);
  
  if (hwnd != 0) {
    int style = myGetWindowLongPtr(hwnd, -20); // GWL_EXSTYLE
    style |= 0x08000000; // WS_EX_NOACTIVATE
    style |= 0x00000080; // WS_EX_TOOLWINDOW
    mySetWindowLongPtr(hwnd, -20, style);
    // HWND_TOPMOST = -1, SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE|SWP_FRAMECHANGED
    mySetWindowPos(hwnd, -1, 0, 0, 0, 0, 0x0002 | 0x0001 | 0x0010 | 0x0020);
  } else {
    print("setAsSuggestionWindow: Window not found!");
  }
}

void setAsDashboardWindow() {
  final titlePtr = "Lipi IME".toNativeUtf16();
  int hwnd = myFindWindow(nullptr, titlePtr);
  calloc.free(titlePtr);
  
  if (hwnd != 0) {
    int style = myGetWindowLongPtr(hwnd, -20); // GWL_EXSTYLE
    style &= ~0x08000000; // Remove WS_EX_NOACTIVATE
    style &= ~0x00000080; // Remove WS_EX_TOOLWINDOW
    mySetWindowLongPtr(hwnd, -20, style);
    // HWND_NOTOPMOST = -2, SWP_NOMOVE|SWP_NOSIZE|SWP_FRAMECHANGED
    mySetWindowPos(hwnd, -2, 0, 0, 0, 0, 0x0002 | 0x0001 | 0x0020);
  } else {
    print("setAsDashboardWindow: Window not found!");
  }
}

void showWindowInactive() {
  final titlePtr = "Lipi IME".toNativeUtf16();
  int hwnd = myFindWindow(nullptr, titlePtr);
  calloc.free(titlePtr);
  
  if (hwnd != 0) {
    // SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOSIZE, HWND_TOPMOST=-1
    mySetWindowPos(hwnd, -1, 0, 0, 0, 0, 0x0002 | 0x0001 | 0x0010);
    myShowWindow(hwnd, 4); // SW_SHOWNOACTIVATE
  } else {
    print("showWindowInactive: Window not found!");
  }
}

void hideWindow() {
  final titlePtr = "Lipi IME".toNativeUtf16();
  int hwnd = myFindWindow(nullptr, titlePtr);
  calloc.free(titlePtr);
  
  if (hwnd != 0) {
    myShowWindow(hwnd, 0); // SW_HIDE
  } else {
    print("hideWindow: Window not found!");
  }
}

void setWindowPosition(int x, int y, int width, int height) {
  final titlePtr = "Lipi IME".toNativeUtf16();
  int hwnd = myFindWindow(nullptr, titlePtr);
  calloc.free(titlePtr);
  
  if (hwnd != 0) {
    // SWP_NOACTIVATE | SWP_NOZORDER
    mySetWindowPos(hwnd, 0, x, y, width, height, 0x0010 | 0x0004);
  }
}
