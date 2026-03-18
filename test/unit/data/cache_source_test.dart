import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rbac_ui_engine/src/data/models/policy_model.dart';
import 'package:rbac_ui_engine/src/data/models/permission_model.dart';
import 'package:rbac_ui_engine/src/data/sources/local/policy_cache_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPrefsPolicyCacheSource cacheSource;

  final sampleModel = PolicyModel(
    id: 'pol-cache-01',
    version: '2.0.0',
    rolePermissions: {
      'admin': [
        const PermissionModel(action: 'read', resource: 'dashboard'),
      ],
    },
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cacheSource = SharedPrefsPolicyCacheSource(preferences: prefs);
  });

  group('SharedPrefsPolicyCacheSource', () {
    group('cachePolicy', () {
      test('stores policy and returns Right(unit)', () async {
        final result = await cacheSource.cachePolicy('key1', sampleModel);
        expect(result.isRight(), isTrue);
      });
    });

    group('getCachedPolicy', () {
      test('returns null when no policy cached for key', () async {
        final result = await cacheSource.getCachedPolicy('nonexistent');
        expect(result.isRight(), isTrue);
        result.fold((_) => fail('Expected Right'), (model) {
          expect(model, isNull);
        });
      });

      test('returns cached policy after storing it', () async {
        await cacheSource.cachePolicy('mykey', sampleModel);
        final result = await cacheSource.getCachedPolicy('mykey');

        expect(result.isRight(), isTrue);
        result.fold((_) => fail('Expected Right'), (model) {
          expect(model, isNotNull);
          expect(model!.id, equals('pol-cache-01'));
          expect(model.version, equals('2.0.0'));
        });
      });

      test('different keys return different values', () async {
        final modelA = PolicyModel(
          id: 'A', version: '1.0', rolePermissions: const {},
        );
        final modelB = PolicyModel(
          id: 'B', version: '1.0', rolePermissions: const {},
        );

        await cacheSource.cachePolicy('keyA', modelA);
        await cacheSource.cachePolicy('keyB', modelB);

        final a = await cacheSource.getCachedPolicy('keyA');
        final b = await cacheSource.getCachedPolicy('keyB');

        a.fold((_) {}, (m) => expect(m!.id, equals('A')));
        b.fold((_) {}, (m) => expect(m!.id, equals('B')));
      });
    });

    group('clearCache', () {
      test('removes a specific key', () async {
        await cacheSource.cachePolicy('toDelete', sampleModel);
        await cacheSource.clearCache('toDelete');

        final result = await cacheSource.getCachedPolicy('toDelete');
        result.fold((_) {}, (m) => expect(m, isNull));
      });
    });

    group('clearAll', () {
      test('removes all cached policies', () async {
        await cacheSource.cachePolicy('k1', sampleModel);
        await cacheSource.cachePolicy('k2', sampleModel);
        await cacheSource.clearAll();

        final r1 = await cacheSource.getCachedPolicy('k1');
        final r2 = await cacheSource.getCachedPolicy('k2');

        r1.fold((_) {}, (m) => expect(m, isNull));
        r2.fold((_) {}, (m) => expect(m, isNull));
      });
    });
  });
}
