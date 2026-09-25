import 'package:flutter_test/flutter_test.dart';
import 'package:quick_apply/services/email_service.dart';

void main() {
  test('extractEmails pulls unique addresses out of a job post', () {
    const post = 'We are hiring! Send CV to HR@Acme.com or jobs.team+flutter@acme.co.in. '
        'Questions: hr@acme.com';
    expect(extractEmails(post), ['hr@acme.com', 'jobs.team+flutter@acme.co.in']);
  });

  test('extractEmails returns empty for text without emails', () {
    expect(extractEmails('no contact here'), isEmpty);
  });
}
