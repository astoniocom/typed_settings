import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/typed_settings_flutter_extend.dart';

void main() {
  testWidgets('pickDateTime keeps the opened time when the time picker is cancelled', (tester) async {
    final result = await _open(tester, (context) {
      return pickDateTime(
        context,
        current: DateTime(2020, 1, 2, 3, 4, 5),
        pickDate: _date(DateTime(2021, 8, 9)),
        pickTimeOfDay: _time(null),
      );
    });

    expect(result?.value, DateTime(2021, 8, 9, 3, 4, 5));
  });

  testWidgets('pickDateTime stores the confirmed hour and minute', (tester) async {
    final result = await _open(tester, (context) {
      return pickDateTime(
        context,
        current: DateTime(2020, 1, 2, 3, 4, 5),
        pickDate: _date(DateTime(2021, 8, 9)),
        pickTimeOfDay: _time(const TimeOfDay(hour: 8, minute: 15)),
      );
    });

    expect(result?.value, DateTime(2021, 8, 9, 8, 15));
  });

  testWidgets('pickDateTime reports a clear from either picker', (tester) async {
    final fromDate = await _open(tester, (context) {
      return pickDateTime(
        context,
        current: DateTime(2020, 1, 2),
        allowClear: true,
        pickDate: (context, {required firstDate, required initialDate, required lastDate, onClear}) async {
          onClear?.call();
          return null;
        },
      );
    });
    expect(fromDate, const DialogResult<DateTime?>(null));

    final fromTime = await _open(tester, (context) {
      return pickDateTime(
        context,
        current: DateTime(2020, 1, 2, 3, 4),
        allowClear: true,
        pickDate: _date(DateTime(2021, 8, 9)),
        pickTimeOfDay: (context, {required initialTime, onClear}) async {
          onClear?.call();
          return null;
        },
      );
    });
    expect(fromTime, const DialogResult<DateTime?>(null));
  });

  testWidgets('pickTimeOfDay reports a clear apart from a dismissal', (tester) async {
    final cleared = await _open(tester, (context) {
      return pickTimeOfDay(
        context,
        current: const TimeOfDay(hour: 7, minute: 0),
        allowClear: true,
        pick: (context, {required initialTime, onClear}) async {
          onClear?.call();
          return null;
        },
      );
    });
    expect(cleared, const DialogResult<TimeOfDay?>(null));

    final dismissed = await _open(tester, (context) {
      return pickTimeOfDay(
        context,
        current: const TimeOfDay(hour: 7, minute: 0),
        pick: (context, {required initialTime, onClear}) async => null,
      );
    });
    expect(dismissed, isNull);
  });
}

PickDate _date(DateTime date) =>
    (context, {required firstDate, required initialDate, required lastDate, onClear}) async => date;

PickTime _time(TimeOfDay? time) =>
    (context, {required initialTime, onClear}) async => time;

Future<T> _open<T>(WidgetTester tester, Future<T> Function(BuildContext context) pick) async {
  await tester.pumpWidget(const MaterialApp(home: Text('open')));
  return pick(tester.element(find.text('open')));
}
