import 'package:typed_settings/src/codec/setting_codec.dart';

/// Two codecs one after the other: [first] converts between the value type
/// [T] and an intermediate type [M], [second] between [M] and the raw type
/// [R]. Built with [SettingCodecChaining.then].
///
/// [encode] runs [first], then [second]; [decode] runs them in reverse.
/// What either throws propagates, so each keeps its own contract.
///
/// The registry compares codecs by type (see `SettingsRegistry`), and the
/// type of a chain names [T], [M] and [R] only: two chains over the same
/// types with other codecs pass its check, so give every setting over one
/// key the same chain.
final class ChainedCodec<T, M, R> implements SettingCodec<T, R> {
  /// Chains [first] and [second].
  const ChainedCodec(this.first, this.second);

  /// Converts between [T] and [M].
  final SettingCodec<T, M> first;

  /// Converts between [M] and [R].
  final SettingCodec<M, R> second;

  @override
  T decode(R raw) => first.decode(second.decode(raw));

  @override
  R encode(T value) => second.encode(first.encode(value));
}

/// Builds a [ChainedCodec]: a codec for a type that maps onto one an
/// existing codec stores.
///
/// ```dart
/// // `LevelCodec` converts between a `Level` and the `Tier` constant it
/// // wraps; the chain stores a `Level` as the name of its `Tier`.
/// final codec = const LevelCodec().then(EnumNameCodec(Tier.values));
/// ```
extension SettingCodecChaining<T, M> on SettingCodec<T, M> {
  /// This codec, then [next]: values go through this codec to [M] and on
  /// through [next] to [R].
  SettingCodec<T, R> then<R>(SettingCodec<M, R> next) => ChainedCodec(this, next);
}
