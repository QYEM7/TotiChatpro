import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('future-backed screens must not return a Future from setState', () {
    final forbidden = RegExp(
      r'setState\s*\(\s*\(\s*\)\s*=>\s*'
      r'_(?:future|state|results|profile|catalog|report|role|'
      r'found|rooms|banners|supportRights|evidence)\s*=',
    );
    final offenders = <String>[];
    final files = Directory('lib/features').listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      if (forbidden.hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
      reason: 'Flutter rejects Future-returning callbacks in setState. '
        'Assign to a Future field inside a void block instead.');
  });
}
