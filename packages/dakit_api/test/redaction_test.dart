import 'package:dakit_api/dakit_api.dart';
import 'package:test/test.dart';

void main() {
  const redactor = Redactor();

  test('redacts sensitive fields case-insensitively', () {
    final result = redactor.fields(<String, Object?>{
      'Authorization': 'Bearer secret',
      'refresh_token': 'secret',
      'status': 200,
    });

    expect(result['Authorization'], '<redacted>');
    expect(result['refresh_token'], '<redacted>');
    expect(result['status'], 200);
  });

  test('redacts authorization callback query values', () {
    final result = redactor.uri(
      Uri.parse('dakit://oauth/callback?code=secret&state=public-state'),
    );

    expect(result.queryParameters['code'], '<redacted>');
    expect(result.queryParameters['state'], 'public-state');
  });
}
