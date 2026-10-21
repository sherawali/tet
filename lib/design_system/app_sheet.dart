import 'package:flutter/material.dart';
import 'app_colors.dart';

/// One look for every bottom sheet of the app.
///
/// The sheet surface, the corner radius, the barrier and the little drag
/// handle are defined once, so no sheet has to invent its own style.
class AppSheet {
  const AppSheet._();

  /// Opens a sheet with the shared look.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool useRootNavigator = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: builder,
    );
  }

  /// The drag handle that sits at the top of every sheet.
  static Widget handle({bool isDark = false, double width = 42}) {
    return Center(
      child: Container(
        width: width,
        height: 5,
        decoration: BoxDecoration(
          color: isDark ? Colors.white24 : Colors.black12,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// The surface a sheet is painted on.
  static BoxDecoration surface({required bool isDark, double topRadius = 24}) {
    return BoxDecoration(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        width: 1.2,
      ),
    );
  }
}
