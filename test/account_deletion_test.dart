import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:memcard/data/auth_provider.dart';
import 'package:memcard/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Use the plugin's platform interface to simulate device storage failures.
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tokenStorage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('queued deletion preserves the session and local data', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
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
    expect(await tokenStorage.read(key: 'auth_token'), 'test-token');
  });

  test('local data cleanup runs when secure token removal fails', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
    final originalStore = FlutterSecureStoragePlatform.instance;
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
    FlutterSecureStoragePlatform.instance = _FailingRemovalStore();
    try {
      expect(await auth.deleteAccount(), isTrue);
      expect(cleared, isTrue);
      expect(auth.token, isNull);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isDeletingAccount, isFalse);
      expect(auth.errorMessage, contains('could not be removed'));
    } finally {
      FlutterSecureStoragePlatform.instance = originalStore;
    }
  });

  test(
    'deletion authenticates, clears data, and removes the saved session',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
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
      expect(await tokenStorage.read(key: 'auth_token'), 'test-token');
      expect(await auth.deleteAccount(), isTrue);
      expect(await tokenStorage.read(key: 'auth_token'), isNull);
      expect(cleared, isTrue);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.token, isNull);
      expect(auth.user, isNull);
    },
  );

  test('login saves the token securely and logout removes it', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(
      apiService: ApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/logout')) {
            expect(request.headers['Authorization'], 'Bearer test-token');
            return http.Response('', 204);
          }
          return http.Response(
            '{"token":"test-token","user":{"id":1,"name":"Test","email":"test@example.com"}}',
            200,
          );
        }),
      ),
    );

    expect(
      await auth.login(email: 'test@example.com', password: 'test'),
      isTrue,
    );
    expect(await tokenStorage.read(key: 'auth_token'), 'test-token');
    expect(
      (await SharedPreferences.getInstance()).getString('auth_token'),
      isNull,
    );
    await auth.logout();
    expect(await tokenStorage.read(key: 'auth_token'), isNull);
    expect(auth.status, AuthStatus.unauthenticated);
  });

  test('server failure preserves account and local data for retry', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
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
    expect(await tokenStorage.read(key: 'auth_token'), 'test-token');
  });
}

class _FailingRemovalStore extends TestFlutterSecureStoragePlatform {
  _FailingRemovalStore() : super({'auth_token': 'test-token'});

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    throw StateError('Secure storage unavailable');
  }
}
