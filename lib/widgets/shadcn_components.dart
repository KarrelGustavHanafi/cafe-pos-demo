import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Re-export shadcn_flutter primitives for easy access in screens
export 'package:shadcn_flutter/shadcn_flutter.dart'
    show
        LucideIcons,
        BootstrapIcons,
        RadixIcons;


/// Reusable Shadcn-styled Card Component
class ShadcnCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final bool isInteractive;

  const ShadcnCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
    this.isInteractive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: AppRadius.roundedLg,
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null || isInteractive) {
      return Material(
        color: Colors.transparent,
        borderRadius: AppRadius.roundedLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.roundedLg,
          hoverColor: AppColors.primarySoft.withValues(alpha: 0.5),
          splashColor: AppColors.primarySoft,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// Badge Variant enum
enum ShadBadgeVariant {
  primary,
  secondary,
  outline,
  success,
  warning,
  destructive,
  accent,
}

/// Reusable Shadcn-styled Badge Component
class ShadcnBadge extends StatelessWidget {
  final String label;
  final ShadBadgeVariant variant;
  final Widget? icon;
  final bool showDot;
  final Color? dotColor;
  final VoidCallback? onTap;

  const ShadcnBadge({
    super.key,
    required this.label,
    this.variant = ShadBadgeVariant.secondary,
    this.icon,
    this.showDot = false,
    this.dotColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case ShadBadgeVariant.primary:
        bg = AppColors.primarySoft;
        fg = AppColors.primaryDark;
        border = AppColors.primaryBorder;
        break;
      case ShadBadgeVariant.success:
        bg = AppColors.successSoft;
        fg = const Color(0xFF047857); // Green 700
        border = const Color(0xFFA7F3D0); // Green 200
        break;
      case ShadBadgeVariant.warning:
        bg = AppColors.warningSoft;
        fg = const Color(0xFFB45309); // Amber 700
        border = const Color(0xFFFDE68A); // Amber 200
        break;
      case ShadBadgeVariant.destructive:
        bg = AppColors.dangerSoft;
        fg = const Color(0xFFB91C1C); // Red 700
        border = const Color(0xFFFECACA); // Red 200
        break;
      case ShadBadgeVariant.accent:
        bg = AppColors.accentAmberSoft;
        fg = AppColors.accentCaramel;
        border = const Color(0xFFFDE68A);
        break;
      case ShadBadgeVariant.outline:
        bg = Colors.transparent;
        fg = AppColors.textPrimary;
        border = AppColors.border;
        break;
      case ShadBadgeVariant.secondary:
        bg = AppColors.surfaceSubtle;
        fg = AppColors.textSecondary;
        border = AppColors.border;
        break;
    }

    final badgeWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.roundedSm,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor ?? fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(size: 12, color: fg),
              child: icon!,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.status.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadius.roundedSm,
        child: badgeWidget,
      );
    }

    return badgeWidget;
  }
}

/// Button Variant enum
enum ShadButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
}

/// Reusable Shadcn-styled Button Component
class ShadcnButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final String? text;
  final Widget? child;
  final ShadButtonVariant variant;
  final bool fullWidth;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final double? height;

  const ShadcnButton({
    super.key,
    required this.onPressed,
    this.text,
    this.child,
    this.icon,
    this.variant = ShadButtonVariant.primary,
    this.fullWidth = false,
    this.isLoading = false,
    this.padding,
    this.height = 42,
  }) : assert(text != null || child != null);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide borderSide;

    switch (variant) {
      case ShadButtonVariant.primary:
        bg = AppColors.primary;
        fg = Colors.white;
        borderSide = BorderSide.none;
        break;
      case ShadButtonVariant.secondary:
        bg = AppColors.surfaceSubtle;
        fg = AppColors.textPrimary;
        borderSide = const BorderSide(color: AppColors.border, width: 1);
        break;
      case ShadButtonVariant.outline:
        bg = Colors.transparent;
        fg = AppColors.textPrimary;
        borderSide = const BorderSide(color: AppColors.border, width: 1.2);
        break;
      case ShadButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.textSecondary;
        borderSide = BorderSide.none;
        break;
      case ShadButtonVariant.destructive:
        bg = AppColors.danger;
        fg = Colors.white;
        borderSide = BorderSide.none;
        break;
    }

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          IconTheme(
            data: IconThemeData(size: 16, color: fg),
            child: icon!,
          ),
          const SizedBox(width: 8),
        ],
        if (child != null)
          Flexible(child: child!)
        else if (text != null)
          Flexible(
            child: Text(
              text!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
      ],
    );

    final buttonWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: height,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: onPressed == null ? bg.withValues(alpha: 0.5) : bg,
        borderRadius: AppRadius.roundedMd,
        border: borderSide != BorderSide.none ? Border.fromBorderSide(borderSide) : null,
      ),
      child: Center(
        widthFactor: fullWidth ? 1.0 : null,
        child: content,
      ),
    );


    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: AppRadius.roundedMd,
        hoverColor: fg.withValues(alpha: 0.08),
        splashColor: fg.withValues(alpha: 0.12),
        child: buttonWidget,
      ),
    );
  }
}

/// Reusable Shadcn-styled Text Field
class ShadcnInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? label;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType keyboardType;
  final bool obscureText;
  final int maxLines;
  final bool autofocus;

  const ShadcnInput({
    super.key,
    this.controller,
    this.hintText,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.roundedMd,
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            maxLines: maxLines,
            autofocus: autofocus,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: AppTypography.body,
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              hintStyle: AppTypography.caption.copyWith(fontSize: 13),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// Clean subtle separator
class ShadcnSeparator extends StatelessWidget {
  final double verticalPadding;
  final Color? color;

  const ShadcnSeparator({
    super.key,
    this.verticalPadding = 12.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Divider(
        height: 1,
        thickness: 1,
        color: color ?? AppColors.border,
      ),
    );
  }
}

/// Section Header with optional action or badge
class ShadcnSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ShadcnSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.sectionTitle,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
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

/// Segmented / Pill Tabs for category filtering or tab switching
class ShadcnTabs<T> extends StatelessWidget {
  final List<T> items;
  final T selectedItem;
  final ValueChanged<T> onSelected;
  final String Function(T) labelBuilder;
  final Widget Function(T)? iconBuilder;
  final int Function(T)? countBuilder;
  final bool scrollable;

  const ShadcnTabs({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onSelected,
    required this.labelBuilder,
    this.iconBuilder,
    this.countBuilder,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final tabButtons = items.map((item) {
      final isSelected = item == selectedItem;
      final label = labelBuilder(item);
      final icon = iconBuilder?.call(item);
      final count = countBuilder?.call(item);

      return Padding(
        padding: const EdgeInsets.only(right: 6.0),
        child: InkWell(
          onTap: () => onSelected(item),
          borderRadius: AppRadius.roundedMd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surface,
              borderRadius: AppRadius.roundedMd,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  IconTheme(
                    data: IconThemeData(
                      size: 15,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                    child: icon,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : AppColors.surfaceSubtle,
                      borderRadius: AppRadius.roundedFull,
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: tabButtons),
      );
    }

    return Row(
      children: tabButtons.map((t) => Expanded(child: t)).toList(),
    );
  }
}

/// Interactive selection tile for modifiers (Radio option style)
class ShadcnSelectionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? priceExtra;
  final bool isSelected;
  final VoidCallback onTap;

  const ShadcnSelectionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.priceExtra,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.roundedMd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: AppRadius.roundedMd,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 5.5 : 1.5,
                ),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.caption,
                    ),
                  ],
                ],
              ),
            ),
            if (priceExtra != null) ...[
              Text(
                priceExtra!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Interactive checkbox tile for add-ons / multiple selections
class ShadcnCheckboxTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? priceExtra;
  final bool isChecked;
  final ValueChanged<bool> onChanged;

  const ShadcnCheckboxTile({
    super.key,
    required this.title,
    this.subtitle,
    this.priceExtra,
    required this.isChecked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!isChecked),
      borderRadius: AppRadius.roundedMd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isChecked ? AppColors.primarySoft : AppColors.surface,
          borderRadius: AppRadius.roundedMd,
          border: Border.all(
            color: isChecked ? AppColors.primary : AppColors.border,
            width: isChecked ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isChecked ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: isChecked ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? const Icon(
                      Icons.check,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isChecked ? FontWeight.w600 : FontWeight.w500,
                      color: isChecked ? AppColors.primaryDark : AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.caption,
                    ),
                  ],
                ],
              ),
            ),
            if (priceExtra != null) ...[
              Text(
                priceExtra!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isChecked ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standardized Shadcn-styled Dialog wrapper
class ShadcnDialog extends StatelessWidget {
  final String title;
  final String? description;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final double? maxHeight;

  const ShadcnDialog({
    super.key,
    required this.title,
    this.description,
    required this.content,
    this.actions,
    this.maxWidth = 540,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight ?? (MediaQuery.of(context).size.height * 0.88),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.roundedLg,
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.sectionTitle.copyWith(fontSize: 17),
                            ),
                            if (description != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                description!,
                                style: AppTypography.caption,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 20),
                        color: AppColors.textSecondary,
                        splashRadius: 18,
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: content,
                  ),
                ),
                // Footer Actions
                if (actions != null && actions!.isNotEmpty) ...[
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
