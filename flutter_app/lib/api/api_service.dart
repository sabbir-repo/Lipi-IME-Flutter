import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Map<String, Map<String, List<String>>> _offlineCache = {};
  File? _cacheFile;
  
  // Basic fallback dictionary
  final Map<String, Map<String, List<String>>> _basicOfflineDict = {
    "bn-t-i0-und": {
      "amar": ["আমার", "আমারে", "আমারও", "আমারই"],
      "tumi": ["তুমি", "তুমিও", "তুমিই", "তোমাকে"],
      "ami": ["আমি", "আমিও", "আমিই", "আমাকে"],
      "bhalo": ["ভালো", "ভাল", "ভালোই", "ভালো লাগছে"],
      "dhaka": ["ঢাকা", "ঢাকায়", "ঢাকাই"],
      "bhasha": ["ভাষা", "ভাষার", "ভাষায়"],
      "bangla": ["বাংলা", "বাংলাদেশ", "বাঙালি", "বাঙला"],
      "nam": ["নাম", "নামের", "নামটি"],
      "ki": ["কী", "কি", "কিছু", "কিনা"],
      "kemon": ["কেমন", "কেমন আছো", "কেমন আছেন"],
      "acho": ["আছো", "আছেন", "আছিস"],
      "bari": ["বাড়ি", "বাড়িতে", "বাড়ির"],
      "khabar": ["খাবার", "খাবো", "খাবার দাবাড়"],
      "desh": ["দেশ", "দেশের", "দেশে"],
      "shonar": ["সোনার", "সোনা", "সোনার বাংলা"]
    },
    // More basic dict entries can be added here
  };

  Future<void> init() async {
    try {
      final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        final lipiDir = Directory('$home/.lipi_ime');
        if (!await lipiDir.exists()) {
          await lipiDir.create(recursive: true);
        }

        _cacheFile = File('${lipiDir.path}/offline_cache.json');
        
        // 1. Migrate old home directory cache
        final oldHomeCacheFile = File('$home/.lipi_ime_offline_cache.json');
        if (await oldHomeCacheFile.exists() && !await _cacheFile!.exists()) {
          try {
            await oldHomeCacheFile.copy(_cacheFile!.path);
            await oldHomeCacheFile.delete();
          } catch (e) {
            print('Failed to migrate home offline cache: $e');
          }
        }

        // 2. Migrate old documents directory cache
        final docDir = await getApplicationDocumentsDirectory();
        final docCacheFile = File('${docDir.path}/.lipi_ime_offline_cache.json');
        if (await docCacheFile.exists() && !await _cacheFile!.exists()) {
          try {
            await docCacheFile.copy(_cacheFile!.path);
            await docCacheFile.delete();
          } catch (e) {
            print('Failed to migrate doc offline cache: $e');
          }
        }

        if (await _cacheFile!.exists()) {
          final content = await _cacheFile!.readAsString();
          final Map<String, dynamic> decoded = jsonDecode(content);
          decoded.forEach((lang, langData) {
            _offlineCache[lang] = {};
            (langData as Map<String, dynamic>).forEach((word, suggestions) {
              _offlineCache[lang]![word] = List<String>.from(suggestions);
            });
          });
        }
      }
    } catch (e) {
      print('Failed to load offline cache: $e');
    }
  }

  Future<void> _saveCache() async {
    if (_cacheFile == null) return;
    try {
      await _cacheFile!.writeAsString(jsonEncode(_offlineCache));
    } catch (e) {
      print('Failed to save offline cache: $e');
    }
  }

  void cacheWord(String langCode, String word, List<String> suggestions) {
    if (word.trim().isEmpty || suggestions.isEmpty) return;
    _offlineCache.putIfAbsent(langCode, () => {});
    _offlineCache[langCode]![word] = suggestions;
    _saveCache(); // Fire and forget saving to prefs file
  }

  Future<List<String>> fetchSuggestions(
      String text, String langCode, bool offlineEnabled, bool onlineMode) async {
    if (text.trim().isEmpty) return [];

    final textLower = text.toLowerCase().trim();

    // 1. Check local offline cache and basic fallback dictionary first
    if (offlineEnabled) {
      final langCache = _offlineCache[langCode] ?? {};
      if (langCache.containsKey(text)) return langCache[text]!;
      if (langCache.containsKey(textLower)) return langCache[textLower]!;

      final basicDict = _basicOfflineDict[langCode] ?? {};
      if (basicDict.containsKey(textLower)) return basicDict[textLower]!;
    }

    // 2. Fall back to online API request if not found in offline cache
    if (onlineMode) {
      final url = Uri.parse('https://inputtools.google.com/request');
      try {
        final response = await http.post(
          url,
          body: {
            'text': text,
            'itc': langCode,
            'num': '5',
            'cp': '0',
            'cs': '1',
            'ie': 'utf-8',
            'oe': 'utf-8',
            'app': 'demomode'
          },
        ).timeout(const Duration(milliseconds: 2500));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data[0] == "SUCCESS") {
            final results = List<String>.from(data[1][0][1]);
            return results;
          }
        }
      } catch (e) {
        // Silently fallback if online API fails
      }
    }

    return [];
  }
}
