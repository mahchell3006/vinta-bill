import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/locale_provider.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _shopNameController = TextEditingController(text: 'My Shop');
  final _shopPhoneController = TextEditingController();
  final _shopAddressController = TextEditingController();

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopPhoneController.dispose();
    _shopAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/'); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
          title: Text(loc.tr('settings')),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Shop details
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.tr('shop_details'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _shopNameController,
                    decoration: InputDecoration(labelText: loc.tr('shop_name')),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _shopPhoneController,
                    decoration: InputDecoration(labelText: loc.tr('shop_phone')),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _shopAddressController,
                    decoration: InputDecoration(labelText: loc.tr('shop_address1')),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(loc.tr('success')),
                          backgroundColor: Colors.green[600],
                        ));
                      },
                      child: Text(loc.tr('save')),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),

            // Printer
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.tr('printer_settings'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(loc.tr('connect_printer')),
                        ));
                      },
                      icon: const Icon(Icons.bluetooth_searching),
                      label: Text(loc.tr('connect_printer')),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),

            // Language
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.tr('language'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: Text(loc.tr('french')),
                          leading: Radio<String>(
                            value: 'fr',
                            groupValue: currentLocale.languageCode,
                            onChanged: (_) => ref.read(localeProvider.notifier).setFrench(),
                          ),
                          onTap: () => ref.read(localeProvider.notifier).setFrench(),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: Text(loc.tr('arabic')),
                          leading: Radio<String>(
                            value: 'ar',
                            groupValue: currentLocale.languageCode,
                            onChanged: (_) => ref.read(localeProvider.notifier).setArabic(),
                          ),
                          onTap: () => ref.read(localeProvider.notifier).setArabic(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),
            const SizedBox(height: 20),

            // Version
            Center(
              child: Text('${loc.tr('app_title')} v1.0.0',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
