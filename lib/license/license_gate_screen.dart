import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'license_models.dart';
import 'license_service.dart';

class LicenseGateScreen extends StatefulWidget {
  const LicenseGateScreen({
    super.key,
    required this.activeChild,
  });

  final Widget activeChild;

  @override
  State<LicenseGateScreen> createState() => _LicenseGateScreenState();
}

class _LicenseGateScreenState extends State<LicenseGateScreen> {
  final LicenseService _service = LicenseService();
  late Future<LicenseGateResult> _gateFuture;

  @override
  void initState() {
    super.initState();
    _gateFuture = _service.evaluateOnLaunch();
  }

  void _reload() {
    setState(() => _gateFuture = _service.evaluateOnLaunch());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LicenseGateResult>(
      future: _gateFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final result = snapshot.data!;
        switch (result.state) {
          case LicenseGateState.active:
            return widget.activeChild;
          case LicenseGateState.notActivated:
            return ActivationScreen(
              service: _service,
              onActivated: _reload,
              message: result.message,
            );
          case LicenseGateState.expired:
            return BlockedLicenseScreen(
              title: 'License Expired',
              description: 'License expired. Contact Ahmad.',
              extra:
                  'Expiry date: ${result.license != null ? _service.formatDate(result.license!.expiryDate) : '-'}',
            );
          case LicenseGateState.deactivated:
            return const BlockedLicenseScreen(
              title: 'License Deactivated',
              description: 'License deactivated. Contact Ahmad.',
            );
          case LicenseGateState.onlineCheckRequired:
            return BlockedLicenseScreen(
              title: 'Online Verification Needed',
              description:
                  result.message ??
                  'Please connect to WiFi to verify your license. Contact: +92-313-6625199',
              actionLabel: 'Retry Check',
              onAction: _reload,
            );
        }
      },
    );
  }
}

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({
    super.key,
    required this.service,
    required this.onActivated,
    this.message,
  });

  final LicenseService service;
  final VoidCallback onActivated;
  final String? message;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _shopCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _shopCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final shopId = _shopCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    if (shopId.isEmpty || key.isEmpty) {
      setState(() => _error = 'Shop ID and Activation Key are required.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.service.activate(shopId: shopId, activationKey: key);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.state == LicenseGateState.active) {
      widget.onActivated();
      return;
    }
    setState(() => _error = result.message ?? 'Activation failed.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            color: theme.cardColor,
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activate ATA-Styles-POS',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'First-time activation requires internet connection.',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _shopCtrl,
                    decoration: const InputDecoration(labelText: 'Shop ID'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyCtrl,
                    decoration: const InputDecoration(labelText: 'Activation Key'),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null || widget.message != null)
                    Text(
                      _error ?? widget.message!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _activate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Activate License'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BlockedLicenseScreen extends StatelessWidget {
  const BlockedLicenseScreen({
    super.key,
    required this.title,
    required this.description,
    this.extra,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final String? extra;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block, size: 44, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(description, textAlign: TextAlign.center),
                  if (extra != null) ...[
                    const SizedBox(height: 8),
                    Text(extra!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Support: +92-313-6625199',
                    style: TextStyle(color: Colors.grey),
                  ),
                  if (onAction != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: onAction,
                      child: Text(actionLabel ?? 'Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
