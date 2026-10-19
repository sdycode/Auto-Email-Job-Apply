import 'package:flutter_test/flutter_test.dart';
import 'package:quick_apply/models.dart';
import 'package:quick_apply/services/firebase_service.dart';

void main() {
  group('FirebaseService key encoding', () {
    test('emailToKey converts dots and preserves lowercase alphanumeric characters', () {
      expect(
        FirebaseService.emailToKey('Shubham.Yeole@Gmail.com'),
        'shubham_yeole@gmail_com',
      );
      expect(
        FirebaseService.emailToKey('test.user+job.apply@acme.co.in'),
        'test_user+job_apply@acme_co_in',
      );
    });
  });

  group('SentRecord status and serialization', () {
    test('SentRecord populates status and unique id', () {
      final now = DateTime.now();
      final record = SentRecord(
        to: 'hr@company.com',
        subject: 'Senior Flutter Developer',
        sentAt: now,
        direct: true,
        status: 'Sent directly via Gmail',
      );

      final json = record.toJson();
      expect(json['status'], 'Sent directly via Gmail');
      expect(json['direct'], true);
      expect(json['to'], 'hr@company.com');
      expect(json['id'], isNotEmpty);

      final fromJson = SentRecord.fromJson(json);
      expect(fromJson.status, 'Sent directly via Gmail');
      expect(fromJson.direct, true);
      expect(fromJson.to, 'hr@company.com');
    });

    test('SentRecord backwards compatibility with missing status/id', () {
      final json = {
        'to': 'jobs@startup.io',
        'subject': 'Application',
        'sentAt': DateTime.now().toIso8601String(),
        'direct': false,
      };

      final record = SentRecord.fromJson(json);
      expect(record.status, 'Opened in mail app');
      expect(record.direct, false);
      expect(record.id, isNotEmpty);
    });
  });
}
