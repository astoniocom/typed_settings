import 'package:material_ui/material_ui.dart';

/// The row a settings tile is built on: icon, title, subtitle and trailing.
///
/// Checkbox and switch tiles are their own Material list tiles. They use
/// [title] and [subtitleText], so the wording of a row still lives here.
class SettingsTile extends StatelessWidget {
  /// Creates a row titled [label].
  const SettingsTile({
    required this.label,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    super.key,
  });

  /// The title of the row.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// The widget after the title.
  ///
  /// `ListTile` offers it the whole row and fails when it takes all of it,
  /// so a text of any length must be bounded and ellipsized.
  final Widget? trailing;

  /// Called when the row is tapped.
  final VoidCallback? onTap;

  /// The title text of a settings row.
  static Widget title(String label) => Text(label);

  /// The subtitle text, or null when [subtitle] is null.
  static Widget? subtitleText(String? subtitle) => subtitle == null ? null : Text(subtitle);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon,
      title: title(label),
      subtitle: subtitleText(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
