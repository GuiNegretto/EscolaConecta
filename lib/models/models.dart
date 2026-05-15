// ─── User / Auth ───────────────────────────────────────────────────────────

enum UserRole { admin, parent }

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? phoneSecondary;
  final String? emailSecondary;
  final UserRole role;
  final String? token;
  final int? firstAccess;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.phoneSecondary,
    this.emailSecondary,
    required this.role,
    this.token,
    this.firstAccess,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? json['phone_secondary'],
      phoneSecondary: json['phoneSecondary'] ?? json['phone_secondary'],
      emailSecondary: json['emailSecondary'] ?? json['email_secondary'],
      role: json['role'] == 'admin' ? UserRole.admin : UserRole.parent,
      token: json['token'],
      firstAccess: json['first_access'] is int
          ? json['first_access'] as int
          : int.tryParse(json['first_access']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'phone_secondary': phoneSecondary,
        'email_secondary': emailSecondary,
        'role': role == UserRole.admin ? 'admin' : 'guardian',
        'token': token,
        'first_access': firstAccess,
      };

  User copyWith({
    String? name,
    String? email,
    String? phone,
    String? phoneSecondary,
    String? emailSecondary,
    String? token,
    int? firstAccess,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      phoneSecondary: phoneSecondary ?? this.phoneSecondary,
      emailSecondary: emailSecondary ?? this.emailSecondary,
      role: role,
      token: token ?? this.token,
      firstAccess: firstAccess ?? this.firstAccess,
    );
  }
}

// ─── Message ────────────────────────────────────────────────────────────────

enum MessageType { geral, turma, individual }
enum MessageStatus { draft, scheduled, pending, sending, sent, cancelled, failed }

class Message {
  final String id;
  final String title;
  final String content;
  final String sender;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final bool isNew;
  final MessageType type;
  final MessageStatus status;
  final String? className;
  final String? parentName;
  final int? recipientCount;
  final int? successCount;
  final int? failureCount;

  const Message({
    required this.id,
    required this.title,
    required this.content,
    required this.sender,
    required this.createdAt,
    this.scheduledAt,
    this.sentAt,
    this.isNew = false,
    this.type = MessageType.geral,
    this.status = MessageStatus.draft,
    this.className,
    this.parentName,
    this.recipientCount,
    this.successCount,
    this.failureCount,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['created_at'] ?? json['sentAt'] ?? json['createdAt'];
    final rawScheduledAt = json['scheduled_at'] ?? json['scheduledAt'];
    final rawSentAt = json['sent_at'] ?? json['sentAt'];

    return Message(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['body'] ?? json['content'] ?? '',
      sender: json['sender_name'] ?? json['sender'] ?? '',
      createdAt: DateTime.tryParse(rawCreatedAt?.toString() ?? '') ?? DateTime.now(),
      scheduledAt: rawScheduledAt != null ? DateTime.tryParse(rawScheduledAt.toString()) : null,
      sentAt: rawSentAt != null ? DateTime.tryParse(rawSentAt.toString()) : null,
      isNew: !(json['read'] == true),
      type: _parseType(json['type']?.toString()),
      status: _parseStatus(json['status']?.toString()),
      className: json['className'] ?? json['class_name'],
      parentName: json['parentName'] ?? json['parent_name'],
      recipientCount: json['recipient_count'] as int?,
      successCount: json['success_count'] as int?,
      failureCount: json['failure_count'] as int?,
    );
  }

  static MessageType _parseType(String? type) {
    switch (type) {
      case 'turma':
        return MessageType.turma;
      case 'individual':
        return MessageType.individual;
      default:
        return MessageType.geral;
    }
  }

  static MessageStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft':
        return MessageStatus.draft;
      case 'scheduled':
        return MessageStatus.scheduled;
      case 'pending':
        return MessageStatus.pending;
      case 'sending':
        return MessageStatus.sending;
      case 'sent':
        return MessageStatus.sent;
      case 'cancelled':
        return MessageStatus.cancelled;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.draft;
    }
  }

  String get typeLabel {
    switch (type) {
      case MessageType.turma:
        return 'Turma';
      case MessageType.individual:
        return 'Individual';
      default:
        return 'Geral';
    }
  }

  String get statusLabel {
    switch (status) {
      case MessageStatus.draft:
        return 'Rascunho';
      case MessageStatus.scheduled:
        return 'Agendada';
      case MessageStatus.pending:
        return 'Pendente';
      case MessageStatus.sending:
        return 'Enviando';
      case MessageStatus.sent:
        return 'Enviada';
      case MessageStatus.cancelled:
        return 'Cancelada';
      case MessageStatus.failed:
        return 'Falha';
    }
  }

  bool get canEdit => status == MessageStatus.draft || status == MessageStatus.scheduled;
  bool get canSend => status == MessageStatus.draft || status == MessageStatus.scheduled;
  bool get canCancel => status == MessageStatus.scheduled || status == MessageStatus.pending;
  bool get canDuplicate => status == MessageStatus.sent || status == MessageStatus.draft;
}

// ─── Student ────────────────────────────────────────────────────────────────

class Student {
  final String id;
  final String name;
  final String grade; // série: "1º Ano"
  final String className; // turma: "A"

  const Student({
    required this.id,
    required this.name,
    required this.grade,
    required this.className,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      grade: json['grade'] ?? '',
      className: json['className'] ?? json['class'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'grade': grade,
        'class': className,
      };

  String get fullClass => '$grade - $className';
}

// ─── Parent / Responsável ────────────────────────────────────────────────────

class Parent {
  final String id;
  final String name;
  final String phone;
  final String? phoneSecondary;
  final String email;
  final String? emailSecondary;
  final String? cpf;
  final List<String> studentIds;

  const Parent({
    required this.id,
    required this.name,
    required this.phone,
    this.phoneSecondary,
    required this.email,
    this.emailSecondary,
    this.cpf,
    required this.studentIds,
  });

  factory Parent.fromJson(Map<String, dynamic> json) {
    return Parent(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      phoneSecondary: json['phoneSecondary'] ?? json['phone_secondary'],
      email: json['email'] ?? '',
      emailSecondary: json['emailSecondary'] ?? json['email_secondary'],
      cpf: json['cpf'],
      studentIds: List<String>.from(json['studentIds'] ?? json['student_ids'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        if (phoneSecondary != null) 'phone_secondary': phoneSecondary,
        'email': email,
        if (emailSecondary != null) 'email_secondary': emailSecondary,
        if (cpf != null) 'cpf': cpf,
        'student_ids': studentIds,
      };
}

// ─── Send Message Request ────────────────────────────────────────────────────

class SendMessageRequest {
  final String title;
  final String content;
  final String type;
  final String? targetClass; // "3º Ano - A"
  final String? targetParentId;
  final bool isDraft;
  final DateTime? scheduledAt;

  const SendMessageRequest({
    required this.title,
    required this.content,
    required this.type,
    this.targetClass,
    this.targetParentId,
    this.isDraft = false,
    this.scheduledAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': content,
        'type': type,
        if (targetClass != null) 'class': targetClass,
        if (targetParentId != null) 'guardian_ids': [targetParentId],
        'is_draft': isDraft,
        if (scheduledAt != null) 'scheduled_at': scheduledAt!.toUtc().toIso8601String(),
      };
}

// ─── Student-Parent Link (Vínculo Aluno-Responsável) ─────────────────────────

class StudentParentLink {
  final Student student;
  final List<Parent> parents;

  const StudentParentLink({
    required this.student,
    required this.parents,
  });

  factory StudentParentLink.fromJson(Map<String, dynamic> json) {
    return StudentParentLink(
      student: Student.fromJson(json['student'] ?? {}),
      parents: (json['parents'] as List<dynamic>?)
          ?.map((p) => Parent.fromJson(p))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'student': student.toJson(),
        'parents': parents.map((p) => p.toJson()).toList(),
      };
}

// ─── Link Management Request ─────────────────────────────────────────────────

class LinkStudentParentRequest {
  final String studentId;
  final String parentId;

  const LinkStudentParentRequest({
    required this.studentId,
    required this.parentId,
  });

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'parent_id': parentId,
      };
}

class UnlinkStudentParentRequest {
  final String studentId;
  final String parentId;

  const UnlinkStudentParentRequest({
    required this.studentId,
    required this.parentId,
  });

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'parent_id': parentId,
      };
}