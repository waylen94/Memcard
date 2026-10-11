import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:memcard/data/auth_provider.dart';
import 'package:memcard/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Use the plugin's platform interface to simulate device storage failures.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('queued deletion preserves the session and local data', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    var cleared = false;
    final auth = AuthProvider(
      apiService: ApiService(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '{"user":{"id":1,"name":"Test","email":"test@example.com"}}',
              200,
            );
          }
          return http.Response('', 202);
        }),
      ),
      clearAccountData: () async {
        cleared = true;
      },
    );
    await auth.tryRestoreSession();
    expect(await auth.deleteAccount(), isFalse);
    expect(auth.token, 'test-token');
    expect(auth.isAuthenticated, isTrue);
    expect(cleared, isFalse);
    expect(auth.isDeletingAccount, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getString('auth_token'),
      'test-token',
    );
  });

  for (final throws in [false, true]) {
    test(
      'local data cleanup runs when token removal ${throws ? "throws" : "fails"}',
      () async {
        SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
        final originalStore = SharedPreferencesStorePlatform.instance;
        var cleared = false;
        final auth = AuthProvider(
          apiService: ApiService(
            client: MockClient((request) async {
              if (request.method == 'GET') {
                return http.Response(
                  '{"user":{"id":1,"name":"Test","email":"test@example.com"}}',
                  200,
                );
              }
              return http.Response('', 204);
            }),
          ),
          clearAccountData: () async {
            cleared = true;
          },
        );
        await auth.tryRestoreSession();
        SharedPreferencesStorePlatform.instance = _FailingRemovalStore(throws);
        try {
          expect(await auth.deleteAccount(), isTrue);
          expect(cleared, isTrue);
          expect(auth.token, isNull);
          expect(auth.isAuthenticated, isFalse);
          expect(auth.isDeletingAccount, isFalse);
          expect(auth.errorMessage, contains('could not be removed'));
        } finally {
          SharedPreferencesStorePlatform.instance = originalStore;
        }
      },
    );
  }

  test(
    'deletion authenticates, clears data, and removes the saved session',
    () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
      var cleared = false;
      final auth = AuthProvider(
        apiService: ApiService(
          client: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                '{"user":{"id":1,"name":"Test","email":"test@example.com"}}',
                200,
              );
            }
            expect(request.method, 'DELETE');
            expect(request.url.path, '/api/auth/account');
            expect(request.headers['Authorization'], 'Bearer test-token');
            return http.Response('', 204);
          }),
        ),
        clearAccountData: () async {
          cleared = true;
        },
      );
      await auth.tryRestoreSession();
      expect(await auth.deleteAccount(), isTrue);
      expect(cleared, isTrue);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.token, isNull);
      expect(auth.user, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('auth_token'),
        isNull,
      );
    },
  );

  test('server failure preserves account and local data for retry', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    var cleared = false;
    final auth = AuthProvider(
      apiService: ApiService(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '{"user":{"id":1,"name":"Test","email":"test@example.com"}}',
              200,
            );
          }
          return http.Response('{"message":"Please try again."}', 500);
        }),
      ),
      clearAccountData: () async {
        cleared = true;
      },
    );
    await auth.tryRestoreSession();
    expect(await auth.deleteAccount(), isFalse);
    expect(cleared, isFalse);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.token, 'test-token');
    expect(auth.errorMessage, 'Please try again.');
    expect(auth.isDeletingAccount, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getString('auth_token'),
      'test-token',
    );
  });
}

class _FailingRemovalStore extends SharedPreferencesStorePlatform {
  _FailingRemovalStore(this.throws);
  final bool throws;

  @override
  Future<bool> clear() async => throw UnimplementedError();

  @override
  Future<Map<String, Object>> getAll() async => throw UnimplementedError();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw UnimplementedError();

  @override
  Future<bool> remove(String key) async {
    if (throws) throw StateError('Device storage unavailable');
    return false;
  }
}
