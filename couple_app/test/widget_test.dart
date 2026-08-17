import 'package:flutter_test/flutter_test.dart';

import 'package:couple_app/core/services/location_service.dart';

void main() {
  group('LocationService.formatDistance', () {
    test('metr ilə göstərir (< 1 km)', () {
      expect(LocationService.formatDistance(0.25), '250 m');
    });

    test('bir onluq dəqiqliklə km göstərir (< 10 km)', () {
      expect(LocationService.formatDistance(3.45), '3.5 km');
    });

    test('yuvarlaqlaşdırılmış km göstərir (>= 10 km)', () {
      expect(LocationService.formatDistance(42.7), '43 km');
    });
  });
}
