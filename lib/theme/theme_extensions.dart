import 'package:flutter/material.dart';
import 'app_colors.dart';

extension PactsTheme on BuildContext {
  Color get primary => AppColors.gold;
  Color get background => AppColors.backgroundDark;
  Color get surface => AppColors.backgroundCard;
  Color get surfaceAlt => AppColors.backgroundSurface;
  Color get textPrimary => AppColors.textPrimary;
  Color get textSecondary => AppColors.textSecondary;
  Color get textDisabled => AppColors.textDisabled;
  
  Color get success => AppColors.success;
  Color get error => AppColors.error;
  Color get warning => AppColors.warning;
  Color get info => AppColors.info;
  Color get pending => AppColors.pending;
  
  Color get goldGlow => AppColors.goldGlow;
  Color get shadowLight => AppColors.shadowLight;
  Color get shadowMedium => AppColors.shadowMedium;
  Color get shadowHeavy => AppColors.shadowHeavy;
  
  TextStyle get titleStyle => Theme.of(this).textTheme.titleLarge!;
  TextStyle get bodyStyle => Theme.of(this).textTheme.bodyMedium!;
  TextStyle get captionStyle => Theme.of(this).textTheme.bodySmall!;
  
  BorderRadius get borderRadius8 => BorderRadius.circular(8);
  BorderRadius get borderRadius10 => BorderRadius.circular(10);
  BorderRadius get borderRadius12 => BorderRadius.circular(12);
  BorderRadius get borderRadius16 => BorderRadius.circular(16);
  BorderRadius get borderRadius20 => BorderRadius.circular(20);
  BorderRadius get borderRadius24 => BorderRadius.circular(24);
  
  BoxDecoration get cardDecoration => BoxDecoration(
    color: AppColors.backgroundCard,
    borderRadius: borderRadius20,
    border: Border.all(color: AppColors.gold.withOpacity(0.1)),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowMedium,
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
  
  BoxDecoration get inputDecoration => BoxDecoration(
    color: AppColors.backgroundSurface,
    borderRadius: borderRadius16,
    border: Border.all(color: AppColors.border),
  );
  
  BoxDecoration get goldButtonDecoration => BoxDecoration(
    gradient: AppColors.createGoldGradient(),
    borderRadius: borderRadius16,
    boxShadow: AppColors.createGoldGlow(),
  );
  
  List<BoxShadow> get goldShadow => AppColors.createGoldGlow();
  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: AppColors.shadowMedium,
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  LinearGradient get goldGradient => AppColors.createGoldGradient();
  
  WidgetStateProperty<Color?> get pressEffect => 
    WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return AppColors.rippleColor;
      }
      return null;
    });
}

class PactsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? elevation;
  
  const PactsCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.backgroundCard;
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: context.borderRadius20,
        border: Border.all(color: AppColors.gold.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: context.borderRadius20,
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            )
          : Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;
  
  const GoldButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: context.borderRadius16,
          child: Container(
            decoration: context.goldButtonDecoration,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.backgroundDark,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: AppColors.backgroundDark, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          text.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.backgroundDark,
                            letterSpacing: 1.5,
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

class OutlineGoldButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double? width;
  final double? height;
  
  const OutlineGoldButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 20, color: AppColors.gold) : null,
        label: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: BorderSide(color: AppColors.gold.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: context.borderRadius16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  
  const StatusChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.getStatusColor(label);
    
    return Chip(
      label: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      avatar: icon != null ? Icon(icon, size: 14, color: chipColor) : null,
      backgroundColor: chipColor.withOpacity(0.15),
      labelStyle: TextStyle(color: chipColor, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(
        borderRadius: context.borderRadius20,
        side: BorderSide(color: chipColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}