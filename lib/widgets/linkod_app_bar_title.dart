import 'package:flutter/material.dart';

class LinkodAppBarTitle extends StatelessWidget {
  final TextStyle? prefixStyle;
  final TextStyle? suffixStyle;

  const LinkodAppBarTitle({super.key, this.prefixStyle, this.suffixStyle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultPrefixStyle = prefixStyle ??
        TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.5,
          color: colorScheme.onPrimary,
        );
    final defaultSuffixStyle = suffixStyle ??
        TextStyle(
          fontWeight: FontWeight.w300,
          fontSize: 24,
          color: colorScheme.onPrimary,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.onPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('LINK', style: defaultPrefixStyle),
        ),
        const SizedBox(width: 6),
        Text('od', style: defaultSuffixStyle),
      ],
    );
  }
}
