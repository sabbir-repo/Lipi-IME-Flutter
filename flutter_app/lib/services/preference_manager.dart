import 'dart:convert';
import 'dart:io';

class PreferenceManager {
  static final PreferenceManager _instance = PreferenceManager._internal();
  factory PreferenceManager() => _instance;
  PreferenceManager._internal();

  Map<String, dynamic> _prefs = {};
  File? _prefFile;

  Future<void> init() async {
    try {
      final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        final lipiDir = Directory('$home/.lipi_ime');
        final oldPrefsFile = File('$home/.lipi_ime_prefs.json');
        final oldDictFile = File('$home/.lipi_ime_dict.json');

        // 1. Create directory if not exists
        if (!await lipiDir.exists()) {
          await lipiDir.create(recursive: true);
        }

        _prefFile = File('${lipiDir.path}/prefs.json');
        final dictFile = File('${lipiDir.path}/dict.json');

        // 2. Perform Migration of Preferences
        if (await oldPrefsFile.exists() && !await _prefFile!.exists()) {
          try {
            await oldPrefsFile.copy(_prefFile!.path);
            await oldPrefsFile.delete();
          } catch (e) {
            print('Failed to migrate preferences: $e');
          }
        }

        // 3. Load preferences first
        if (await _prefFile!.exists()) {
          final content = await _prefFile!.readAsString();
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _prefs = decoded;
          }
        }

        // 4. Perform Migration of Custom Dictionary (Merge into prefs.json under "custom_dict" key)
        Map<String, dynamic>? migratedDict;
        if (await dictFile.exists()) {
          try {
            final content = await dictFile.readAsString();
            migratedDict = jsonDecode(content);
            await dictFile.delete();
          } catch (_) {}
        } else if (await oldDictFile.exists()) {
          try {
            final content = await oldDictFile.readAsString();
            migratedDict = jsonDecode(content);
            await oldDictFile.delete();
          } catch (_) {}
        }

        if (migratedDict != null) {
          if (!_prefs.containsKey('custom_dict')) {
            _prefs['custom_dict'] = <String, dynamic>{};
          }
          // The old dict was global key-value (since old Lipi was mostly Bengali).
          // We nest it under the default language code "bn-t-i0-und".
          final customDictNode = _prefs['custom_dict'] as Map<String, dynamic>;
          if (!customDictNode.containsKey('bn-t-i0-und')) {
            customDictNode['bn-t-i0-und'] = <String, dynamic>{};
          }
          final bnNode = customDictNode['bn-t-i0-und'] as Map<String, dynamic>;
          migratedDict.forEach((key, value) {
            bnNode[key] = value;
          });
          
          await _saveToFile();
        }
      }
    } catch (e) {
      print('Failed to load user preferences: $e');
    }
  }

  Map<String, String> getHistory(String langCode) {
    if (_prefs.containsKey(langCode)) {
      final data = _prefs[langCode];
      if (data is Map) {
        return data.map((key, value) => MapEntry(key.toString(), value.toString()));
      }
    }
    return {};
  }

  void savePreference(String langCode, String bufferText, String selectedWord) {
    if (!_prefs.containsKey(langCode)) {
      _prefs[langCode] = <String, dynamic>{};
    }
    _prefs[langCode][bufferText] = selectedWord;
    
    _saveToFile();
  }

  Map<String, String> getCustomDict(String langCode) {
    if (_prefs.containsKey('custom_dict')) {
      final customDictNode = _prefs['custom_dict'];
      if (customDictNode is Map && customDictNode.containsKey(langCode)) {
        final data = customDictNode[langCode];
        if (data is Map) {
          return data.map((key, value) => MapEntry(key.toString(), value.toString()));
        }
      }
    }
    return {};
  }

  void saveCustomWord(String langCode, String text, String translation) {
    if (!_prefs.containsKey('custom_dict')) {
      _prefs['custom_dict'] = <String, dynamic>{};
    }
    final customDictNode = _prefs['custom_dict'] as Map<String, dynamic>;
    if (!customDictNode.containsKey(langCode)) {
      customDictNode[langCode] = <String, dynamic>{};
    }
    (customDictNode[langCode] as Map<String, dynamic>)[text] = translation;
    
    _saveToFile();
  }

  void removeCustomWord(String langCode, String text) {
    if (_prefs.containsKey('custom_dict')) {
      final customDictNode = _prefs['custom_dict'];
      if (customDictNode is Map && customDictNode.containsKey(langCode)) {
        final data = customDictNode[langCode] as Map;
        data.remove(text);
        _saveToFile();
      }
    }
  }

  void clearCustomWords(String langCode) {
    if (_prefs.containsKey('custom_dict')) {
      final customDictNode = _prefs['custom_dict'];
      if (customDictNode is Map && customDictNode.containsKey(langCode)) {
        final data = customDictNode[langCode] as Map;
        data.clear();
        _saveToFile();
      }
    }
  }

  dynamic getSetting(String key, dynamic defaultValue) {
    return _prefs[key] ?? defaultValue;
  }

  void setSetting(String key, dynamic value) {
    _prefs[key] = value;
    _saveToFile();
  }

  // --- Premium Features Helpers ---

  List<String> getAppBlacklist() {
    final list = _prefs['app_blacklist'];
    if (list is List) {
      return List<String>.from(list);
    }
    return [];
  }

  void setAppBlacklist(List<String> list) {
    _prefs['app_blacklist'] = list;
    _saveToFile();
  }

  int getThemeColor(String key, int defaultColor) {
    return _prefs[key] ?? defaultColor;
  }

  void setThemeColor(String key, int colorValue) {
    _prefs[key] = colorValue;
    _saveToFile();
  }

  bool getGlassmorphism() {
    return _prefs['enable_glassmorphism'] ?? true;
  }

  void setGlassmorphism(bool value) {
    _prefs['enable_glassmorphism'] = value;
    _saveToFile();
  }

  String getSoundType() {
    return _prefs['sound_type'] ?? 'system';
  }

  void setSoundType(String type) {
    _prefs['sound_type'] = type;
    _saveToFile();
  }

  Future<void> _saveToFile() async {
    if (_prefFile == null) return;
    try {
      await _prefFile!.writeAsString(jsonEncode(_prefs));
    } catch (e) {
      print('Failed to save preferences: $e');
    }
  }
}
