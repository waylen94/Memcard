import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:memcard/data/auth_provider.dart';
import 'package:memcard/services/api_service.dart';
import 'package:memcard/ui/auth/login_screen.dart';

void main() {
  testWidgets('empty sign-in fields are rejected before an API request', (
    tester,
  ) async {
    var requestCount = 0;
    final auth = AuthProvider(
      apiService: ApiService(
        client: MockClient((_) async {
          requestCount++;
          return http.Response('', 500);
        }),
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authProvider: auth)));

    final submit = find.byType(FilledButton);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(requestCount, 0);
  });

  testWidgets('failed sign-in displays the API error', (tester) async {
    final auth = AuthProvider(
      apiService: ApiService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/auth/login');
          return http.Response('{"message":"Invalid credentials."}', 401);
        }),
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authProvider: auth)));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'student@example.com');
    await tester.enterText(fields.at(1), 'wrong-password');
    final submit = find.byType(FilledButton);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials.'), findsOneWidget);
    expect(auth.isAuthenticated, isFalse);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });
}
