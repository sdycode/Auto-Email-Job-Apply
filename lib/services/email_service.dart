import 'dart:async';
import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/mailer.dart' as mailer show send, checkCredentials;
import 'package:mailer/smtp_server.dart';

import '../models.dart';
import 'app_store.dart';

final _emailRegex = RegExp(r'[\w.+\-]+@[\w\-]+(\.[\w\-]+)+');

/// Pulls every email address out of pasted text (e.g. a whole LinkedIn post).
List<String> extractEmails(String text) => _emailRegex
    .allMatches(text)
    .map((m) => m.group(0)!.toLowerCase())
    .toSet()
    .toList();

const _smtpTimeout = Duration(seconds: 30);

enum SendMode {
  /// Sent in the background via Gmail SMTP, no other app opened.
  direct,

  /// Gmail isn't configured, so the mail app was opened.
  mailApp,

  /// Direct sending failed, so the mail app was opened as a backup.
  mailAppFallback,
}

class SendResult {
  final SendMode mode;

  /// Why direct sending failed (only for [SendMode.mailAppFallback]).
  final String? error;

  const SendResult(this.mode, [this.error]);
}

class EmailService {
  /// Sends the application. With Gmail configured it is sent directly in the
  /// background. If that isn't configured or fails for any reason, the phone's
  /// mail app is opened with everything pre-filled as a safe backup.
  static Future<SendResult> send({
    required AppStore store,
    required List<String> recipients,
    required EmailTemplate template,
    Resume? resume,
  }) async {
    final attachment =
        resume != null && File(resume.path).existsSync() ? resume : null;

    if (store.smtpConfigured) {
      try {
        await sendViaSmtp(
          server: gmail(store.senderEmail, store.appPassword),
          fromEmail: store.senderEmail,
          fromName: store.senderName,
          recipients: recipients,
          subject: template.subject,
          body: template.body,
          resume: attachment,
        );
        return const SendResult(SendMode.direct);
      } catch (e) {
        await _openMailApp(recipients, template, attachment);
        return SendResult(SendMode.mailAppFallback, describeError(e));
      }
    }

    await _openMailApp(recipients, template, attachment);
    return const SendResult(SendMode.mailApp);
  }

  static Future<void> sendViaSmtp({
    required SmtpServer server,
    required String fromEmail,
    required String fromName,
    required List<String> recipients,
    required String subject,
    required String body,
    Resume? resume,
  }) async {
    final message = Message()
      ..from = Address(fromEmail, fromName.isEmpty ? null : fromName)
      ..recipients.addAll(recipients)
      ..subject = subject
      ..text = body;
    if (resume != null) {
      message.attachments
          .add(FileAttachment(File(resume.path))..fileName = resume.name);
    }
    await mailer.send(message, server, timeout: _smtpTimeout);
  }

  /// Logs in to Gmail without sending anything. Throws on failure.
  static Future<void> verifyGmail(String email, String appPassword) =>
      mailer.checkCredentials(gmail(email, appPassword), timeout: _smtpTimeout);

  static Future<void> _openMailApp(
      List<String> recipients, EmailTemplate template, Resume? resume) {
    return FlutterEmailSender.send(Email(
      recipients: recipients,
      subject: template.subject,
      body: template.body,
      attachmentPaths: resume != null ? [resume.path] : [],
    ));
  }

  /// Turns SMTP/network exceptions into something a user can act on, based on
  /// Gmail's actual reply (e.g. 534 5.7.9 vs 535 5.7.8).
  static String describeError(Object e) {
    final raw = e.toString();
    if (e is SmtpClientAuthenticationException) {
      if (raw.contains('5.7.9') || raw.contains('Application-specific password')) {
        return 'Gmail needs an App Password here, not your normal Gmail password. '
            'Create one at myaccount.google.com/apppasswords.';
      }
      if (raw.contains('5.7.8') || raw.contains('BadCredentials')) {
        return 'Gmail rejected the email/App Password. Make sure you pasted the '
            '16-letter App Password (not your normal password) for this same Gmail account.';
      }
      if (raw.contains('5.7.0') || raw.contains('WebLoginRequired')) {
        return 'Google blocked this sign-in. Open Gmail in a browser, confirm it was you, then try again.';
      }
      return 'Gmail rejected the login.';
    }
    if (e is SocketException || e is TimeoutException || e is HandshakeException) {
      return 'Could not reach Gmail — check the internet connection.';
    }
    if (e is SmtpMessageValidationException) {
      return 'Invalid email address.';
    }
    return raw;
  }
}
