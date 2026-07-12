import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'api/api_service.dart';
import 'services/ime_controller.dart';
import 'services/win32_hook.dart';
import 'services/window_helper.dart';
import 'services/focus_tracker.dart';
import 'services/preference_manager.dart';
import 'ui/dashboard.dart';
import 'ui/suggestion_window.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await ApiService().init();
  await PreferenceManager().init();
  ImeController().loadSettings();
  Win32Hook().startHook();
  FocusTracker().start();

  WindowOptions windowOptions = const WindowOptions(
    title: 'Lipi IME',
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setTitle('Lipi IME');
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
    
    // Resolve and cache Lipi IME window handle
    Win32Hook().updateLipiHwnd();
    
    // Default to Dashboard mode initially
    setAsDashboardWindow();
  });

  runApp(const LipiApp());
}

class LipiApp extends StatefulWidget {
  const LipiApp({Key? key}) : super(key: key);

  @override
  State<LipiApp> createState() => _LipiAppState();
}

class _LipiAppState extends State<LipiApp> {
  final SystemTray _systemTray = SystemTray();
  final AppWindow _appWindow = AppWindow();
  
  bool _showDashboard = true;
  bool _inSuggestionMode = false;
  bool? _lastEnabled;
  String? _lastLang;
  String? _lastExe;

  @override
  void initState() {
    super.initState();
    _initSystemTray();
    
    // Listen to IME controller changes to show suggestions
    ImeController().addListener(_onImeChange);
  }
  
  void _onImeChange() {
    final ime = ImeController();
    
    // Update System Tray Tooltip on change
    if (ime.isEnabled != _lastEnabled || ime.langCode != _lastLang) {
      _lastEnabled = ime.isEnabled;
      _lastLang = ime.langCode;
      
      final statusText = ime.isEnabled ? "Active" : "Disabled";
      final langText = ime.langCode == "bn-t-i0-und" ? "Bengali" :
                       ime.langCode == "hi-t-i0-und" ? "Hindi" :
                       ime.langCode == "ar-t-i0-und" ? "Arabic" :
                       ime.langCode == "ne-t-i0-und" ? "Nepali" : "Urdu";
                       
      _systemTray.setToolTip("Lipi IME ($statusText - $langText)");
      _updateSystemTrayMenu(); // Update tray checkboxes state dynamically
    }
    
    // Check if we need to update tray for blacklist
    if (ime.currentActiveExe != _lastExe) {
      _lastExe = ime.currentActiveExe;
      _updateSystemTrayMenu();
    }

    // 🟢 বাগ ফিক্স: ড্যাশবোর্ড ওপেন থাকলে উইন্ডো হাইড করা যাবে না
    if (_showDashboard) {
      // যদি ড্যাশবোর্ড ওপেন থাকা অবস্থায় কেউ টাইপ করা শুরু করে, তবে ড্যাশবোর্ড বন্ধ করে সাজেশন দেখাবে
      if (ime.buffer.isNotEmpty) {
        _showDashboard = false;
        if (!_inSuggestionMode) {
          _inSuggestionMode = true;
          setAsSuggestionWindow();
        }
        showWindowInactive();
      }
      setState(() {});
      return; // 🟢 ড্যাশবোর্ড ওপেন থাকলে নিচের hideWindow() লজিকে যাবে না
    }

    // ড্যাশবোর্ড বন্ধ থাকলে রেগুলার সাজেশন উইন্ডোর লজিক
    if (ime.buffer.isNotEmpty || ime.notificationText.isNotEmpty) {
      // Switch to suggestion window mode if not already in it
      if (!_inSuggestionMode) {
        _inSuggestionMode = true;
        setAsSuggestionWindow();
      }
      showWindowInactive();
      setState(() {});
    } else {
      // Hide suggestion window when buffer and notifications are both empty
      _inSuggestionMode = false;
      hideWindow();
      setState(() {});
    }
  }

  Future<void> _updateSystemTrayMenu() async {
    try {
      final menu = Menu();
      final ime = ImeController();
      
      await menu.buildFrom([
        MenuItemLabel(label: 'Show Dashboard', onClicked: (menuItem) {
          _openDashboard();
        }),
        if (ime.currentActiveExe.isNotEmpty)
          MenuItemLabel(
            label: 'Block Current App (${ime.currentActiveExe})',
            onClicked: (menuItem) {
              ime.addAppToBlacklist(ime.currentActiveExe);
            },
          ),
        MenuItemCheckbox(
          label: 'Active (Alt + T)',
          checked: ime.isEnabled,
          onClicked: (menuItem) {
            ime.toggleActive();
          },
        ),
        MenuSeparator(),
        SubMenu(
          label: 'Select Language',
          children: [
            MenuItemCheckbox(
              label: 'Bengali',
              checked: ime.langCode == 'bn-t-i0-und',
              onClicked: (menuItem) => ime.updateDefaultLanguage('bn-t-i0-und'),
            ),
            MenuItemCheckbox(
              label: 'Hindi',
              checked: ime.langCode == 'hi-t-i0-und',
              onClicked: (menuItem) => ime.updateDefaultLanguage('hi-t-i0-und'),
            ),
            MenuItemCheckbox(
              label: 'Arabic',
              checked: ime.langCode == 'ar-t-i0-und',
              onClicked: (menuItem) => ime.updateDefaultLanguage('ar-t-i0-und'),
            ),
            MenuItemCheckbox(
              label: 'Nepali',
              checked: ime.langCode == 'ne-t-i0-und',
              onClicked: (menuItem) => ime.updateDefaultLanguage('ne-t-i0-und'),
            ),
            MenuItemCheckbox(
              label: 'Urdu',
              checked: ime.langCode == 'ur-t-i0-und',
              onClicked: (menuItem) => ime.updateDefaultLanguage('ur-t-i0-und'),
            ),
          ],
        ),
        SubMenu(
          label: 'Settings',
          children: [
            MenuItemCheckbox(
              label: 'Enable Sound Alerts',
              checked: ime.soundEnabled,
              onClicked: (menuItem) => ime.updateSoundEnabled(!ime.soundEnabled),
            ),
            MenuItemCheckbox(
              label: 'Offline Fallback Mode',
              checked: ime.offlineEnabled,
              onClicked: (menuItem) => ime.updateOfflineEnabled(!ime.offlineEnabled),
            ),
          ],
        ),
        MenuSeparator(),
        MenuItemLabel(label: 'Exit IME', onClicked: (menuItem) {
          Win32Hook().stopHook();
          exit(0);
        }),
      ]);
      
      await _systemTray.setContextMenu(menu);
    } catch (e) {
      print("Failed to update system tray menu: $e");
    }
  }

  Future<void> _initSystemTray() async {
    try {
      String path = Platform.isWindows ? 'assets/icon.ico' : 'assets/icon.png';
      await _systemTray.initSystemTray(
        title: "Lipi IME",
        iconPath: path,
      );

      await _updateSystemTrayMenu();

      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          // লেফট-ক্লিক করলে ড্যাশবোর্ড ওপেন হবে
          _openDashboard();
        } else if (eventName == kSystemTrayEventRightClick) {
          // 🟢 বাগ ফিক্স: রাইট-ক্লিক করলে কনটেক্সট মেনু (Context Menu) দেখাবে
          _systemTray.popUpContextMenu();
        }
      });
    } catch (e) {
      print("SystemTray init failed (likely missing asset): $e");
    }
  }

  void _openDashboard() async {
    // ১. প্রথমেই স্টেট পরিবর্তন করুন, যাতে ফ্লাটার ড্যাশবোর্ড উইজেট তৈরি করা শুরু করে দেয়
    setState(() {
      _showDashboard = true;
    });

    // ২. ফ্লাটারকে ড্যাশবোর্ডের ফ্রেম রেন্ডার করার জন্য সামান্য সময় দিন
    await Future.delayed(const Duration(milliseconds: 50));

    // ৩. উইন্ডো রিসাইজ করার সময় চোখের সামনে যাতে উইন্ডো লাফালাফি না করে, 
    // তাই আগে উইন্ডোর Opacity 0 (অদৃশ্য) করে দিন
    await windowManager.setOpacity(0.0);

    // ৪. এবার উইন্ডোটি Show করুন (এটি ফ্লাটারের স্ট্রেচ বা ঘোলা হওয়ার বাগটি ফিক্স করবে)
    await windowManager.show();

    // ৫. উইন্ডোর নেটিভ স্টাইলগুলো (TOOLWINDOW এবং NOACTIVATE) সরিয়ে স্বাভাবিক করুন
    setAsDashboardWindow();
    await windowManager.setAlwaysOnTop(false);

    // ৬. এখন ড্যাশবোর্ডের আসল সাইজ দিন এবং স্ক্রিনের মাঝে নিয়ে আসুন
    await windowManager.setSize(const Size(800, 600));
    await windowManager.center();

    // ৭. অপারেটিং সিস্টেমকে সাইজ আপডেট করার জন্য একটু সময় দিন
    await Future.delayed(const Duration(milliseconds: 50));

    // ৮. সবশেষে উইন্ডোটিকে আবার দৃশ্যমান (Opacity 1.0) করে ফোকাস করুন
    await windowManager.setOpacity(1.0);
    await windowManager.focus();
  }
  
  void _closeDashboard() async {
    setState(() {
      _showDashboard = false;
      _inSuggestionMode = false;
    });
    hideWindow();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lipi IME',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101014),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF47a7ff),
          surface: Color(0xFF181822),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: _showDashboard 
            ? Dashboard(onClose: _closeDashboard) 
            : const SuggestionView(),
      ),
    );
  }
}
