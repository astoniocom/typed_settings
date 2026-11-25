import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';

void main() {
  test('a raw state compares by raw value and by where it was read from', () {
    expect(const RawSlotState(1), const RawSlotState(1));
    expect(const RawSlotState(1).hashCode, const RawSlotState(1).hashCode);
    expect(const RawSlotState(1), isNot(const RawSlotState(2)));
    expect(const RawSlotState(1), isNot(const RawSlotState(1, fromLegacyKey: true)));
  });

  test('a null state compares by where it was read from', () {
    expect(const NullSlotState<int>(), const NullSlotState<int>());
    expect(const NullSlotState<int>(), isNot(const NullSlotState<int>(fromLegacyKey: true)));
  });

  test('the three states differ from each other', () {
    expect(const AbsentSlotState<int>(), isNot(const NullSlotState<int>()));
    expect(const NullSlotState<int?>(), isNot(const RawSlotState<int?>(null)));
    expect(const AbsentSlotState<int>(), isNot(const RawSlotState(0)));
  });

  test('an absent state is never read from a legacy key', () {
    expect(const AbsentSlotState<int>().fromLegacyKey, isFalse);
  });
}
