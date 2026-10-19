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
  final String id;
  final String to;
  final String subject;
  final DateTime sentAt;

  /// True if sent directly via Gmail; false if handed off to the mail app.
  final bool direct;
  final String status;

  SentRecord({
    String? id,
    required this.to,
    required this.subject,
    required this.sentAt,
    this.direct = true,
    String? status,
  })  : id = (id != null && id.isNotEmpty)
            ? id
            : sentAt.microsecondsSinceEpoch.toString(),
        status = status ??
            (direct ? 'Sent directly via Gmail' : 'Opened in mail app');

  Map<String, dynamic> toJson() => {
        'id': id,
        'to': to,
        'subject': subject,
        'sentAt': sentAt.toIso8601String(),
        'direct': direct,
        'status': status,
      };

  factory SentRecord.fromJson(Map<String, dynamic> j) => SentRecord(
        id: j['id']?.toString(),
        to: j['to'] ?? '',
        subject: j['subject'] ?? '',
        sentAt: j['sentAt'] != null
            ? DateTime.parse(j['sentAt'])
            : DateTime.now(),
        direct: j['direct'] ?? false,
        status: j['status']?.toString(),
      );
}

class CoverLetter {
  final String id;
  final String title;
  final String content;
  final DateTime updatedAt;

  const CoverLetter({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  CoverLetter copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? updatedAt,
  }) {
    return CoverLetter(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CoverLetter.fromJson(Map<String, dynamic> j) => CoverLetter(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        content: j['content'] as String? ?? '',
        updatedAt: j['updatedAt'] != null
            ? DateTime.tryParse(j['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
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

const defaultCoverLetterTitle = 'Senior Flutter Developer';
const defaultCoverLetterBody = defaultTemplateBody;
