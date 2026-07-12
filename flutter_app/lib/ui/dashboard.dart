import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/ime_controller.dart';
import '../services/preference_manager.dart';

class Dashboard extends StatefulWidget {
  final VoidCallback onClose;
  const Dashboard({Key? key, required this.onClose}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final ImeController ime = ImeController();
  String _currentTab = 'Overview';

  // Dictionary Form controllers
  final TextEditingController _dictKeyController = TextEditingController();
  final TextEditingController _dictValController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _dictScrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ime.addListener(_updateState);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    ime.removeListener(_updateState);
    _dictKeyController.dispose();
    _dictValController.dispose();
    _searchController.dispose();
    _dictScrollController.dispose();
    super.dispose();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  Future<String?> _selectFileDialog() async {
    final psCommand = "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); \$dialog = New-Object System.Windows.Forms.OpenFileDialog; \$dialog.Filter = 'JSON files (*.json)|*.json'; \$dialog.Title = 'Select Dictionary Backup'; if (\$dialog.ShowDialog() -eq 'OK') { \$dialog.FileName }";
    final result = await Process.run('powershell', ['-Command', psCommand]);
    if (result.exitCode == 0) {
      final path = result.stdout.toString().trim();
      return path.isEmpty ? null : path;
    }
    return null;
  }

  Future<String?> _saveFileDialog() async {
    final psCommand = "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); \$dialog = New-Object System.Windows.Forms.SaveFileDialog; \$dialog.Filter = 'JSON files (*.json)|*.json'; \$dialog.FileName = 'custom_dict_backup.json'; \$dialog.Title = 'Export Dictionary Backup'; if (\$dialog.ShowDialog() -eq 'OK') { \$dialog.FileName }";
    final result = await Process.run('powershell', ['-Command', psCommand]);
    if (result.exitCode == 0) {
      final path = result.stdout.toString().trim();
      return path.isEmpty ? null : path;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border.all(color: Color(0xFF383B47), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildTitleBar(),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(),
                  VerticalDivider(width: 1, color: Color(0xFF383B47)),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(padding: EdgeInsets.only(left: 16),
              child: Text('Lipi IME Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.white54),
              onPressed: widget.onClose,
              hoverColor: Colors.red.withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 200,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSidebarItem(Icons.dashboard, 'Overview'),
            _buildSidebarItem(Icons.settings, 'Settings'),
            _buildSidebarItem(Icons.book, 'Dictionary'),
            _buildSidebarItem(Icons.block, 'Exclusions'),
            _buildSidebarItem(Icons.palette, 'Appearance'),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String tabName) {
    final isActive = _currentTab == tabName;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: isActive ? Theme.of(context).colorScheme.primary : Colors.white54),
          title: Text(tabName, style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () {
            setState(() {
              _currentTab = tabName;
            });
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentTab) {
      case 'Settings':
        return _buildSettingsTab();
      case 'Dictionary':
        return _buildDictionaryTab();
      case 'Exclusions':
        return _buildAppExclusionsTab();
      case 'Appearance':
        return _buildAppearanceTab();
      case 'Overview':
      default:
        return _buildOverviewTab();
    }
  }

  final TextEditingController _exeController = TextEditingController();

  Widget _buildAppExclusionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('App Exclusions (Blacklist)', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(height: 8),
          Text('The IME will automatically bypass these applications.', style: TextStyle(color: Colors.white70)),
          SizedBox(height: 24),
          
          if (ime.currentActiveExe.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Currently Focused App:', style: TextStyle(fontSize: 12, color: Colors.white54)),
                        SizedBox(height: 4),
                        Text(ime.currentActiveExe, style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.block, size: 18),
                    label: Text("Add to Blacklist"),
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                    onPressed: () {
                      ime.addAppToBlacklist(ime.currentActiveExe);
                    },
                  )
                ],
              ),
            ),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _exeController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter executable name (e.g. code.exe)',
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Color(0xFF1a1a24),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  if (_exeController.text.trim().isNotEmpty) {
                    ime.addAppToBlacklist(_exeController.text.trim().toLowerCase());
                    _exeController.clear();
                  }
                },
                child: Text('Add'),
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              )
            ],
          ),
          SizedBox(height: 24),
          
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: ime.appBlacklist.length,
            itemBuilder: (context, index) {
              final exe = ime.appBlacklist[index];
              return Card(
                color: Color(0xFF1a1a24),
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(exe, style: TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => ime.removeAppFromBlacklist(exe),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showColorPicker(String title, Color initialColor, Function(Color) onColorChanged) {
    Color tempColor = initialColor;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(title, style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (color) => tempColor = color,
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                onColorChanged(tempColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppearanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance & Theme', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(height: 24),
          
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: Text('Enable Glassmorphism (Acrylic Blur)', style: TextStyle(color: Colors.white)),
              subtitle: Text('Blurs the background of the suggestion window.', style: TextStyle(color: Colors.white54)),
              value: ime.enableGlassmorphism,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) {
                setState(() {
                  ime.enableGlassmorphism = val;
                  ime.saveSettings();
                });
              },
            ),
          ),
          Divider(height: 32, color: Color(0xFF383B47)),
          
          Text('Theme Colors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(height: 16),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildColorTile('Background Color', ime.bgColor, (c) {
                setState(() { ime.bgColor = c; ime.saveSettings(); });
              }),
              _buildColorTile('Text Color', ime.textColor, (c) {
                setState(() { ime.textColor = c; ime.saveSettings(); });
              }),
              _buildColorTile('Highlight Color', ime.highlightColor, (c) {
                setState(() { ime.highlightColor = c; ime.saveSettings(); });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorTile(String title, Color color, Function(Color) onColorChanged) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showColorPicker(title, color, onColorChanged),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(color: Colors.white)),
              SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final statusText = ime.isEnabled ? "Active" : "Disabled";
    final langText = ime.langCode == "bn-t-i0-und" ? "Bengali" :
                     ime.langCode == "hi-t-i0-und" ? "Hindi" :
                     ime.langCode == "ar-t-i0-und" ? "Arabic" :
                     ime.langCode == "ne-t-i0-und" ? "Nepali" : "Urdu";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 30),
          
          // IME Status Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF383B47)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IME Status', style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ime.isEnabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
                            boxShadow: [
                              BoxShadow(
                                color: ime.isEnabled ? Theme.of(context).colorScheme.primary.withOpacity(0.5) : Theme.of(context).colorScheme.error.withOpacity(0.5),
                                blurRadius: 8,
                              )
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(statusText, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: ime.isEnabled,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (val) {
                    ime.toggleActive();
                  },
                )
              ],
            ),
          ),
          SizedBox(height: 24),
          
          // Current Language Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFF383B47)),
            ),
            child: Row(
              children: [
                Icon(Icons.language, color: Colors.blueAccent, size: 28),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACTIVE LANGUAGE', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(langText, style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 30),
          
          // Shortcut References
          Text('Shortcut References', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(height: 12),
          _buildShortcutRow('Toggle IME Active/Inactive', 'Alt + T'),
          _buildShortcutRow('Cycle Input Language', 'Alt + L'),
          _buildShortcutRow('Navigate Suggestions', 'Up / Down Arrows'),
          _buildShortcutRow('Select Highlighted Word', 'Space / Enter'),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String description, String shortcut) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(description, style: TextStyle(color: Colors.white70)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFF383B47),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(shortcut, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
          )
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    final List<Map<String, String>> langs = [
      {"name": "Bengali", "code": "bn-t-i0-und"},
      {"name": "Hindi", "code": "hi-t-i0-und"},
      {"name": "Arabic", "code": "ar-t-i0-und"},
      {"name": "Nepali", "code": "ne-t-i0-und"},
      {"name": "Urdu", "code": "ur-t-i0-und"}
    ];
    final selectedLangName = langs.firstWhere((l) => l['code'] == ime.langCode, orElse: () => langs.first)['name'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('IME Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 24),
          
          // Language Select Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active Language', style: TextStyle(fontSize: 16, color: Colors.white70)),
              DropdownButton<String>(
                value: selectedLangName,
                dropdownColor: Theme.of(context).colorScheme.surface,
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                style: TextStyle(color: Colors.white, fontSize: 16),
                underline: Container(height: 1, color: Theme.of(context).colorScheme.primary),
                items: langs.map((l) {
                  return DropdownMenuItem<String>(
                    value: l['name'],
                    child: Text(l['name']!),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final newCode = langs.firstWhere((l) => l['name'] == val)['code']!;
                    ime.updateDefaultLanguage(newCode);
                  }
                },
              ),
            ],
          ),
          Divider(height: 32, color: Color(0xFF383B47)),
          
          // Debounce Delay Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Debounce Delay (Typing delay)', style: TextStyle(fontSize: 16, color: Colors.white70)),
                  Text('${ime.debounceDelayMs} ms', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: ime.debounceDelayMs.toDouble(),
                min: 50,
                max: 200,
                divisions: 15,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) {
                  ime.updateDebounceDelay(val.toInt());
                },
              )
            ],
          ),
          Divider(height: 24, color: Color(0xFF383B47)),
          
          // Font Size Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Suggestion Window Font Size', style: TextStyle(fontSize: 16, color: Colors.white70)),
                  Text('${ime.fontSize} px', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: ime.fontSize.toDouble(),
                min: 9,
                max: 18,
                divisions: 9,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) {
                  ime.updateFontSize(val.toInt());
                },
              )
            ],
          ),
          Divider(height: 24, color: Color(0xFF383B47)),

          // Opacity Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Suggestion Window Opacity', style: TextStyle(fontSize: 16, color: Colors.white70)),
                  Text('${(ime.suggestionOpacity * 100).toInt()} %', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: ime.suggestionOpacity,
                min: 0.5,
                max: 1.0,
                divisions: 10,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) {
                  ime.updateOpacity(val);
                },
              )
            ],
          ),
          Divider(height: 32, color: Color(0xFF383B47)),
          
          // Toggle Switched
          _buildToggleRow('Allow inside Browser Websites', ime.allowWebsites, (val) {
            ime.updateAllowWebsites(val);
          }),
          _buildToggleRow('Run on Windows Startup', ime.startup, (val) {
            ime.updateStartup(val);
          }),
          _buildToggleRow('Enable Offline Cache Mode', ime.offlineEnabled, (val) {
            ime.updateOfflineEnabled(val);
          }),
          
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Typing Sound Feedback', style: TextStyle(fontSize: 16, color: Colors.white)),
              DropdownButton<String>(
                value: ime.soundEnabled ? ime.soundType : "none",
                dropdownColor: Theme.of(context).colorScheme.surface,
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                style: TextStyle(color: Colors.white, fontSize: 16),
                underline: Container(height: 1, color: Theme.of(context).colorScheme.primary),
                items: [
                  DropdownMenuItem(value: "none", child: Text("None")),
                  DropdownMenuItem(value: "system", child: Text("Windows System Beep")),
                  DropdownMenuItem(value: "mechanical", child: Text("Mechanical Keyboard")),
                ],
                onChanged: (val) {
                  setState(() {
                    if (val == "none") {
                      ime.soundEnabled = false;
                    } else {
                      ime.soundEnabled = true;
                      ime.soundType = val!;
                    }
                    ime.saveSettings();
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 16),

          _buildToggleRow('Enable Online Translation Mode', ime.onlineMode, (val) {
            ime.updateOnlineMode(val);
          }),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 15, color: Colors.white70)),
          Switch(
            value: value,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: onChanged,
          )
        ],
      ),
    );
  }

  Widget _buildDictionaryTab() {
    final customWords = PreferenceManager().getCustomDict(ime.langCode);
    final filteredWords = customWords.entries.where((entry) {
      if (_searchQuery.isEmpty) return true;
      return entry.key.contains(_searchQuery) || entry.value.toLowerCase().contains(_searchQuery);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Custom Dictionary Manager', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 20),
          
          // Add mapping input fields
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dictKeyController,
                  decoration: InputDecoration(
                    labelText: 'English Word (Key)',
                    labelStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _dictValController,
                  decoration: InputDecoration(
                    labelText: 'Native Value',
                    labelStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {
                  final key = _dictKeyController.text.trim().toLowerCase();
                  final val = _dictValController.text.trim();
                  if (key.isNotEmpty && val.isNotEmpty) {
                    PreferenceManager().saveCustomWord(ime.langCode, key, val);
                    _dictKeyController.clear();
                    _dictValController.clear();
                    setState(() {});
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Search box
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search word mappings...',
              hintStyle: TextStyle(color: Colors.white30),
              prefixIcon: Icon(Icons.search, color: Colors.white54),
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
              fillColor: Theme.of(context).colorScheme.surface,
              filled: true,
            ),
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 16),
          
          // Word List view
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF383B47)),
              ),
              child: filteredWords.isEmpty
                  ? Center(child: Text('No custom words mapped.', style: TextStyle(color: Colors.white30, fontSize: 16)),
                    )
                  : Scrollbar(
                      controller: _dictScrollController,
                      child: ListView.separated(
                        controller: _dictScrollController,
                        itemCount: filteredWords.length,
                        separatorBuilder: (ctx, idx) => Divider(height: 1, color: Color(0xFF383B47)),
                        itemBuilder: (ctx, index) {
                          final item = filteredWords[index];
                          return ListTile(
                            title: Row(
                              children: [
                                Expanded(child: Text(item.key, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                SizedBox(width: 16),
                                Icon(Icons.arrow_right_alt, color: Colors.white30, size: 20),
                                SizedBox(width: 16),
                                Expanded(child: Text(item.value, style: TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error, size: 20),
                              onPressed: () {
                                PreferenceManager().removeCustomWord(ime.langCode, item.key);
                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
          SizedBox(height: 16),
          
          // Backup & Clear actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: Icon(Icons.upload_file),
                    label: Text('Import Backup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                    onPressed: _importBackup,
                  ),
                  SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: Icon(Icons.download),
                    label: Text('Export Backup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                    onPressed: _exportBackup,
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.clear_all),
                label: Text('Clear All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: _clearAllMappings,
              ),
            ],
          )
        ],
      ),
    );
  }

  void _clearAllMappings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Confirm Clear', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete all custom dictionary mappings for this language?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: Text('Clear'),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              PreferenceManager().clearCustomWords(ime.langCode);
              Navigator.of(ctx).pop();
              setState(() {});
            },
          )
        ],
      ),
    );
  }

  Future<void> _importBackup() async {
    try {
      final path = await _selectFileDialog();
      if (path == null) return;
      
      final file = File(path);
      if (!await file.exists()) return;
      
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      
      if (decoded is! Map) {
        throw const FormatException("Backup format must be a JSON object containing key-value mappings.");
      }

      final Map<String, String> cleanData = {};
      decoded.forEach((key, value) {
        cleanData[key.toString().trim().toLowerCase()] = value.toString().trim();
      });

      if (cleanData.isEmpty) {
        _showMsgDialog("Import", "No valid word mappings found in the backup file.");
        return;
      }

      // Ask for merge or overwrite option
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text('Import Options', style: TextStyle(color: Colors.white)),
          content: Text('Do you want to MERGE the imported ${cleanData.length} mappings with your existing ones, or OVERWRITE them?'),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: Text('Overwrite', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () {
                PreferenceManager().clearCustomWords(ime.langCode);
                cleanData.forEach((k, v) {
                  PreferenceManager().saveCustomWord(ime.langCode, k, v);
                });
                Navigator.of(ctx).pop();
                setState(() {});
                _showMsgDialog("Import Complete", "Successfully imported ${cleanData.length} mappings (overwritten).");
              },
            ),
            ElevatedButton(
              child: Text('Merge'),
              onPressed: () {
                cleanData.forEach((k, v) {
                  PreferenceManager().saveCustomWord(ime.langCode, k, v);
                });
                Navigator.of(ctx).pop();
                setState(() {});
                _showMsgDialog("Import Complete", "Successfully merged ${cleanData.length} mappings.");
              },
            ),
          ],
        ),
      );
    } catch (e) {
      _showMsgDialog("Import Error", "Failed to import backup:\n$e");
    }
  }

  Future<void> _exportBackup() async {
    try {
      final words = PreferenceManager().getCustomDict(ime.langCode);
      if (words.isEmpty) {
        _showMsgDialog("Export Empty", "Your custom dictionary is empty. Nothing to export.");
        return;
      }

      final path = await _saveFileDialog();
      if (path == null) return;

      final file = File(path);
      const encoder = JsonEncoder.withIndent('    ');
      await file.writeAsString(encoder.convert(words));
      _showMsgDialog("Export Success", "Successfully exported ${words.length} mappings to:\n$path");
    } catch (e) {
      _showMsgDialog("Export Error", "Failed to export backup:\n$e");
    }
  }

  void _showMsgDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(title, style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      ),
    );
  }
}
