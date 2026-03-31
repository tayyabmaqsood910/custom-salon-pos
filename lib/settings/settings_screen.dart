import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_provider.dart';
import '../utils/responsive_layout.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedCategoryIndex = 0;
  String? _businessLogoPath;

  final List<String> _categories = [
    'Business Profile',
    'POS & Hardware',
    'Loyalty & Inventory',
    'Security & Access',
    'Backup & Export',
  ];

  late TextEditingController _salonNameCtrl;
  late TextEditingController _businessTaglineCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _footerCtrl;
  String _currencySymbol = '\$';

  // Tab 2
  String _defaultPaymentMethod = 'Cash';
  bool _enableTip = true;

  // Tab 3
  bool _enableLoyalty = true;
  late TextEditingController _pointsEarnRateCtrl;
  late TextEditingController _pointsRedeemRateCtrl;
  String _pointsExpiry = 'Never Expire';
  bool _autoDeductStock = true;
  late TextEditingController _lowStockThresholdCtrl;

  // Tab 4
  bool _enableStaffLogin = false;
  late TextEditingController _adminPinCtrl;
  late TextEditingController _adminPinConfirmCtrl;

  // Tab 5
  String _systemTheme = 'Deep Ocean Dark (Default)';
  String _fontScaling = 'Normal Space';
  String _language = 'English (US)';

  // Tab 6
  bool _enableAutoBackup = true;
  String _dbSize = '0.00 MB';
  String _backupSize = '0.00 MB';
  String _totalRecords = '0 records';

  static const List<String> _paymentMethodValues = [
    'Cash',
    'Card',
    'Mobile',
    'Split',
  ];

  /// Maps legacy labels and unknown values to billing-compatible keys.
  String _normalizePaymentMethod(String raw) {
    switch (raw) {
      case 'Credit Card':
        return 'Card';
      case 'Mobile Wallet':
        return 'Mobile';
      default:
        if (_paymentMethodValues.contains(raw)) return raw;
        return 'Cash';
    }
  }

  String _safeImageExt(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.jpg')) return 'jpg';
    if (lower.endsWith('.jpeg')) return 'jpeg';
    if (lower.endsWith('.webp')) return 'webp';
    return 'png';
  }

  String _normalizeSystemTheme(String value) {
    switch (value) {
      case 'Clean Light Mode':
        return 'Soft Light';
      case 'Midnight Black':
      case 'Soft Light':
      case 'Warm Sepia':
      case 'Ocean Blue':
      case 'Deep Ocean Dark (Default)':
        return value;
      default:
        return 'Deep Ocean Dark (Default)';
    }
  }

  String _normalizeLanguage(String value) {
    switch (value) {
      case 'Urdu (Coming Soon)':
        return 'Urdu (PK)';
      case 'English (US)':
      case 'Urdu (PK)':
      case 'Spanish':
        return value;
      default:
        return 'English (US)';
    }
  }

  Future<void> _pickBusinessLogo() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo upload is supported on desktop/mobile app.'),
        ),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (result == null || result.files.isEmpty) return;

      final pickedPath = result.files.single.path;
      if (pickedPath == null || pickedPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read selected image path.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final logosDir = Directory(
        '${appDir.path}${Platform.pathSeparator}business_logos',
      );
      if (!logosDir.existsSync()) {
        await logosDir.create(recursive: true);
      }

      final ext = _safeImageExt(pickedPath);
      final savedLogoPath =
          '${logosDir.path}${Platform.pathSeparator}logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final copiedLogo = await File(pickedPath).copy(savedLogoPath);

      // Clear stale cache when user replaces logo with another file.
      PaintingBinding.instance.imageCache.clear();

      setState(() => _businessLogoPath = copiedLogo.path);
      await context.read<AppProvider>().saveSettings({
        'businessLogoPath': copiedLogo.path,
      });
      _showSavedSnackbar();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logo upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _calculateStorageStats() async {
    int records = 0;
    double dbMB = 0.0;
    double backupMB = 0.0;

    try {
      final p = context.read<AppProvider>();
      records =
          p.customers.length +
          p.inventory.length +
          p.transactions.length +
          p.staff.length +
          p.expenses.length +
          p.services.length;

      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final dbPath = '${dir.path}${Platform.pathSeparator}salon_pos.db';
        final file = File(dbPath);
        if (file.existsSync()) {
          dbMB = file.lengthSync() / (1024 * 1024);
        }

        final downPath = await getDownloadsDirectory();
        if (downPath != null && downPath.existsSync()) {
          for (var entity in downPath.listSync()) {
            if (entity is File && entity.path.contains('SPS_')) {
              backupMB += entity.lengthSync() / (1024 * 1024);
            }
          }
        }
      }
    } catch (e) {}

    if (mounted) {
      setState(() {
        _totalRecords = '$records records';
        _dbSize = '${dbMB.toStringAsFixed(2)} MB';
        _backupSize = '${backupMB.toStringAsFixed(2)} MB';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _calculateStorageStats();

    _salonNameCtrl = TextEditingController();
    _businessTaglineCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _taxCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _footerCtrl = TextEditingController();

    _pointsEarnRateCtrl = TextEditingController();
    _pointsRedeemRateCtrl = TextEditingController();
    _lowStockThresholdCtrl = TextEditingController();
    _adminPinCtrl = TextEditingController();
    _adminPinConfirmCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AppProvider>().settings;
      setState(() {
        _salonNameCtrl.text = s['salonName'] ?? 'Styles POS';
        _businessTaglineCtrl.text = s['businessTagline'] ?? 'Salon & beauty';
        _phoneCtrl.text = s['phone'] ?? '';
        _taxCtrl.text = s['tax'] ?? '5.0';
        _addressCtrl.text = s['address'] ?? '';
        _footerCtrl.text =
            s['receiptFooter'] ??
            'Thank you for your visit! Follow us on IG @StylesPOS';
        _currencySymbol = s['currencySymbol'] ?? '\$';
        _businessLogoPath = s['businessLogoPath'];

        _defaultPaymentMethod =
            _normalizePaymentMethod(s['defaultPaymentMethod'] ?? 'Cash');
        _enableTip = (s['enableTip'] ?? 'true') == 'true';

        _enableLoyalty = (s['enableLoyalty'] ?? 'true') == 'true';
        _pointsExpiry = s['pointsExpiry'] ?? 'Never Expire';
        _autoDeductStock = (s['autoDeductStock'] ?? 'true') == 'true';

        _enableStaffLogin = (s['enableStaffLogin'] ?? 'false') == 'true';

        _systemTheme = _normalizeSystemTheme(
          s['systemTheme'] ?? 'Deep Ocean Dark (Default)',
        );
        _fontScaling = s['fontScaling'] ?? 'Normal Space';
        _language = _normalizeLanguage(s['language'] ?? 'English (US)');

        _enableAutoBackup = (s['enableAutoBackup'] ?? 'true') == 'true';

        _pointsEarnRateCtrl.text = s['pointsEarnRate'] ?? '10';
        _pointsRedeemRateCtrl.text = s['pointsRedeemRate'] ?? '10';
        _lowStockThresholdCtrl.text = s['lowStockThreshold'] ?? '5';
        _adminPinCtrl.text = s['adminPin'] ?? '1234';
        _adminPinConfirmCtrl.text = s['adminPin'] ?? '1234';
      });
    });
  }

  @override
  void dispose() {
    _salonNameCtrl.dispose();
    _businessTaglineCtrl.dispose();
    _phoneCtrl.dispose();
    _taxCtrl.dispose();
    _addressCtrl.dispose();
    _footerCtrl.dispose();
    _pointsEarnRateCtrl.dispose();
    _pointsRedeemRateCtrl.dispose();
    _lowStockThresholdCtrl.dispose();
    _adminPinCtrl.dispose();
    _adminPinConfirmCtrl.dispose();
    super.dispose();
  }

  /// Persists salon name, contact, tax, receipt text, currency, logo only.
  /// Does not require loyalty or PIN validation (those blocked full save before).
  Future<void> _saveBusinessProfile() async {
    final provider = context.read<AppProvider>();
    await provider.saveSettings({
      'salonName': _salonNameCtrl.text,
      'businessTagline': _businessTaglineCtrl.text,
      'phone': _phoneCtrl.text,
      'tax': _taxCtrl.text,
      'address': _addressCtrl.text,
      'receiptFooter': _footerCtrl.text,
      'currencySymbol': _currencySymbol,
      'businessLogoPath': _businessLogoPath ?? '',
    });
    if (!mounted) return;
    _showSavedSnackbar();
  }

  Future<void> _savePosSettings() async {
    final provider = context.read<AppProvider>();
    await provider.saveSettings({
      'defaultPaymentMethod': _defaultPaymentMethod,
      'enableTip': _enableTip.toString(),
    });
    if (!mounted) return;
    _showSavedSnackbar();
  }

  Future<void> _saveAutoBackupFlag() async {
    await context.read<AppProvider>().saveSettings({
      'enableAutoBackup': _enableAutoBackup.toString(),
    });
  }

  Future<void> _saveAllSettings() async {
    if (_adminPinCtrl.text != _adminPinConfirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin PINs do not match!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    final earnRate = double.tryParse(_pointsEarnRateCtrl.text.trim()) ??
        double.tryParse(provider.settings['pointsEarnRate'] ?? '10');
    final redeemRate = double.tryParse(_pointsRedeemRateCtrl.text.trim()) ??
        double.tryParse(provider.settings['pointsRedeemRate'] ?? '10');
    final lowStockThreshold = int.tryParse(_lowStockThresholdCtrl.text.trim()) ??
        int.tryParse(provider.settings['lowStockThreshold'] ?? '5');
    if (earnRate == null || earnRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Points earn rate must be a number greater than 0.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (redeemRate == null || redeemRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Points redeem rate must be a number greater than 0.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (lowStockThreshold == null || lowStockThreshold < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Low-stock threshold must be a non-negative number.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await provider.saveSettings({
      'salonName': _salonNameCtrl.text,
      'businessTagline': _businessTaglineCtrl.text,
      'phone': _phoneCtrl.text,
      'tax': _taxCtrl.text,
      'address': _addressCtrl.text,
      'receiptFooter': _footerCtrl.text,
      'currencySymbol': _currencySymbol,
      'businessLogoPath': _businessLogoPath ?? '',
      'defaultPaymentMethod': _defaultPaymentMethod,
      'enableTip': _enableTip.toString(),
      'enableLoyalty': _enableLoyalty.toString(),
      'pointsEarnRate': earnRate.toString(),
      'pointsRedeemRate': redeemRate.toString(),
      'pointsExpiry': _pointsExpiry,
      'autoDeductStock': _autoDeductStock.toString(),
      'lowStockThreshold': lowStockThreshold.toString(),
      'enableStaffLogin': _enableStaffLogin.toString(),
      'adminPin': _adminPinCtrl.text,
      'systemTheme': _systemTheme,
      'fontScaling': _fontScaling,
      'language': _language,
      'enableAutoBackup': _enableAutoBackup.toString(),
    });
    await provider.applyGlobalLowStockThreshold(lowStockThreshold);
    if (!mounted) return;
    _showSavedSnackbar();
  }

  @override
  Widget build(BuildContext context) {
    final pad = AppBreakpoints.pagePadding(context);
    return Padding(
      padding: pad,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < AppBreakpoints.mobile;
          final contentPadding = isMobile ? 16.0 : 32.0;

          Widget categoryPicker() {
            if (!isMobile) {
              return SizedBox(
                width: 250,
                child: ListView.separated(
                  itemCount: _categories.length,
                  separatorBuilder: (ctx, i) =>
                      const Divider(height: 1, color: Colors.white12),
                  itemBuilder: (ctx, i) {
                    final isSelected = _selectedCategoryIndex == i;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      title: Text(
                        _categories[i],
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.white,
                        ),
                      ),
                      onTap: () => setState(() => _selectedCategoryIndex = i),
                    );
                  },
                ),
              );
            }
            final sectionIndex = _selectedCategoryIndex < 0
                ? 0
                : (_selectedCategoryIndex >= _categories.length
                    ? _categories.length - 1
                    : _selectedCategoryIndex);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: DropdownButtonFormField<int>(
                key: ValueKey<int>(sectionIndex),
                initialValue: sectionIndex,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: List.generate(
                  _categories.length,
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(_categories[i]),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCategoryIndex = v);
                },
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings & Configuration',
                style: TextStyle(
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage business details, hardware, and data exports',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            categoryPicker(),
                            const Divider(height: 1, color: Colors.white12),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(contentPadding),
                                child: _buildCategoryContent(),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            categoryPicker(),
                            const VerticalDivider(
                              width: 1,
                              color: Colors.white24,
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(contentPadding),
                                child: _buildCategoryContent(),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryContent() {
    switch (_selectedCategoryIndex) {
      case 0:
        return _buildBusinessProfile();
      case 1:
        return _buildPOSSettings();
      case 2:
        return _buildLoyaltyInventory();
      case 3:
        return _buildSecurity();
      case 4:
        return _buildBackupExport();
      default:
        return const Center(child: Text('Coming soon...'));
    }
  }

  // 1. BUSINESS PROFILE
  Widget _buildBusinessProfile() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        final logoBox = Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: _businessLogoPath != null &&
                  _businessLogoPath!.isNotEmpty &&
                  File(_businessLogoPath!).existsSync()
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_businessLogoPath!),
                    fit: BoxFit.cover,
                    key: ValueKey(_businessLogoPath),
                  ),
                )
              : const Center(
                  child: Icon(Icons.store, size: 40, color: Colors.grey),
                ),
        );
        final currencyDropdown = DropdownButtonFormField<String>(
          key: ValueKey<String>(_currencySymbol),
          initialValue: _currencySymbol,
          decoration: const InputDecoration(labelText: 'Currency Symbol'),
          items: ['\$', 'Rs.', '€', '£']
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _currencySymbol = v);
            }
          },
        );

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Business Profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (isCompact) ...[
                logoBox,
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickBusinessLogo,
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload Logo'),
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    logoBox,
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _pickBusinessLogo,
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload Logo'),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              if (isCompact) ...[
                TextField(
                  decoration: const InputDecoration(labelText: 'Salon Name'),
                  controller: _salonNameCtrl,
                ),
                const SizedBox(height: 16),
                currencyDropdown,
              ] else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Salon Name'),
                        controller: _salonNameCtrl,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: currencyDropdown),
                  ],
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _businessTaglineCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business Type / Tagline',
                ),
              ),
              const SizedBox(height: 16),
              if (isCompact) ...[
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Tax / GST (%)'),
                  keyboardType: TextInputType.number,
                  controller: _taxCtrl,
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone Number'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Tax / GST (%)'),
                        keyboardType: TextInputType.number,
                        controller: _taxCtrl,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Physical Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Receipt Footer Message',
                ),
                controller: _footerCtrl,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveBusinessProfile,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. POS & HARDWARE
  Widget _buildPOSSettings() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Point of Sale config',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_defaultPaymentMethod),
            initialValue: _normalizePaymentMethod(_defaultPaymentMethod),
            decoration: const InputDecoration(
              labelText: 'Default Payment Method',
            ),
            items: _paymentMethodValues
                .map(
                  (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _defaultPaymentMethod = v);
            },
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Enable Tip Collection on Checkout'),
            value: _enableTip,
            activeThumbColor: Theme.of(context).primaryColor,
            onChanged: (v) => setState(() => _enableTip = v),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 32, color: Colors.white12),
          const Text(
            'Receipt Printer (Thermal 80mm)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ensure your OS has the default printer correctly targeted in Settings.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () =>
                _showSimulatedAction('Test print sent to default printer!'),
            icon: const Icon(Icons.print),
            label: const Text('Test Print Receipt'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _savePosSettings,
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }

  // 3. LOYALTY & INVENTORY
  Widget _buildLoyaltyInventory() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Loyalty Engine',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable Loyalty Program'),
            value: _enableLoyalty,
            activeThumbColor: Theme.of(context).primaryColor,
            onChanged: (v) => setState(() => _enableLoyalty = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          if (isCompact) ...[
            TextField(
              decoration: const InputDecoration(
                labelText: 'Amount Spent to Earn 1 Point (\$)',
                prefixIcon: Icon(Icons.money),
              ),
              controller: _pointsEarnRateCtrl,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Points Required for \$1 Discount',
                prefixIcon: Icon(Icons.star),
              ),
              controller: _pointsRedeemRateCtrl,
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Amount Spent to Earn 1 Point (\$)',
                      prefixIcon: Icon(Icons.money),
                    ),
                    controller: _pointsEarnRateCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Points Required for \$1 Discount',
                      prefixIcon: Icon(Icons.star),
                    ),
                    controller: _pointsRedeemRateCtrl,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _pointsExpiry,
            decoration: const InputDecoration(
              labelText: 'Points Expiry Duration',
            ),
            items: [
              'Never Expire',
              '6 Months',
              '12 Months',
            ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _pointsExpiry = v);
            },
          ),
          const Divider(height: 32, color: Colors.white12),
          const Text(
            'Inventory Rules',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Auto-Deduct Linked Stock during Checkout'),
            subtitle: const Text(
              'Requires mapping items to services in Inventory tab',
            ),
            value: _autoDeductStock,
            activeThumbColor: Theme.of(context).primaryColor,
            onChanged: (v) => setState(() => _autoDeductStock = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Global Low-Stock Threshold (Default)',
            ),
            controller: _lowStockThresholdCtrl,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _saveAllSettings,
            child: const Text('Save Settings'),
          ),
        ],
          ),
        );
      },
    );
  }

  // 4. SECURITY & ACCESS
  Widget _buildSecurity() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Access Control & Permissions',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable Staff Login Mode (Limited POS Access)'),
            value: _enableStaffLogin,
            activeThumbColor: Theme.of(context).primaryColor,
            onChanged: (v) => setState(() => _enableStaffLogin = v),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 32, color: Colors.white12),
          const Text(
            'Admin Dashboard Protection',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Require PIN to enter Reports, Settings, and Expenses modules.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (isCompact) ...[
            TextField(
              decoration: const InputDecoration(labelText: 'New Admin PIN'),
              obscureText: true,
              controller: _adminPinCtrl,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Confirm Admin PIN',
              ),
              obscureText: true,
              controller: _adminPinConfirmCtrl,
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'New Admin PIN'),
                    obscureText: true,
                    controller: _adminPinCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Confirm Admin PIN',
                    ),
                    obscureText: true,
                    controller: _adminPinConfirmCtrl,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _saveAllSettings,
            child: const Text('Update Permissions'),
          ),
        ],
          ),
        );
      },
    );
  }

  // 6. BACKUP & EXPORT (Module 9)
  Widget _buildBackupExport() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Storage & Database Card
          Container(
            padding: EdgeInsets.all(isCompact ? 16 : 24),
            decoration: BoxDecoration(
              color: const Color(
                0xFF161618,
              ), // Very dark background matching mock
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompact) ...[
                  Row(
                    children: [
                      Icon(Icons.storage, color: Colors.grey[400]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Storage & Database',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _calculateStorageStats,
                      icon: const Icon(
                        Icons.refresh,
                        color: Color(0xFFFF6231),
                        size: 18,
                      ),
                      label: const Text(
                        'Refresh',
                        style: TextStyle(
                          color: Color(0xFFFF6231),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storage, color: Colors.grey[400]),
                          const SizedBox(width: 12),
                          const Text(
                            'Storage & Database',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _calculateStorageStats,
                        icon: const Icon(
                          Icons.refresh,
                          color: Color(0xFFFF6231),
                          size: 18,
                        ),
                        label: const Text(
                          'Refresh',
                          style: TextStyle(
                            color: Color(0xFFFF6231),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                _buildStatRow('Database size', _dbSize),
                const SizedBox(height: 12),
                _buildStatRow('Backup folder size', _backupSize),
                const SizedBox(height: 12),
                _buildStatRow('Total records', _totalRecords),
                const SizedBox(height: 12),
                _buildStatRow('Last backup', 'Never'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Application Info Card
          Container(
            padding: EdgeInsets.all(isCompact ? 16 : 24),
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Application Info',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Version: 1.0.0',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const Text(
                  'Database: SQLite (Local) — SQLite ORM',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const Text(
                  'Framework: Flutter + Provider',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const Text(
                  'Phase: Phase 1 — Offline',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const Text(
                  'Future-ready for: Cloud sync, Android, Multi-device',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                if (isCompact) ...[
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Check for Updates'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Last checked: Never',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ] else
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Check for Updates'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Last checked: Never',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (isCompact) ...[
                  ElevatedButton.icon(
                      onPressed: () async {
                        if (kIsWeb) return;
                        try {
                          final dir = await getApplicationDocumentsDirectory();
                          final dbFile = File(
                            '${dir.path}${Platform.pathSeparator}salon_pos.db',
                          );
                          if (await dbFile.exists()) {
                            final targetDir = await getDownloadsDirectory();
                            if (targetDir != null) {
                              final backupFile = File(
                                '${targetDir.path}${Platform.pathSeparator}SPS_DB_Backup_${DateTime.now().millisecondsSinceEpoch}.db',
                              );
                              await dbFile.copy(backupFile.path);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Database backed up to Downloads!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _calculateStorageStats();
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Backup failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Backup DB Now'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          FilePickerResult? result = await FilePicker.platform
                              .pickFiles(type: FileType.any);

                          if (result != null &&
                              result.files.single.path != null) {
                            String filePath = result.files.single.path!;
                            String fileName = result.files.single.name
                                .toLowerCase();

                            _confirmDangerAction(
                              'Restore Data',
                              'This will wipe your current database and replace it. Continue?',
                              () async {
                                final provider = context.read<AppProvider>();
                                if (fileName.endsWith('.json')) {
                                  final content = await File(
                                    filePath,
                                  ).readAsString();
                                  await provider.importAllDataFromJSON(content);
                                } else if (fileName.endsWith('.db')) {
                                  final dir =
                                      await getApplicationDocumentsDirectory();
                                  final dbPath =
                                      '${dir.path}${Platform.pathSeparator}salon_pos.db';
                                  await File(filePath).copy(dbPath);
                                  await provider.init();
                                }
                                _calculateStorageStats();
                              },
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Restore failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Restore File'),
                    ),
                ] else
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (kIsWeb) return;
                          try {
                            final dir = await getApplicationDocumentsDirectory();
                            final dbFile = File(
                              '${dir.path}${Platform.pathSeparator}salon_pos.db',
                            );
                            if (await dbFile.exists()) {
                              final targetDir = await getDownloadsDirectory();
                              if (targetDir != null) {
                                final backupFile = File(
                                  '${targetDir.path}${Platform.pathSeparator}SPS_DB_Backup_${DateTime.now().millisecondsSinceEpoch}.db',
                                );
                                await dbFile.copy(backupFile.path);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Database backed up to Downloads!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _calculateStorageStats();
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Backup failed: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Backup DB Now'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            FilePickerResult? result = await FilePicker.platform
                                .pickFiles(type: FileType.any);

                            if (result != null &&
                                result.files.single.path != null) {
                              String filePath = result.files.single.path!;
                              String fileName = result.files.single.name
                                  .toLowerCase();

                              if (!fileName.endsWith('.db') &&
                                  !fileName.endsWith('.json')) {
                                throw Exception(
                                  'Unsupported file format. Use .db or .json',
                                );
                              }

                              final appDir =
                                  await getApplicationDocumentsDirectory();
                              final target = File(
                                '${appDir.path}${Platform.pathSeparator}salon_pos.db',
                              );
                              await File(filePath).copy(target.path);

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Database restored successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              await context.read<AppProvider>().init();
                              _calculateStorageStats();
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Restore failed: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Restore File'),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    'Enable Auto-Backup (Weekly File Generation)',
                  ),
                  value: _enableAutoBackup,
                  activeThumbColor: Theme.of(context).primaryColor,
                  onChanged: (v) {
                    setState(() => _enableAutoBackup = v);
                    _saveAutoBackupFlag();
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Excel / CSV Batch Exports',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildExportButton('Customers List', Icons.people),
              _buildExportButton('Inventory Stock', Icons.inventory_2),
              _buildExportButton('Sales & Transactions', Icons.point_of_sale),
              _buildExportButton('Expenses Log', Icons.money_off),
              _buildExportButton('Payroll History', Icons.work_history),
            ],
          ),
          const SizedBox(height: 48),
          _buildDangerZone(),
        ],
          ),
        );
      },
    );
  }

  Widget _buildDangerZone() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E0C0C), // Dark red tint background
        border: Border.all(color: const Color(0xFF331414)), // Dark red border
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF331414)),
          _buildDangerAction(
            title: 'Export All Data as JSON',
            subtitle: 'Download complete data backup as JSON file',
            buttonText: 'Export JSON',
            buttonColor: const Color(0xFF2ECA71),
            isFilled: true,
            titleColor: Colors.white,
            onTap: () async {
              final jsonStr = await context
                  .read<AppProvider>()
                  .exportAllDataAsJSON();
              if (kIsWeb) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Export JSON only supported on Desktop/Mobile.',
                    ),
                  ),
                );
                return;
              }
              final dir = await getDownloadsDirectory();
              if (dir != null) {
                final file = File(
                  '${dir.path}/SPS_Full_Backup_${DateTime.now().millisecondsSinceEpoch}.json',
                );
                await file.writeAsString(jsonStr);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data exported to Downloads folder!'),
                  ),
                );
              }
            },
          ),
          const Divider(height: 1, color: Color(0xFF331414)),
          _buildDangerAction(
            title: 'Clear All Data',
            subtitle:
                'Permanently delete all orders, customers, and sales data.\nStaff accounts and menu items will be kept.',
            buttonText: 'Clear Data',
            buttonColor: Colors.redAccent,
            isFilled: false,
            titleColor: Colors.redAccent,
            onTap: () async {
              _confirmDangerAction(
                'Clear All Data',
                'Are you sure you want to delete all transactions and customers?',
                () async {
                  await context.read<AppProvider>().clearAllData(
                    keepStaffAndMenu: true,
                  );
                  _calculateStorageStats();
                },
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFF331414)),
          _buildDangerAction(
            title: 'Prepare for client (demo + cloud)',
            subtitle:
                'Fresh demo categories, products, Demo Admin & Manager.\nOptionally clears this Shop ID on Supabase and uploads the demo data.\nKeeps your settings. Default logins: admin / Admin123! and manager / Manager123!',
            buttonText: 'Prepare for client',
            buttonColor: Colors.orangeAccent,
            isFilled: false,
            titleColor: Colors.orangeAccent,
            onTap: () {
              _confirmDangerAction(
                'Prepare Demo Data',
                'This will wipe all data and insert sample demo items. Proceed?',
                () async {
                  await context.read<AppProvider>().prepareForClient();
                  _calculateStorageStats();
                },
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFF331414)),
          _buildDangerAction(
            title: 'Factory Reset',
            subtitle:
                'Delete EVERYTHING including staff and menu.\nApp will return to first-launch setup screen.',
            buttonText: 'Factory Reset',
            buttonColor: const Color(0xFFF75151),
            isFilled: true,
            titleColor: const Color(0xFFF75151),
            onTap: () {
              _confirmDangerAction(
                'Factory Reset',
                'This will permanently destroy ALL your settings and database. Irreversible!',
                () async {
                  await context.read<AppProvider>().factoryReset();
                  _calculateStorageStats();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDangerAction({
    required String title,
    required String subtitle,
    required String buttonText,
    required Color buttonColor,
    required bool isFilled,
    required Color titleColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isFilled)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: onTap,
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: buttonColor,
                side: BorderSide(color: buttonColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: onTap,
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDangerAction(
    String title,
    String content,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.redAccent)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Action Executed Successfully'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton(String title, IconData icon) {
    return OutlinedButton.icon(
      onPressed: () => _exportToCSV(title),
      icon: Icon(icon, color: Colors.greenAccent),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _exportToCSV(String category) async {
    final provider = context.read<AppProvider>();
    // Ensure data is loaded
    await provider.init();
    List<List<String>> rows = [];

    if (category == 'Customers List') {
      rows.add([
        'ID',
        'Name',
        'Phone',
        'Email',
        'Gender',
        'Loyalty Points',
        'Total Spent',
        'Tier',
        'Member Since',
      ]);
      for (var c in provider.customers) {
        rows.add([
          c.id,
          c.name,
          c.phone,
          c.email,
          c.gender,
          c.loyaltyPoints.toString(),
          c.totalSpent.toStringAsFixed(2),
          c.tier,
          c.memberSince.toIso8601String(),
        ]);
      }
    } else if (category == 'Inventory Stock') {
      rows.add([
        'ID',
        'Name',
        'Category',
        'Unit',
        'Purchase Price',
        'Retail Price',
        'Stock',
        'Min Threshold',
        'Low Stock',
      ]);
      for (var i in provider.inventory) {
        rows.add([
          i.id,
          i.name,
          i.category,
          i.unit,
          i.purchasePrice.toStringAsFixed(2),
          i.sellingPrice.toStringAsFixed(2),
          i.quantity.toString(),
          i.minThreshold.toString(),
          i.isLowStock.toString(),
        ]);
      }
    } else if (category == 'Sales & Transactions') {
      rows.add([
        'ID',
        'Date',
        'Customer Name',
        'Staff Name',
        'Subtotal',
        'Discount',
        'Tip',
        'Total',
        'Payment Method',
      ]);
      for (var t in provider.transactions) {
        rows.add([
          t.id,
          t.date.toIso8601String(),
          t.customerName,
          t.staffName,
          t.subtotal.toStringAsFixed(2),
          t.discount.toStringAsFixed(2),
          t.tip.toStringAsFixed(2),
          t.total.toStringAsFixed(2),
          t.paymentMethod,
        ]);
      }
    } else if (category == 'Expenses Log') {
      rows.add([
        'ID',
        'Date',
        'Category',
        'Description',
        'Amount',
        'Payment Method',
        'Recurring',
        'Receipt',
      ]);
      for (var e in provider.expenses) {
        rows.add([
          e.id,
          e.date.toIso8601String(),
          e.category,
          e.description,
          e.amount.toStringAsFixed(2),
          e.paymentMethod,
          e.isRecurring.toString(),
          e.hasReceipt.toString(),
        ]);
      }
    } else if (category == 'Payroll History') {
      rows.add(['Staff Name', 'Date', 'Service', 'Amount', 'Commission']);
      for (var s in provider.staff) {
        for (var h in s.commissionHistory) {
          rows.add([
            s.name,
            h.date.toIso8601String(),
            h.service,
            h.amount.toStringAsFixed(2),
            h.commission.toStringAsFixed(2),
          ]);
        }
      }
    } else {
      return;
    }

    String csvContent = rows
        .map(
          (e) => e
              .map((val) {
                if (val.contains(',') || val.contains('"')) {
                  return '"${val.replaceAll('"', '""')}"';
                }
                return val;
              })
              .join(','),
        )
        .join('\n');

    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Web CSV export not supported offline. Run as Windows app.',
            ),
          ),
        );
        return;
      }

      final dir = await getDownloadsDirectory();
      if (dir != null) {
        final filename = category.replaceAll(' & ', '_').replaceAll(' ', '_');
        final f = File('${dir.path}/SPS_$filename.csv');
        await f.writeAsString(csvContent);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully exported to Downloads!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access Downloads directory.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSavedSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully!')),
    );
  }

  void _showSimulatedAction(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('System Process'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
