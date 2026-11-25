import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

/// How much work one assignment does: it encodes and decodes the value once,
/// copies it once and reads the slot once, so that a setting written on
/// every frame (a slider over a map) stays cheap.
void main() {
  test('an assignment encodes, decodes and copies once, and reads the slot once', () {
    final codec = _CountingCodec();
    var snapshots = 0;
    final slot = _CountingSlot(InMemoryStorage());
    final setting = StoredSetting<int, int>(
      slot: slot,
      codec: codec,
      defaultValue: 0,
      snapshot: (value) {
        snapshots++;
        return value;
      },
    );
    expect(setting.value, 0);
    codec
      ..encodes = 0
      ..decodes = 0;
    snapshots = 0;
    slot.reads = 0;

    setting.value = 5;

    expect((codec.encodes, codec.decodes, snapshots, slot.reads), (1, 1, 1, 1));
    expect(setting.value, 5);

    codec
      ..encodes = 0
      ..decodes = 0;
    setting.value = 5;
    expect((codec.encodes, codec.decodes), (0, 0), reason: 'assigning the current value again encodes nothing');
  });

  test('a list of maps read back from the storage equals the same content, so assigning it is a no-op', () {
    final storage = InMemoryStorage();
    final setting = ListSetting<Map<String, Object?>>(
      storage: storage,
      key: 'k',
      defaultValue: const [],
      fromJson: (json) => Map<String, Object?>.from(json! as Map),
      toJson: (element) => element,
    );
    setting.value = [
      {'a': 1},
    ];
    var written = 0;
    storage.addKeyListener('k', () => written++);
    var notified = 0;
    setting.addListener(() => notified++);

    setting.value = [
      {'a': 1},
    ];

    expect(notified, 0);
    expect(written, 0, reason: 'the same content is not written');
  });
}

class _CountingCodec implements SettingCodec<int, int> {
  int encodes = 0;
  int decodes = 0;

  @override
  int encode(int value) {
    encodes++;
    return value;
  }

  @override
  int decode(int raw) {
    decodes++;
    return raw;
  }
}

/// A keyed slot that counts its reads.
final class _CountingSlot implements SettingSlot<int> {
  _CountingSlot(SettingsStorage storage) : _inner = KeyedSettingSlot.ofInt(storage, key: 'k');

  final KeyedSettingSlot<int> _inner;

  int reads = 0;

  @override
  SlotState<int> read() {
    reads++;
    return _inner.read();
  }

  @override
  SettingsObserver get observer => _inner.observer;

  @override
  SlotPlace get place => _inner.place;

  @override
  void write(int raw) => _inner.write(raw);

  @override
  void writeNull() => _inner.writeNull();

  @override
  Future<void> commit(int raw) => _inner.commit(raw);

  @override
  Future<void> commitNull() => _inner.commitNull();

  @override
  void remove() => _inner.remove();

  @override
  void addListener(void Function() listener) => _inner.addListener(listener);

  @override
  void removeListener(void Function() listener) => _inner.removeListener(listener);
}
