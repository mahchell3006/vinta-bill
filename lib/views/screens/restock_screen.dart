import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';

class RestockScreen extends ConsumerWidget {
  const RestockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: Text(loc.tr('restock')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  loc.tr('restock'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),

                // Coming Soon badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber[300]!),
                  ),
                  child: Text(
                    loc.tr('coming_soon'),
                    style: TextStyle(
                      color: Colors.amber[800],
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  loc.tr('restock_coming_soon_desc'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
