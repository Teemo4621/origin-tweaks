import 'package:flutter/material.dart';

class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.background, this.foreground, this.size = 40});

  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.55, color: foreground ?? scheme.onSecondaryContainer),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.children = const [],
    this.color,
    this.iconBackground,
    this.iconForeground,
  });

  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> children;
  final Color? color;
  final Color? iconBackground;
  final Color? iconForeground;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, background: iconBackground, foreground: iconForeground),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(title, style: text.titleMedium),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 4),
                    Text(body!, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                  if (children.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...children,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NumberedStep extends StatelessWidget {
  const NumberedStep({super.key, required this.number, required this.text, this.done = false, this.detail});

  final int number;
  final String text;
  final String? detail;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? scheme.primary : scheme.surfaceContainerHighest,
            ),
            child: done
                ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                : Text('$number', style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    text,
                    style: textTheme.bodyLarge?.copyWith(
                      color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (detail != null && !done)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(detail!, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
