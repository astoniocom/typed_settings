import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:typed_settings/src/settings/setting.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';

/// How a setting reads its place: its value type, its raw type and the
/// class of its codec.
typedef _Shape = ({Type value, Type raw, Type codec});

/// The settings in use over one storage, and the guard against two
/// settings reading the same stored data differently.
///
/// Every `StoredSetting` registers at the place its slot names
/// ([SettingSlot.place]) when it is created and leaves when it is
/// disposed. Several settings may share a place, as instances of one
/// setting do, as long as they agree on how it is stored: the same value
/// type, raw type and codec class, and the same legacy keys in the same
/// order, since one that falls back to a legacy key reads a value the
/// other does not. Creating a setting that disagrees with
/// a live one over its place throws a [StateError] before the setting
/// touches the slot: an `IntSetting` and a `StringSetting` over one key
/// would each read the other's data as garbage, or overwrite it. Settings
/// over different keys must not touch a common key at all, legacy keys
/// ([KeyedSlotPlace.legacyKeys]) included, since a write of one moves its
/// value off its legacy keys and would remove the other's. Two settings
/// over one slot with no key have to agree in the same way.
///
/// Codecs are compared by type, not by configuration. Two codecs of one
/// type configured differently (an `EnumNameCodec` over other values, a
/// `JsonListCodec` with other element conversions, which are functions
/// and cannot be compared) pass the guard, and so do different
/// validators, though one may reject what the other accepts. Give every
/// setting over one key the same configuration: create it in one place
/// and share it, or create its instances from one function.
///
/// [settings] enumerates the live keyed settings of one storage, for what
/// spans an application (a debug menu, resetting everything, exporting a
/// profile), and [operator []] finds one by key. A setting is listed by
/// the storage it was created over. A setting over a slot with no key
/// shares nothing and is listed nowhere.
///
/// They are listed as `Setting<Object?>`. Dart's generics are covariant,
/// so every setting is one, and what does not take a value works on it as
/// it is: [Setting.reset], reading [Setting.value] and
/// [ReadOnlySetting.diagnosticKey]. Assigning a value checks its type when
/// the program runs, and throws a `TypeError` for a value of another type
/// than the setting's.
@immutable
final class SettingsRegistry {
  /// The registry of [storage]: a view of the settings live over it, which
  /// follows them as they are created and disposed. Registries of one
  /// storage are equal.
  const SettingsRegistry.of(SettingsStorage storage) : _storage = storage;

  final SettingsStorage _storage;

  /// The places claimed by live settings or reserved, by what holds them:
  /// the storage of a key, or a slot with no key. Each map is in the order
  /// its places were claimed.
  static final Expando<Map<String?, _Claim>> _claims = Expando('typed_settings claimed places');

  /// The live settings over this storage, one per key (the first created
  /// of those sharing it), in the order their keys came into use.
  Iterable<Setting<Object?>> get settings => [
    for (final claim in _claims[_storage]?.values ?? const <_Claim>[]) ?claim.members.firstOrNull,
  ];

  /// The live setting under [key] (the first created of those sharing
  /// it), or `null` when there is none.
  Setting<Object?>? operator [](String key) => _claims[_storage]?[key]?.members.firstOrNull;

  @override
  bool operator ==(Object other) => other is SettingsRegistry && identical(other._storage, _storage);

  @override
  int get hashCode => identityHashCode(_storage);

  /// Adds [setting], which reads [place] as [shape]. Throws a
  /// [StateError] for a conflict with a live setting (see the class
  /// documentation). Called by `StoredSetting`.
  @internal
  static void register(
    Setting<Object?> setting,
    SlotPlace place, {
    required ({Type value, Type raw, Type codec}) shape,
  }) {
    final held = _heldAt(place);
    final claims = _claims[held.holder] ??= {};
    final touched = {held.key, ...held.legacyKeys};
    for (final MapEntry(key: otherKey, value: other) in claims.entries) {
      if (other.reservedFor case final purpose? when touched.contains(otherKey)) {
        throw StateError('`$otherKey`, which `${held.key}` uses, is reserved for $purpose');
      }
    }
    final own = claims[held.key];
    if (own != null) {
      if (own.shape != shape) {
        if (held.key == null) {
          throw StateError('This slot holds a live setting of ${_describe(own.shape!)}, not ${_describe(shape)}');
        }
        throw StateError(
          '`${held.key}` is the key of a live setting of ${_describe(own.shape!)}, not ${_describe(shape)}',
        );
      }
      if (!const ListEquality<String>().equals(own.legacyKeys, held.legacyKeys)) {
        throw StateError(
          '`${held.key}` is the key of a live setting with the legacy keys ${own.legacyKeys}, '
          'not ${held.legacyKeys}: while the value is under one of them, the two would read different values',
        );
      }
    }
    for (final MapEntry(key: otherKey, value: other) in claims.entries) {
      if (otherKey == held.key) continue;
      final shared = touched.intersection({otherKey, ...other.legacyKeys});
      if (shared.isNotEmpty) {
        throw StateError(
          '`${held.key}` and the live setting `$otherKey` both use `${shared.first}`, '
          'so that a write of one would remove the value of the other',
        );
      }
    }
    (own ?? (claims[held.key] = _Claim(shape, held.legacyKeys))).members.add(setting);
  }

  /// Removes [setting], registered at [place]; called by
  /// `StoredSetting.dispose`.
  @internal
  static void unregister(Setting<Object?> setting, SlotPlace place) {
    final held = _heldAt(place);
    final claims = _claims[held.holder];
    final claim = claims?[held.key];
    if (claims == null || claim == null) return;
    claim.members.removeWhere((member) => identical(member, setting));
    if (claim.members.isEmpty) claims.remove(held.key);
  }

  /// Keeps settings off [key] of [storage], which holds [purpose] (the
  /// layout version of `SettingsMigrator`): a setting over it, or one that
  /// lists it as a legacy key, is rejected with a [StateError] from now
  /// on, for as long as [storage] lives. Throws a [StateError] when a live
  /// setting already uses [key] or it is reserved for something else;
  /// reserving it again for [purpose] is a no-op.
  @internal
  static void reserve(SettingsStorage storage, String key, {required String purpose}) {
    final claims = _claims[storage] ??= {};
    final own = claims[key];
    if (own != null) {
      if (own.reservedFor == purpose) return;
      throw StateError(
        '`$key` cannot hold $purpose: it is '
        '${own.reservedFor == null ? 'the key of a live setting' : 'reserved for ${own.reservedFor}'}',
      );
    }
    for (final MapEntry(key: otherKey, value: other) in claims.entries) {
      if (other.legacyKeys.contains(key)) {
        throw StateError('`$key` cannot hold $purpose: it is a legacy key of the live setting `$otherKey`');
      }
    }
    claims[key] = _Claim.reserved(purpose);
  }

  static String _describe(_Shape shape) => '${shape.value} stored as ${shape.raw} by ${shape.codec}';
}

/// What holds the data of a place, and the keys there: the storage of a
/// key, or the slot itself for a slot with no key.
typedef _HeldAt = ({Object holder, String? key, List<String> legacyKeys});

_HeldAt _heldAt(SlotPlace place) => switch (place) {
  KeylessSlotPlace(:final slot) => (holder: slot, key: null, legacyKeys: const []),
  KeyedSlotPlace(:final storage, :final key, :final legacyKeys) => (holder: storage, key: key, legacyKeys: legacyKeys),
};

/// The live settings over one place and how they read it, or a place kept
/// off settings for something else ([reservedFor]).
class _Claim {
  _Claim(_Shape this.shape, this.legacyKeys) : reservedFor = null;

  _Claim.reserved(String this.reservedFor) : shape = null, legacyKeys = const [];

  /// How the settings read the place; `null` for a reserved one.
  final _Shape? shape;

  /// The legacy keys every setting over the place falls back to, which
  /// they agree on; empty for a reserved place.
  final List<String> legacyKeys;

  /// What the place holds instead of a setting; `null` for one that
  /// settings use.
  final String? reservedFor;

  /// The live settings over the place, in the order they were created;
  /// empty for a reserved place, and never otherwise.
  final List<Setting<Object?>> members = [];
}
