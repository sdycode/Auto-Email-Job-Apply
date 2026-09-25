import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/mailer.dart' as mailer show send;
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

enum SendMode { direct, mailApp }

class EmailService {
  /// Sends the application. With Gmail SMTP configured, this is truly one tap
  /// (sent in the background). Otherwise it opens the phone's mail app with
  /// everything pre-filled and the resume attached.
  static Future<SendMode> send({
    required AppStore store,
    required List<String> recipients,
    required EmailTemplate template,
    Resume? resume,
  }) async {
    final attachment =
        resume != null && File(resume.path).existsSync() ? resume.path : null;

    if (store.smtpConfigured) {
      final message = Message()
        ..from = Address(store.senderEmail,
            store.senderName.isEmpty ? null : store.senderName)
        ..recipients.addAll(recipients)
        ..subject = template.subject
        ..text = template.body;
      if (attachment != null) {
        message.attachments.add(
            FileAttachment(File(attachment))..fileName = resume!.name);
      }
      await mailer.send(message, gmail(store.senderEmail, store.appPassword));
      return SendMode.direct;
    }

    await FlutterEmailSender.send(Email(
      recipients: recipients,
      subject: template.subject,
      body: template.body,
      attachmentPaths: attachment != null ? [attachment] : [],
    ));
    return SendMode.mailApp;
  }
}
