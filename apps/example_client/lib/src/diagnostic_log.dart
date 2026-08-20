import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:flutter/foundation.dart';

final class DiagnosticLog extends ChangeNotifier implements DiagnosticSink {
  static const int maximumEvents = 100;

  final List<DiagnosticEvent> _events = <DiagnosticEvent>[];

  List<DiagnosticEvent> get events =>
      List<DiagnosticEvent>.unmodifiable(_events.reversed);

  @override
  void add(DiagnosticEvent event) {
    _events.add(event);
    if (_events.length > maximumEvents) _events.removeAt(0);
    notifyListeners();
  }

  void clear() {
    _events.clear();
    notifyListeners();
  }
}
