// Not exported: @Preview requires public top-level functions, and the
// previews are not part of the package API.
import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_flutter/typed_settings_flutter.dart';

/// A preview of [BoolCheckboxSettingTile].
@Preview(name: 'BoolCheckboxSettingTile')
Widget previewBoolCheckboxSettingTile() {
  return BoolCheckboxSettingTile(
    setting: BoolSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: true,
    ),
    label: 'Test',
  );
}

/// A preview of [BoolNullableDropdownSettingTile].
@Preview(name: 'BoolNullableDropdownSettingTile')
Widget previewBoolNullableDropdownSettingTile() {
  return BoolNullableDropdownSettingTile(
    setting: BoolNullableSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: true,
    ),
    label: 'Test',
  );
}

/// A preview of [BoolNullableCheckboxSettingTile].
@Preview(name: 'BoolNullableCheckboxSettingTile')
Widget previewBoolNullableCheckboxSettingTile() {
  return BoolNullableCheckboxSettingTile(
    setting: BoolNullableSetting(
      storage: InMemoryStorage(),
      key: 'test',
    ),
    label: 'Test',
  );
}

/// A preview of [BoolSwitchSettingTile].
@Preview(name: 'BoolSwitchSettingTile')
Widget previewBoolSwitchSettingTile() {
  return BoolSwitchSettingTile(
    setting: BoolSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: true,
    ),
    label: 'Test',
  );
}

/// A preview of [ColorNullableSettingTile].
@Preview(name: 'ColorNullableSettingTile')
Widget previewColorNullableSettingTile() {
  return ColorNullableSettingTile(
    setting: ColorNullableSetting(
      storage: InMemoryStorage(),
      key: 'test',
      validator: SettingValidator(
        (value) => value == Colors.red
            ? ForbiddenValueValidationError(
                value,
                debugDescription: 'Red is not allowed',
              )
            : null,
      ),
    ),
    label: 'Test',
  );
}

/// A preview of [ColorSettingTile].
@Preview(name: 'ColorSettingTile')
Widget previewColorSettingTile() {
  return ColorSettingTile(
    setting: ColorSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: Colors.green,
      validator: SettingValidator(
        (value) => value == Colors.red
            ? const ForbiddenValueValidationError(
                Colors.red,
                debugDescription: 'Red is not allowed',
              )
            : null,
      ),
    ),
    label: 'Test',
  );
}

/// A preview of [DateTimeNullableSettingTile].
@Preview(name: 'DateTimeNullableSettingTile')
Widget previewDateTimeNullableSettingTile() {
  return DateTimeNullableSettingTile(
    setting: DateTimeNullableSetting(
      storage: InMemoryStorage(),
      key: 'test',
    ),
    label: 'Test',
  );
}

/// A preview of [DateTimeSettingTile].
@Preview(name: 'DateTimeSettingTile')
Widget previewDateTimeSettingTile() {
  return DateTimeSettingTile(
    setting: DateTimeSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: DateTime.now(),
    ),
    label: 'Test',
  );
}

/// A preview of [DoubleNullableSettingTile].
@Preview(name: 'DoubleNullableSettingTile')
Widget previewDoubleNullableSettingTile() {
  return DoubleNullableSettingTile(
    setting: DoubleNullableSetting(
      storage: InMemoryStorage(),
      key: 'test',
    ),
    label: 'Test',
  );
}

/// A preview of [DoubleSettingTile].
@Preview(name: 'DoubleSettingTile')
Widget previewDoubleSettingTile() {
  return DoubleSettingTile(
    setting: DoubleSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: 0.5,
    ),
    label: 'Test',
  );
}

/// A preview of [DurationNullableSettingTile].
@Preview(name: 'DurationNullableSettingTile')
Widget previewDurationNullableSettingTile() {
  return DurationNullableSettingTile(
    setting: DurationNullableSetting(
      storage: InMemoryStorage(),
      key: 'test',
    ),
    label: 'Test',
  );
}

/// A preview of [DurationSettingTile].
@Preview(name: 'DurationSettingTile')
Widget previewDurationSettingTile() {
  return DurationSettingTile(
    setting: DurationSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: const Duration(minutes: 5),
    ),
    label: 'Test',
  );
}

/// A preview of [EnumNullableSettingTile].
@Preview(name: 'EnumNullableSettingTile')
Widget previewEnumNullableSettingTile() {
  return EnumNullableSettingTile(
    setting: EnumNullableSetting(
      storage: InMemoryStorage(),
      key: 'test',
      values: BlendMode.values,
    ),
    label: 'Test',
  );
}

/// A preview of [EnumSettingTile].
@Preview(name: 'EnumSettingTile')
Widget previewEnumSettingTile() {
  return EnumSettingTile(
    setting: EnumSetting(
      storage: InMemoryStorage(),
      key: 'test',
      values: BlendMode.values,
      defaultValue: BlendMode.multiply,
    ),
    label: 'Test',
  );
}

/// A preview of [IntListSettingTile].
@Preview(name: 'IntListSettingTile')
Widget previewIntListSettingTile() {
  return IntListSettingTile(
    setting: IntListSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: [1, 2, 3],
    ),
    label: 'Test',
  );
}

/// A preview of [IntNullableSettingTile].
@Preview(name: 'IntNullableSettingTile')
Widget previewIntNullableSettingTile() {
  return IntNullableSettingTile(
    setting: IntNullableSetting(
      storage: InMemoryStorage(),
      key: 'test',
    ),
    label: 'Test',
  );
}

/// A preview of [IntSettingTile].
@Preview(name: 'IntSettingTile')
Widget previewIntSettingTile() {
  return IntSettingTile(
    setting: IntSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: 1,
    ),
    label: 'Test',
  );
}

/// A preview of [MapNullableSettingTile].
@Preview(name: 'MapNullableSettingTile')
Widget previewMapNullableSettingTile() {
  return MapNullableSettingTile(
    setting: MapNullableSetting(
      storage: InMemoryStorage(),
      key: 'test',
    ),
    label: 'Test',
  );
}

/// A preview of [MapSettingTile].
@Preview(name: 'MapSettingTile')
Widget previewMapSettingTile() {
  return MapSettingTile(
    setting: MapSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: {'a': 1, 'b': 2},
    ),
    label: 'Test',
  );
}

/// A preview of [StringListSettingTile].
@Preview(name: 'StringListSettingTile')
Widget previewStringListSettingTile() {
  return StringListSettingTile(
    setting: StringListSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: ['a', 'b', 'c'],
    ),
    label: 'Test',
  );
}

/// A preview of [StringNullableSettingTile].
@Preview(name: 'StringNullableSettingTile')
Widget previewStringNullableSettingTile() {
  return StringNullableSettingTile(
    setting: StringNullableSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: 'test',
    ),
    label: 'Test',
  );
}

/// A preview of [StringSettingTile].
@Preview(name: 'StringSettingTile')
Widget previewStringSettingTile() {
  return StringSettingTile(
    setting: StringSetting(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: 'test',
    ),
    label: 'Test',
  );
}

/// A preview of [ThemeSettingTile].
@Preview(name: 'ThemeSettingTile')
Widget previewThemeSettingTile() {
  return ThemeSettingTile(
    setting: EnumSetting<ThemeMode>(
      storage: InMemoryStorage(),
      key: 'test',
      defaultValue: ThemeMode.system,
      values: ThemeMode.values,
    ),
    label: 'Theme',
  );
}
