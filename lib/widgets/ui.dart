import 'package:flutter/material.dart';

const kRed = Color(0xFFD32F2F);
const kRedDark = Color(0xFF8E1B1B);

const kHeroGradient = LinearGradient(
  colors: [kRed, kRedDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Rounded, softly-bordered card used everywhere instead of the default Card.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.onTap,
    this.borderColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? (dark ? scheme.surfaceContainer : Colors.white),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor ?? scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// App logo: white circle with a red blood drop.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(Icons.water_drop, color: kRed, size: size * 0.56),
    );
  }
}

/// Small coloured label, e.g. URGENT.
class Tag extends StatelessWidget {
  final String text;
  final Color color;
  final Color? textColor;
  final IconData? icon;
  const Tag(this.text,
      {super.key, required this.color, this.textColor, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                  color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}
