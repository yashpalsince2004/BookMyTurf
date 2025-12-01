import 'package:flutter/material.dart';
import 'dart:ui'; // Required for ImageFilter

// ---------------------------------------------------------------------
// REUSABLE "LIQUID GLASS" WIDGET (OPTIMIZED)
// ---------------------------------------------------------------------
class GlassPane extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  // Toggle blur for performance
  final bool useBlur;

  const GlassPane({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.width,
    this.height,
    this.onTap,
    this.color,
    this.borderColor,
    this.useBlur = true, // Default to true, set false for scrollable lists
  });

  @override
  Widget build(BuildContext context) {
    // 1. Base Container configuration
    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.12), // Default frosted color
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );

    // 2. Performance Check: If useBlur is false, return just the container
    if (!useBlur) {
      return content;
    }

    // 3. If useBlur is true, wrap in BackdropFilter (Heavy)
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: content,
      ),
    );
  }
}