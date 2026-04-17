// ─── User / Auth ───────────────────────────────────────────────────────────

enum UserRole { admin, parent }

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? phoneSecondary;
  final UserRole role;
  final String? token;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.phoneSecondary,
    required this.role,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      phoneSecondary: json['phoneSecondary'],
      role: json['role'] == 'admin' ? UserRole.admin : UserRole.parent,
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'phoneSecondary': phoneSecondary,
        'role': role == UserRole.admin ? 'admin' : 'parent',
      };

  User copyWith({
    String? name,
    String? email,
    String? phone,
    String? phoneSecondary,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      phoneSecondary: phoneSecondary ?? this.phoneSecondary,
      role: role,
      token: token,
    );
  }
}

// ─── Message ────────────────────────────────────────────────────────────────

enum MessageType { general, meeting, reminder, cultural, urgent }

class Message {
  final String id;
  final String title;
  final String content;
  final String sender;
  final DateTime sentAt;
  final bool isNew;
  final MessageType type;
  final String? className; // e.g. "1º Ano - A"
  final String? parentName;

  const Message({
    required this.id,
    required this.title,
    required this.content,
    required this.sender,
    required this.sentAt,
    this.isNew = false,
    this.type = MessageType.general,
    this.className,
    this.parentName,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      sender: json['sender'] ?? '',
      sentAt: DateTime.tryParse(json['sentAt'] ?? '') ?? DateTime.now(),
      isNew: json['isNew'] ?? false,
      type: _parseType(json['type']),
      className: json['className'],
      parentName: json['parentName'],
    );
  }

  static MessageType _parseType(String? type) {
    switch (type) {
      case 'meeting':
        return MessageType.meeting;
      case 'reminder':
        return MessageType.reminder;
      case 'cultural':
        return MessageType.cultural;
      case 'urgent':
        return MessageType.urgent;
      default:
        return MessageType.general;
    }
  }

  String get typeLabel {
    switch (type) {
      case MessageType.meeting:
        return 'Reunião';
      case MessageType.reminder:
        return 'Lembrete';
      case MessageType.cultural:
        return 'Cultural';
      case MessageType.urgent:
        return 'Urgente';
      default:
        return 'Geral';
    }
  }
}

// ─── Student ────────────────────────────────────────────────────────────────

class Student {
  final String id;
  final String name;
  final String grade;  // série: "1º Ano"
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
      className: json['className'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'grade': grade,
        'className': className,
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
  final List<String> studentIds;

  const Parent({
    required this.id,
    required this.name,
    required this.phone,
    this.phoneSecondary,
    required this.email,
    this.emailSecondary,
    required this.studentIds,
  });

  factory Parent.fromJson(Map<String, dynamic> json) {
    return Parent(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      phoneSecondary: json['phoneSecondary'],
      email: json['email'] ?? '',
      emailSecondary: json['emailSecondary'],
      studentIds: List<String>.from(json['studentIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'phoneSecondary': phoneSecondary,
        'email': email,
        'emailSecondary': emailSecondary,
        'studentIds': studentIds,
      };
}

// ─── Send Message Request ────────────────────────────────────────────────────

class SendMessageRequest {
  final String title;
  final String content;
  final String type;
  final String? targetClass;    // null = todos
  final String? targetParentId; // envio individual

  const SendMessageRequest({
    required this.title,
    required this.content,
    required this.type,
    this.targetClass,
    this.targetParentId,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'type': type,
        if (targetClass != null) 'targetClass': targetClass,
        if (targetParentId != null) 'targetParentId': targetParentId,
      };
}