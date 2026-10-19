import 'package:flutter/material.dart';

import '../theme.dart';

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Palette.surface,
    this.borderColor = Palette.line,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: AppText.heading.copyWith(fontSize: 24, height: 1.25)),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(fontSize: 13, color: Palette.muted)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(label, style: AppText.heading.copyWith(fontSize: 17)),
            ),
          ),
          if (trailing != null) Text(trailing!, style: const TextStyle(fontSize: 13, color: Palette.muted)),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Palette.accent : null,
              border: active ? null : Border.all(color: Palette.muted, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, color: Palette.textSoft)),
        ],
      ),
    );
  }
}

class SegmentMeter extends StatelessWidget {
  const SegmentMeter({super.key, required this.filled, this.count = 4, this.height = 6});

  final int filled;
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: height,
                decoration: BoxDecoration(
                  color: i < filled ? Palette.accent : Palette.line,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag({super.key, required this.label, this.heat = false});

  final String label;
  final bool heat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: heat ? Palette.heatLine : Palette.line),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: heat ? Palette.heat : Palette.muted),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.heat = false, this.size = 40});

  final IconData icon;
  final bool heat;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: heat ? Palette.heatTile : Palette.raised,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, size: size * 0.55, color: heat ? Palette.heat : Palette.text),
      ),
    );
  }
}

class InsetDivider extends StatelessWidget {
  const InsetDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: indent);
}
