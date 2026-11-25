import 'package:typed_settings/src/validation/validation_errors.dart';

/// [error] as text for a diagnostic, with the stored data it may carry
/// only when [includeData] is set: the `source` of a [FormatException],
/// where codecs and storages put the data they could not use, and the
/// props of a [ValidationError], which may hold the rejected value.
String describeError(Object error, {required bool includeData}) => switch (error) {
  ValidationError() => error.describe(includeData: includeData),
  FormatException() => '${includeData ? error : withoutStoredData(error)}',
  _ => '$error',
};

/// [error] without the stored data it may carry: a [FormatException]
/// loses its `source`. Anything else is returned as it is; a
/// [ValidationError] leaves its props out of `toString` outside debug
/// builds by itself.
Object withoutStoredData(Object error) =>
    error is FormatException ? FormatException(error.message, null, error.offset) : error;

/// [error], thrown while stored data was turned into a value, as text for
/// a diagnostic: as [describeError] puts it, except that without
/// [includeData] it is described as [decodeErrorWithoutStoredData] leaves
/// it.
String describeDecodeError(Object error, {required bool includeData}) =>
    describeError(includeData ? error : decodeErrorWithoutStoredData(error), includeData: includeData);

/// [error], thrown while stored data was turned into a value, without the
/// stored data it may carry. Unlike the exceptions that codecs throw on
/// purpose, an [Error] may quote that data anywhere in its message (the
/// receiver of a [NoSuchMethodError], the value of an [ArgumentError]), so
/// it is replaced by one that keeps its type alone; a [TypeError], whose
/// message names types only, is kept. An [Exception] loses what
/// [withoutStoredData] removes.
Object decodeErrorWithoutStoredData(Object error) => switch (error) {
  TypeError() => error,
  Error() => _ErrorWithoutStoredData('${error.runtimeType}'),
  _ => withoutStoredData(error),
};

/// Stands in for an [Error] whose message was left out.
final class _ErrorWithoutStoredData extends Error {
  _ErrorWithoutStoredData(this._type);

  final String _type;

  @override
  String toString() => '$_type (message left out, it may quote stored data)';
}
