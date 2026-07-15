import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../api/api_service.dart';
import 'preference_manager.dart';
import 'win32_ffi.dart';
import 'ipc_server.dart';

class ImeController extends ChangeNotifier {
  static final ImeController _instance = ImeController._internal();
  factory ImeController() => _instance;
  ImeController._internal();

  bool isEnabled = true;
  String langCode = "bn-t-i0-und";
  
  String buffer = "";
  String lastFetchedBuffer = "";
  List<String> suggestions = [];
  int highlightedIndex = 0;
  String notificationText = "";
  Timer? _notificationTimer;
  
  // Settings (with default values)
  bool onlineMode = true;
  bool offlineEnabled = true;
  int debounceDelayMs = 70; // Default 70ms like python
  
  int fontSize = 11;
  double suggestionOpacity = 0.9;
  bool soundEnabled = true;
  bool allowWebsites = false;
  bool startup = false;
  
  // Premium Features State
  List<String> appBlacklist = [];
  Color bgColor = const Color(0xFF111113);
  Color textColor = const Color(0xFFf0f0f5);
  Color highlightColor = const Color(0xFFff4ec2);
  bool enableGlassmorphism = true;
  String soundType = "system";
  String currentActiveExe = "";

  Timer? _debounceTimer;
  final List<AudioPlayer> _audioPlayers = List.generate(4, (_) => AudioPlayer());
  int _currentPlayerIndex = 0;
  final IpcServer _ipcServer = IpcServer();

  void loadSettings() {
    try {
      _ipcServer.start();
      _ipcServer.onMessage.listen((msg) {
        print("IPC MSG: $msg");
        // TSF DLL থেকে KEY:A ফরম্যাটে মেসেজ আসে
        if (msg.startsWith("KEY:") && msg.length == 5) {
          final char = msg.substring(4).toLowerCase();
          appendBuffer(char);
        }
      });
      final prefs = PreferenceManager();
      isEnabled = prefs.getSetting("enabled", true);
      langCode = prefs.getSetting("lang_code", "bn-t-i0-und");
      onlineMode = prefs.getSetting("online_mode", true);
      offlineEnabled = prefs.getSetting("offline_enabled", true);
      
      // Convert double seconds to ms
      double delaySec = prefs.getSetting("debounce_delay", 0.07);
      debounceDelayMs = (delaySec * 1000).toInt();
      
      fontSize = prefs.getSetting("font_size", 11);
      suggestionOpacity = prefs.getSetting("suggestion_opacity", 0.9);
      soundEnabled = prefs.getSetting("sound_enabled", true);
      allowWebsites = prefs.getSetting("allow_websites", false);
      startup = prefs.getSetting("startup", false);

      appBlacklist = prefs.getAppBlacklist();
      bgColor = Color(prefs.getThemeColor("theme_bg_color", 0xFF111113));
      textColor = Color(prefs.getThemeColor("theme_text_color", 0xFFf0f0f5));
      highlightColor = Color(prefs.getThemeColor("theme_highlight_color", 0xFFff4ec2));
      enableGlassmorphism = prefs.getGlassmorphism();
      soundType = prefs.getSoundType();
    } catch (e) {
      print("Failed to load settings in ImeController: $e");
    }
  }

  void saveSettings() {
    try {
      final prefs = PreferenceManager();
      prefs.setSetting("enabled", isEnabled);
      prefs.setSetting("lang_code", langCode);
      prefs.setSetting("online_mode", onlineMode);
      prefs.setSetting("offline_enabled", offlineEnabled);
      prefs.setSetting("debounce_delay", debounceDelayMs / 1000.0);
      
      prefs.setSetting("font_size", fontSize);
      prefs.setSetting("suggestion_opacity", suggestionOpacity);
      prefs.setSetting("sound_enabled", soundEnabled);
      prefs.setSetting("allow_websites", allowWebsites);
      prefs.setSetting("startup", startup);

      prefs.setAppBlacklist(appBlacklist);
      prefs.setThemeColor("theme_bg_color", bgColor.value);
      prefs.setThemeColor("theme_text_color", textColor.value);
      prefs.setThemeColor("theme_highlight_color", highlightColor.value);
      prefs.setGlassmorphism(enableGlassmorphism);
      prefs.setSoundType(soundType);
    } catch (e) {
      print("Failed to save settings in ImeController: $e");
    }
  }

  void showNotification(String text) {
    notificationText = text;
    notifyListeners();
    
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(milliseconds: 1000), () {
      notificationText = "";
      notifyListeners();
    });
  }

  void addAppToBlacklist(String exeName) {
    if (exeName.isNotEmpty && !appBlacklist.contains(exeName)) {
      appBlacklist.add(exeName);
      saveSettings();
      notifyListeners();
    }
  }

  void removeAppFromBlacklist(String exeName) {
    if (appBlacklist.contains(exeName)) {
      appBlacklist.remove(exeName);
      saveSettings();
      notifyListeners();
    }
  }

  Future<void> playKeystrokeSound() async {
    if (!soundEnabled) return;
    try {
      if (soundType == 'mechanical') {
        int r = Random().nextInt(34) + 1;
        final player = _audioPlayers[_currentPlayerIndex];
        _currentPlayerIndex = (_currentPlayerIndex + 1) % _audioPlayers.length;
        player.play(AssetSource('audio/key_$r.mp3'), mode: PlayerMode.lowLatency);
      } else if (soundType == 'system') {
        myBeep(700, 50);
      }
    } catch (e) {
      print("Audio play error: $e");
    }
  }

  void toggleActive() {
    isEnabled = !isEnabled;
    if (!isEnabled) {
      clearBuffer();
    }
    
    showNotification(isEnabled ? "Active" : "Disabled");
    
    // Play native system beep
    if (soundEnabled && Platform.isWindows) {
      try {
        if (isEnabled) {
          myBeep(900, 120);
        } else {
          myBeep(600, 120);
        }
      } catch (_) {}
    }
    
    saveSettings();
    notifyListeners();
  }

  void cycleLanguage() {
    const langCodes = [
      "bn-t-i0-und",
      "hi-t-i0-und",
      "ar-t-i0-und",
      "ne-t-i0-und",
      "ur-t-i0-und"
    ];
    int idx = langCodes.indexOf(langCode);
    int nextIdx = (idx + 1) % langCodes.length;
    langCode = langCodes[nextIdx];
    clearBuffer();
    
    final langText = langCode == "bn-t-i0-und" ? "Bengali" :
                     langCode == "hi-t-i0-und" ? "Hindi" :
                     langCode == "ar-t-i0-und" ? "Arabic" :
                     langCode == "ne-t-i0-und" ? "Nepali" : "Urdu";
    showNotification(langText);
    
    // Play language-specific native beep
    if (soundEnabled && Platform.isWindows) {
      try {
        myBeep(700 + nextIdx * 100, 150);
      } catch (_) {}
    }
    
    saveSettings();
    notifyListeners();
  }

  Future<void> updateStartup(bool val) async {
    startup = val;
    saveSettings();
    
    if (Platform.isWindows) {
      final exePath = Platform.resolvedExecutable;
      try {
        if (val) {
          await Process.run('reg', [
            'add',
            'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run',
            '/v',
            'LipiIME',
            '/t',
            'REG_SZ',
            '/d',
            '"$exePath"',
            '/f'
          ]);
        } else {
          await Process.run('reg', [
            'delete',
            'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run',
            '/v',
            'LipiIME',
            '/f'
          ]);
        }
      } catch (e) {
        print("Failed to update startup registry: $e");
      }
    }
    notifyListeners();
  }

  void updateDebounceDelay(int ms) {
    debounceDelayMs = ms;
    saveSettings();
    notifyListeners();
  }

  void updateFontSize(int size) {
    fontSize = size;
    saveSettings();
    notifyListeners();
  }

  void updateOpacity(double opacity) {
    suggestionOpacity = opacity;
    saveSettings();
    notifyListeners();
  }

  void updateAllowWebsites(bool val) {
    allowWebsites = val;
    saveSettings();
    notifyListeners();
  }

  void updateOfflineEnabled(bool val) {
    offlineEnabled = val;
    saveSettings();
    notifyListeners();
  }

  void updateOnlineMode(bool val) {
    onlineMode = val;
    saveSettings();
    notifyListeners();
  }

  void updateSoundEnabled(bool val) {
    soundEnabled = val;
    saveSettings();
    notifyListeners();
  }

  void updateDefaultLanguage(String code) {
    langCode = code;
    clearBuffer();
    saveSettings();
    notifyListeners();
  }

  void appendBuffer(String char) {
    buffer += char;
    _requestSuggestions();
    Future.microtask(() => notifyListeners());
  }

  void popBuffer() {
    if (buffer.isNotEmpty) {
      buffer = buffer.substring(0, buffer.length - 1);
      if (buffer.isNotEmpty) {
        _requestSuggestions();
      } else {
        clearBuffer();
      }
      Future.microtask(() => notifyListeners());
    }
  }

  void clearBuffer() {
    buffer = "";
    lastFetchedBuffer = "";
    suggestions.clear();
    highlightedIndex = 0;
    _debounceTimer?.cancel();
    Future.microtask(() => notifyListeners());
  }

  void selectNext() {
    if (suggestions.isNotEmpty) {
      highlightedIndex = (highlightedIndex + 1) % suggestions.length;
      Future.microtask(() => notifyListeners());
    }
  }

  void selectPrevious() {
    if (suggestions.isNotEmpty) {
      highlightedIndex = (highlightedIndex - 1 + suggestions.length) % suggestions.length;
      Future.microtask(() => notifyListeners());
    }
  }

  void _requestSuggestions() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: debounceDelayMs), () async {
      if (buffer.isEmpty) return;
      
      final currentBuffer = buffer;
      final results = await ApiService().fetchSuggestions(
        currentBuffer, 
        langCode, 
        offlineEnabled, 
        onlineMode
      );
      
      // Ensure we only update if the buffer hasn't changed drastically while fetching
      if (buffer == currentBuffer) {
        lastFetchedBuffer = currentBuffer;
        final list = results.take(5).toList();
        
        // 1. Prioritize Custom Dictionary word at Index 0
        final customDict = PreferenceManager().getCustomDict(langCode);
        final customWord = customDict[currentBuffer] ?? customDict[currentBuffer.toLowerCase()];
        if (customWord != null) {
          if (list.contains(customWord)) {
            list.remove(customWord);
          }
          list.insert(0, customWord);
        }
        
        // 2. Prioritize User Preference history
        final history = PreferenceManager().getHistory(langCode);
        final preferred = history[currentBuffer] ?? history[currentBuffer.toLowerCase()];
        if (preferred != null) {
          if (list.contains(preferred)) {
            list.remove(preferred);
          }
          if (customWord != null) {
            list.insert(1, preferred);
          } else {
            list.insert(0, preferred);
          }
        }
        
        suggestions = list.take(5).toList();
        suggestions.add(currentBuffer); // Add English literal at the end
        highlightedIndex = 0;
        notifyListeners();
      }
    });
  }
}
