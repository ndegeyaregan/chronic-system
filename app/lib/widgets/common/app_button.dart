import 'package:flutter/material.dart';
import '../../core/constants.dart';

enum AppButtonVariant { primary, secondary, outlined, danger, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final IconData? leadingIcon;
  final double? height;
  final double? fontSize;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.leadingIcon,
    this.height,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? 52.0;

    if (variant == AppButtonVariant.primary) {
      return _GradientButton(
        label: label,
        onPressed: isLoading ? null : onPressed,
        isLoading: isLoading,
        fullWidth: fullWidth,
        height: h,
        leadingIcon: leadingIcon,
        fontSize: fontSize,
        gradient: kPrimaryGradient,
      );
    }

    if (variant == AppButtonVariant.secondary) {
      return _GradientButton(
        label: label,
        onPressed: isLoading ? null : onPressed,
        isLoading: isLoading,
        fullWidth: fullWidth,
        height: h,
        leadingIcon: leadingIcon,
        fontSize: fontSize,
        gradient: kAccentGradient,
      );
    }

    if (variant == AppButtonVariant.danger) {
      return _GradientButton(
        label: label,
        onPressed: isLoading ? null : onPressed,
        isLoading: isLoading,
        fullWidth: fullWidth,
        height: h,
        leadingIcon: leadingIcon,
        fontSize: fontSize,
        gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
      );
    }

    if (variant == AppButtonVariant.outlined) {
      return SizedBox(
        width: fullWidth ? double.infinity : null,
        height: h,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: kPrimary, width: 1.5),
            foregroundColor: kPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadiusMd)),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: kPrimary))
              : _ButtonContent(
                  label: label,
                  leadingIcon: leadingIcon,
                  fontSize: fontSize,
                  color: kPrimary),
        ),
      );
    }

    // ghost
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: h,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: kPrimary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusMd)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kPrimary))
            : _ButtonContent(
                label: label,
                leadingIcon: leadingIcon,
                fontSize: fontSize,
                color: kPrimary),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool fullWidth;
  final double height;
  final IconData? leadingIcon;
  final double? fontSize;
  final LinearGradient gradient;

  const _GradientButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.fullWidth,
    required this.height,
    required this.gradient,
    this.leadingIcon,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(kRadiusMd),
          child: Ink(
            decoration: BoxDecoration(
              gradient: onPressed == null
                  ? const LinearGradient(
                      colors: [Color(0xFFB0BEC5), Color(0xFF90A4AE)])
                  : gradient,
              borderRadius: BorderRadius.circular(kRadiusMd),
              boxShadow: onPressed == null
                  ? []
                  : [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white)))
                  : _ButtonContent(
                      label: label,
                      leadingIcon: leadingIcon,
                      fontSize: fontSize,
                      color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final double? fontSize;
  final Color color;

  const _ButtonContent({
    required this.label,
    required this.color,
    this.leadingIcon,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 18, color: color),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize ?? 15,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}