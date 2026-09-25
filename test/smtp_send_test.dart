import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:quick_apply/models.dart';
import 'package:quick_apply/services/email_service.dart';

/// Minimal SMTP server that records one message, optionally rejecting AUTH.
class FakeSmtpServer {
  late final ServerSocket _socket;
  final bool rejectAuth;
  final recipients = <String>[];
  String data = '';
  String? username;
  String? password;

  FakeSmtpServer({this.rejectAuth = false});

  int get port => _socket.port;

  Future<void> start() async {
    _socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _socket.listen(_handle);
  }

  Future<void> close() => _socket.close();

  void _handle(Socket client) {
    var inData = false;
    var authStep = 0; // 1 = awaiting username, 2 = awaiting password
    final buffer = StringBuffer();
    client.write('220 fake ESMTP\r\n');
    client
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (inData) {
        if (line == '.') {
          inData = false;
          data = buffer.toString();
          client.write('250 OK queued\r\n');
        } else {
          buffer.writeln(line);
        }
        return;
      }
      if (authStep == 1) {
        username = utf8.decode(base64.decode(line));
        authStep = 2;
        client.write('334 UGFzc3dvcmQ6\r\n');
        return;
      }
      if (authStep == 2) {
        password = utf8.decode(base64.decode(line));
        authStep = 0;
        client.write(rejectAuth
            ? '535 5.7.8 Username and Password not accepted\r\n'
            : '235 2.7.0 Accepted\r\n');
        return;
      }
      final cmd = line.toUpperCase();
      if (cmd.startsWith('EHLO') || cmd.startsWith('HELO')) {
        client.write('250-fake\r\n250 AUTH PLAIN LOGIN\r\n');
      } else if (cmd == 'AUTH LOGIN') {
        authStep = 1;
        client.write('334 VXNlcm5hbWU6\r\n');
      } else if (cmd.startsWith('MAIL FROM')) {
        client.write('250 OK\r\n');
      } else if (cmd.startsWith('RCPT TO')) {
        recipients.add(line.substring(line.indexOf('<') + 1, line.indexOf('>')));
        client.write('250 OK\r\n');
      } else if (cmd == 'DATA') {
        inData = true;
        client.write('354 End data with <CR><LF>.<CR><LF>\r\n');
      } else if (cmd == 'QUIT') {
        client.write('221 Bye\r\n');
        client.close();
      } else {
        client.write('250 OK\r\n');
      }
    });
  }
}

void main() {
  late Directory tmp;
  late Resume resume;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quick_apply_test');
    final file = File('${tmp.path}/resume.pdf')..writeAsStringSync('%PDF-1.4 fake resume');
    resume = Resume(id: '1', name: 'Shubham_Resume.pdf', path: file.path);
  });

  tearDown(() => tmp.delete(recursive: true));

  test('sendViaSmtp delivers recipient, subject, body and resume attachment', () async {
    final server = FakeSmtpServer();
    await server.start();

    await EmailService.sendViaSmtp(
      server: SmtpServer('127.0.0.1', port: server.port, allowInsecure: true, username: 'me@gmail.com', password: 'app-pass'),
      fromEmail: 'me@gmail.com',
      fromName: 'Shubham Yeole',
      recipients: ['hr@acme.com'],
      subject: defaultTemplateSubject,
      body: defaultTemplateBody,
      resume: resume,
    );
    await server.close();

    expect(server.username, 'me@gmail.com');
    expect(server.password, 'app-pass');
    expect(server.recipients, ['hr@acme.com']);
    expect(server.data, contains('subject: $defaultTemplateSubject'));
    expect(server.data, contains('from: Shubham Yeole <me@gmail.com>'));
    expect(server.data, contains('Shubham_Resume.pdf'));
    expect(server.data, contains(base64.encode(utf8.encode('%PDF-1.4 fake resume'))));
  });

  test('rejected login surfaces a clear message', () async {
    final server = FakeSmtpServer(rejectAuth: true);
    await server.start();

    Object? error;
    try {
      await EmailService.sendViaSmtp(
        server: SmtpServer('127.0.0.1', port: server.port, allowInsecure: true, username: 'me@gmail.com', password: 'wrong'),
        fromEmail: 'me@gmail.com',
        fromName: '',
        recipients: ['hr@acme.com'],
        subject: 's',
        body: 'b',
      );
    } catch (e) {
      error = e;
    }
    await server.close();

    expect(error, isA<SmtpClientAuthenticationException>());
    expect(EmailService.describeError(error!), contains('App Password'));
  });

  test('unreachable server maps to a network message', () async {
    Object? error;
    try {
      // Nothing listens on port 1.
      await EmailService.sendViaSmtp(
        server: SmtpServer('127.0.0.1', port: 1, allowInsecure: true),
        fromEmail: 'me@gmail.com',
        fromName: '',
        recipients: ['hr@acme.com'],
        subject: 's',
        body: 'b',
      );
    } catch (e) {
      error = e;
    }
    expect(EmailService.describeError(error!), contains('internet'));
  });
}
