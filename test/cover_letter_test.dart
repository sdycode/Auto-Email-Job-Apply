import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_apply/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_apply/services/app_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoverLetter Model', () {
    test('toJson and fromJson work correctly', () {
      final now = DateTime.now();
      final letter = CoverLetter(
        id: '123',
        title: 'Senior Flutter Dev',
        content: 'Dear Hiring Manager...',
        updatedAt: now,
      );

      final json = letter.toJson();
      final recovered = CoverLetter.fromJson(json);

      expect(recovered.id, '123');
      expect(recovered.title, 'Senior Flutter Dev');
      expect(recovered.content, 'Dear Hiring Manager...');
      expect(recovered.updatedAt.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
    });
  });

  group('AppStore Cover Letters persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test(
        'Blocks saving when email unverified, and allows saving when verified',
        () async {
      final store = AppStore();
      await store.load();

      // On first launch, starter cover letter is seeded
      expect(store.coverLetters.isNotEmpty, isTrue);
      expect(store.coverLetters.first.title, defaultCoverLetterTitle);
      expect(store.isEmailVerified, isFalse);

      final newLetter = CoverLetter(
        id: 'custom_1',
        title: 'Backend Engineer',
        content: 'Hello, I am a backend developer...',
        updatedAt: DateTime.now(),
      );

      // Attempting to save without verified email is blocked
      final saveBlocked = await store.saveCoverLetter(newLetter);
      expect(saveBlocked, isFalse);
      expect(store.coverLetters.length, 1);

      // Verify email via SMTP credentials
      store.senderEmail = 'shubham@gmail.com';
      store.appPassword = 'testpassword123';
      expect(store.isEmailVerified, isTrue);

      // Now saving succeeds
      final saveSuccess = await store.saveCoverLetter(newLetter);
      expect(saveSuccess, isTrue);
      expect(store.coverLetters.length, 2);
      expect(store.coverLetters.first.title, 'Backend Engineer');

      // Update existing cover letter
      final updated = CoverLetter(
        id: 'custom_1',
        title: 'Senior Backend Engineer',
        content: 'Updated content',
        updatedAt: DateTime.now(),
      );
      await store.saveCoverLetter(updated);
      expect(store.coverLetters.first.title, 'Senior Backend Engineer');
      expect(store.coverLetters.first.content, 'Updated content');

      // Delete cover letter
      await store.deleteCoverLetter('custom_1');
      expect(store.coverLetters.any((l) => l.id == 'custom_1'), isFalse);
    });
  });
}
