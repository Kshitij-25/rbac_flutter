import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_ui_engine/src/domain/entities/resource.dart';

void main() {
  group('Resource', () {
    const dashboard = Resource(id: 'dashboard');
    const nested = Resource(id: 'dashboard.analytics.chart');

    test('segments splits on dots', () {
      expect(nested.segments, equals(['dashboard', 'analytics', 'chart']));
    });

    test('namespace returns first segment', () {
      expect(nested.namespace, equals('dashboard'));
    });

    test('single segment has length 1 segments', () {
      expect(dashboard.segments, hasLength(1));
    });

    test('default type is widget', () {
      expect(dashboard.type, equals(ResourceType.widget));
    });

    test('equality based on id only', () {
      const r1 = Resource(id: 'dashboard');
      const r2 = Resource(id: 'dashboard', type: ResourceType.route);
      expect(r1, equals(r2));
    });
  });
}
