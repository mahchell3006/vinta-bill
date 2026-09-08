import 'package:flutter/material.dart';

class InputLabel extends StatelessWidget {
  final String text;
  final bool isRequired;

  const InputLabel({
    super.key,
    required this.text,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (isRequired) ...[
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
