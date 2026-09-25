class EmailTemplate {
  final String id;
  final String name;
  final String subject;
  final String body;

  const EmailTemplate({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'subject': subject, 'body': body};

  factory EmailTemplate.fromJson(Map<String, dynamic> j) => EmailTemplate(
        id: j['id'],
        name: j['name'],
        subject: j['subject'],
        body: j['body'],
      );
}

class Resume {
  final String id;
  final String name;
  final String path;

  const Resume({required this.id, required this.name, required this.path});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'path': path};

  factory Resume.fromJson(Map<String, dynamic> j) =>
      Resume(id: j['id'], name: j['name'], path: j['path']);
}

class SentRecord {
  final String to;
  final String subject;
  final DateTime sentAt;

  const SentRecord(
      {required this.to, required this.subject, required this.sentAt});

  Map<String, dynamic> toJson() =>
      {'to': to, 'subject': subject, 'sentAt': sentAt.toIso8601String()};

  factory SentRecord.fromJson(Map<String, dynamic> j) => SentRecord(
        to: j['to'],
        subject: j['subject'],
        sentAt: DateTime.parse(j['sentAt']),
      );
}

const defaultTemplateSubject = 'Application for Senior Flutter Developer';

const defaultTemplateBody = '''Dear Hiring Manager,

I am writing to apply for the Flutter Developer position at your organization.

I have 4.5 years of professional experience in mobile application development, with strong hands-on experience in Flutter and Dart. I have developed, maintained, and improved mobile applications for both Android and iOS, with a focus on clean UI, performance, scalability, and a smooth user experience.

My key experience includes:

* Flutter & Dart development
* Android & iOS mobile application development
* REST API integration
* State management and application architecture
* UI implementation and responsive design
* Debugging and performance optimization
* App maintenance and deployment
* App Store and Google Play deployment

I have attached my latest resume for your consideration. You can also view my portfolio and work here:

Portfolio: https://shubham-resume-theta.vercel.app/

GitHub: https://github.com/sdycode

I would be happy to discuss how my experience and skills could contribute to your team. I look forward to hearing from you.

Best regards,
Shubham Yeole
Flutter / Mobile App Developer
8626043082
shubhamyeole123@gmail.com''';
