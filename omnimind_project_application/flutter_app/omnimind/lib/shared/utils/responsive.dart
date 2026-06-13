import 'package:flutter/material.dart';

/// Responsive utility class for calculating adaptive values based on screen size
class Responsive {
  // Screen dimensions
  static late double width;
  static late double height;
  static late double pixelRatio;
  static late bool isTablet;
  static late bool isDesktop;
  static late bool isMobile;

  // Breakpoints
  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 900;

  /// Initialize responsive values - must be called in build() context
  static void init(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    width = mediaQuery.size.width;
    height = mediaQuery.size.height;
    pixelRatio = mediaQuery.devicePixelRatio;
    isTablet = width >= tabletBreakpoint && width < desktopBreakpoint;
    isDesktop = width >= desktopBreakpoint;
    isMobile = width < tabletBreakpoint;
  }

  /// Calculate responsive width percentage
  static double wp(double percent) => width * percent / 100;

  /// Calculate responsive height percentage
  static double hp(double percent) => height * percent / 100;

  /// Calculate responsive font size based on the shorter side (percent of shortest side)
  static double spPercent(double percent) {
    final shortestSide = width < height ? width : height;
    return shortestSide * percent / 100;
  }



  /// Get responsive font size with scaling
  static double sp(double percent) => shorterSidePercent(percent);

  static double fontSize(double baseSize) {

    // Base font size calculation
    double factor = 1.0;
    if (isTablet) {
      factor = 1.1;
    } else if (isDesktop) {
      factor = 1.2;
    }
    return baseSize * factor;
  }

  /// Get responsive spacing
  static double spacing(double baseSize) {
    double factor = 1.0;
    if (isTablet) {
      factor = 1.2;
    } else if (isDesktop) {
      factor = 1.5;
    }
    return baseSize * factor;
  }

  /// Get responsive padding
  static EdgeInsets padding(double all) {
    return EdgeInsets.all(spacing(all));
  }

  /// Get responsive border radius
  static BorderRadius borderRadius(double radius) {
    return BorderRadius.circular(rs(radius));
  }



  // Helper: interpret legacy "percent"-style values.
  // Most usages in the UI treat inputs like 2.4 => 2.4% of shorter side.
  static double shorterSidePercent(double percent) {
    final shortestSide = width < height ? width : height;
    return shortestSide * percent / 100;
  }

  // Legacy APIs expected by the UI
  static double rs(double percent) => shorterSidePercent(percent);
  static double rw(double percent) => wp(percent);
  static double rh(double percent) => hp(percent);
  static double rf(double baseSize) => fontSize(baseSize);

  // Padding helpers used in dashboard
  static EdgeInsets paddingOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  static EdgeInsets paddingAll(double all) => EdgeInsets.all(all);

  static EdgeInsets paddingSymmetry({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  static EdgeInsets paddingSymmetric({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }



  /// Get responsive icon size
  static double iconSize(double baseSize) {
    return fontSize(baseSize);
  }

  /// Determine number of columns for grid layouts
  static int gridColumnCount({
    int mobileColumns = 2,
    int tabletColumns = 3,
    int desktopColumns = 4,
  }) {
    if (isDesktop) return desktopColumns;
    if (isTablet) return tabletColumns;
    return mobileColumns;
  }

  /// Determine if we should use expanded layout (sidebar + main content)
  static bool shouldUseExpandedLayout() {
    return isTablet || isDesktop;
  }
}

/// Extension for easy access to responsive values in BuildContext
extension ResponsiveExtension on BuildContext {
  double get wp => Responsive.width;
  double get hp => Responsive.height;
  double get sp => Responsive.sp(1);
  double get dp => Responsive.sp(1);
  
  double rw(double percent) => Responsive.wp(percent);
  double rh(double percent) => Responsive.hp(percent);
  double rs(double percent) => Responsive.sp(percent);
  
  double rf(double baseSize) => Responsive.fontSize(baseSize);
  double rsSpacing(double baseSize) => Responsive.spacing(baseSize);
  
  bool get isTablet => Responsive.isTablet;
  bool get isDesktop => Responsive.isDesktop;
  bool get isMobile => Responsive.isMobile;
  
  int get gridColumnCount => Responsive.gridColumnCount();
  bool get shouldUseExpandedLayout => Responsive.shouldUseExpandedLayout();
}