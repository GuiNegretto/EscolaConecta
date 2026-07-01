
import 'package:flutter/foundation.dart';

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

class MessageAttachment {
  final String id;
  final String fileName;
  final String fileType;
  final String url;

  const MessageAttachment({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.url,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id']?.toString() ?? '',
      fileName: json['file_name'] ?? json['fileName'] ?? '',
      fileType: json['file_type'] ?? json['fileType'] ?? '',
      url: json['url'] ?? json['file_path'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'file_name': fileName,
        'file_type': fileType,
        'url': url,
      };

  bool get isImage => fileType.startsWith('image/');
  bool get isVideo => fileType.startsWith('video/');
  bool get isPdf => fileType == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf');
}

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
  final List<MessageAttachment> attachments;

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
    this.attachments = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['created_at'] ?? json['sentAt'] ?? json['createdAt'];
    final rawScheduledAt = json['scheduled_at'] ?? json['scheduledAt'];
    final rawSentAt = json['sent_at'] ?? json['sentAt'];

    // Parse attachments
    final List<MessageAttachment> attachmentsList = [];
    if (json['attachments'] != null) {
      final attachmentsJson = json['attachments'] as List<dynamic>?;
      if (attachmentsJson != null) {
        for (var att in attachmentsJson) {
          if (att is Map<String, dynamic>) {
            attachmentsList.add(MessageAttachment.fromJson(att));
          }
        }
      }
    }

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
      status: _parseStatusFromDraft(json['is_draft'], json['status']?.toString()),
      className: json['className'] ?? json['class_name'],
      parentName: json['parentName'] ?? json['parent_name'],
      recipientCount: json['recipient_count'] as int?,
      successCount: json['success_count'] as int?,
      failureCount: json['failure_count'] as int?,
      attachments: attachmentsList,
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

  static MessageStatus _parseStatusFromDraft(dynamic isDraft, String? status) {
    // Prioridade para o campo is_draft que vem do banco Go
    if (isDraft != null) {
      final boolDraft = isDraft == true || isDraft == 1 || isDraft == "1";
      if (!boolDraft) {
        return MessageStatus.sent; // Se não é rascunho, consideramos enviada
      }
    }

    // Fallback para o campo status se existir
    switch (status?.toLowerCase()) {
      case 'draft':
        return MessageStatus.draft;
      case 'scheduled':
        return MessageStatus.scheduled;
      case 'sent':
        return MessageStatus.sent;
      default:
        return (isDraft == false || isDraft == 0) ? MessageStatus.sent : MessageStatus.draft;
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
  bool get canSend => (status == MessageStatus.draft || status == MessageStatus.scheduled) && status != MessageStatus.sent && sentAt == null;
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
  final List<Student> students;

  const Parent({
    required this.id,
    required this.name,
    required this.phone,
    this.phoneSecondary,
    required this.email,
    this.emailSecondary,
    this.cpf,
    required this.studentIds,
    this.students = const [],
  });

  factory Parent.fromJson(Map<String, dynamic> json) {
    final studentsList = (json['students'] as List<dynamic>?)
            ?.map((s) => Student.fromJson(s))
            .toList() ??
        [];

    return Parent(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      phoneSecondary: json['phoneSecondary'] ?? json['phone_secondary'],
      email: json['email'] ?? '',
      emailSecondary: json['emailSecondary'] ?? json['email_secondary'],
      cpf: json['cpf'],
      studentIds: studentsList.isNotEmpty
          ? studentsList.map((s) => s.id).toList()
          : List<String>.from(json['studentIds'] ?? json['student_ids'] ?? []),
      students: studentsList,
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

// ─── CSV Import Models ──────────────────────────────────────────────────────

class ImportError {
  final int row;
  final String field;
  final String message;

  const ImportError({
    required this.row,
    required this.field,
    required this.message,
  });

  factory ImportError.fromJson(Map<String, dynamic> json) {
    return ImportError(
      row: ImportResult._asInt(json['row']),
      field: json['field'] ?? json['column'] ?? '',
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'row': row,
        'field': field,
        'message': message,
      };
}

class ImportResult {
  final int totalProcessed;
  final int totalImported;
  final int totalIgnored;
  final int totalErrors;
  final List<ImportError> errors;
  final DateTime? importedAt;

  const ImportResult({
    required this.totalProcessed,
    required this.totalImported,
    required this.totalIgnored,
    required this.totalErrors,
    required this.errors,
    this.importedAt,
  });

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    final errorsList = (json['errors'] as List<dynamic>?)
            ?.map((e) => ImportError.fromJson(e is Map<String, dynamic> ? e : {}))
            .toList() ??
        [];

    return ImportResult(
      totalProcessed: _asInt(json['total_processed'] ?? json['total']),
      totalImported: _asInt(json['total_imported'] ?? json['imported']),
      totalIgnored: _asInt(json['total_ignored'] ?? json['ignored']),
      totalErrors: _asInt(
        json['total_errors'] ?? json['failed'],
        fallback: errorsList.length,
      ),
      errors: errorsList,
      importedAt: json['imported_at'] != null
          ? DateTime.tryParse(json['imported_at'].toString())
          : DateTime.now(),
    );
  }

  /// Converte dinamicamente qualquer valor para `int` de forma segura.
  ///
  /// Foi adicionada para evitar `TypeError: type '_JsonMap' is not a subtype
  /// of type 'int'` quando o backend retorna um objeto/Map em um campo que o
  /// app espera como número (ex: `"total": { "students": 10 }`).
  ///
  /// Comportamento:
  /// - `null` ou ausente → [fallback] (padrão `0`)
  /// - `int` → retorna direto
  /// - `double` → converte com `.toInt()`
  /// - `String` numérica (`"10"`) → `int.tryParse` ou [fallback]
  /// - `bool` → `1` se `true`, caso contrário [fallback]
  /// - `Map` / List / outro tipo inesperado → loga um warning e retorna
  ///   [fallback] (NUNCA lança TypeError).
  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    if (value is bool) return value ? 1 : fallback;

    // Formato inesperado (Map/Lista/etc.). Loga e usa fallback em vez de
    // quebrar a tela com TypeError.
    // ignore: avoid_print
    debugPrint(
      '[ImportResult] Campo numérico veio em formato inesperado: '
      '$value (${value.runtimeType}) — usando fallback=$fallback. '
      'Verifique o JSON retornado pelo backend.',
    );
    return fallback;
  }

  Map<String, dynamic> toJson() => {
        'total_processed': totalProcessed,
        'total_imported': totalImported,
        'total_ignored': totalIgnored,
        'total_errors': totalErrors,
        'errors': errors.map((e) => e.toJson()).toList(),
        'imported_at': importedAt?.toIso8601String(),
      };

  int get successRate => totalProcessed > 0 ? ((totalImported * 100) ~/ totalProcessed) : 0;
  bool get hasErrors => errors.isNotEmpty && totalErrors > 0;
}

class CsvRow {
  final int lineNumber;
  final String studentName;
  final String grade;
  final String className;
  final String guardianName;
  final String guardianEmail;
  final String guardianPhone;
  final String? guardianPhoneSecondary;
  final String? guardianEmailSecondary;
  String? validationError;

  CsvRow({
    required this.lineNumber,
    required this.studentName,
    required this.grade,
    required this.className,
    required this.guardianName,
    required this.guardianEmail,
    required this.guardianPhone,
    this.guardianPhoneSecondary,
    this.guardianEmailSecondary,
    this.validationError,
  });

  bool get isValid => validationError == null;

  factory CsvRow.fromCsvLine(List<dynamic> line, int lineNumber) {
    final row = CsvRow(
      lineNumber: lineNumber,
      studentName: _parseField(line, 0),
      grade: _parseField(line, 1),
      className: _parseField(line, 2),
      guardianName: _parseField(line, 3),
      guardianEmail: _parseField(line, 4),
      guardianPhone: _parseField(line, 5),
      guardianPhoneSecondary: _parseFieldOptional(line, 6),
      guardianEmailSecondary: _parseFieldOptional(line, 7),
    );

    // Validar
    row.validationError = row._validate();
    return row;
  }

  static String _parseField(List<dynamic> line, int index) {
    if (index >= line.length) return '';
    final value = line[index];
    return (value ?? '').toString().trim();
  }

  static String? _parseFieldOptional(List<dynamic> line, int index) {
    final value = _parseField(line, index);
    return value.isEmpty ? null : value;
  }

  String? _validate() {
    if (studentName.isEmpty) return 'Nome do aluno obrigatório';
    if (grade.isEmpty) return 'Série obrigatória';
    if (className.isEmpty) return 'Turma obrigatória';
    if (guardianName.isEmpty) return 'Nome do responsável obrigatório';
    if (guardianEmail.isEmpty) return 'Email do responsável obrigatório';
    if (!_isValidEmail(guardianEmail)) return 'Email do responsável inválido';
    if (guardianPhone.isEmpty) return 'Telefone do responsável obrigatório';
    return null;
  }

  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  Map<String, dynamic> toJson() => {
        'student_name': studentName,
        'grade': grade,
        'class': className,
        'guardian_name': guardianName,
        'guardian_email': guardianEmail,
        'guardian_phone': guardianPhone,
        if (guardianPhoneSecondary != null && guardianPhoneSecondary!.isNotEmpty)
          'guardian_phone_secondary': guardianPhoneSecondary,
        if (guardianEmailSecondary != null && guardianEmailSecondary!.isNotEmpty)
          'guardian_email_secondary': guardianEmailSecondary,
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