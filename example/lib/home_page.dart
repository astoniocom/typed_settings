import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_example/app_settings.dart';
import 'package:typed_settings_example/settings_page.dart';
import 'package:typed_settings_flutter/typed_settings_flutter.dart';

/// The settings of one storage, shown on a tab named `title`.
typedef StorageTab = ({String title, AppSettings settings});

class HomePage extends StatelessWidget {
  const HomePage({required this.tabs, super.key});

  final List<StorageTab> tabs;

  @override
  Widget build(BuildContext context) {
    return SettingsErrorHandlerProvider(
      handler: const SnackbarSettingsErrorHandler(),
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('typed_settings'),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final tab in tabs) Tab(text: tab.title)],
            ),
          ),
          body: TabBarView(
            children: [
              for (final tab in tabs)
                _SettingsTheme(
                  settings: tab.settings,
                  child: SettingsPage(settings: tab.settings),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Themes [child] by the theme mode and accent color of [settings], so
/// that each tab shows its own.
class _SettingsTheme extends StatelessWidget {
  const _SettingsTheme({required this.settings, required this.child});

  final AppSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        settings.themeMode,
        settings.accentColor,
      ]),
      builder: (context, child) {
        final brightness = switch (settings.themeMode.value) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
        return Theme(
          data: ThemeData(
            colorSchemeSeed: settings.accentColor.value,
            brightness: brightness,
          ),
          child: Material(child: child),
        );
      },
      child: child,
    );
  }
}
