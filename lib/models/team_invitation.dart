class TeamInvitation {
  final String id;
  final Team team;
  final User inviter;
  final User invitee;
  final String email;
  final String role;
  final String status; // 'pending', 'accepted', 'declined', 'expired'
  final DateTime expiresAt;
  final String? message;
  final DateTime createdAt;

  TeamInvitation({
    required this.id,
    required this.team,
    required this.inviter,
    required this.invitee,
    required this.email,
    required this.role,
    required this.status,
    required this.expiresAt,
    this.message,
    required this.createdAt,
  });

  factory TeamInvitation.fromJson(Map<String, dynamic> json) {
    return TeamInvitation(
      id: json['_id'] ?? json['id'],
      team: Team.fromJson(json['team']),
      inviter: User.fromJson(json['inviter']),
      invitee: User.fromJson(json['invitee']),
      email: json['email'],
      role: json['role'] ?? 'member',
      status: json['status'] ?? 'pending',
      expiresAt: DateTime.parse(json['expiresAt']),
      message: json['message'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  bool get isPending => status == 'pending';
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get canRespond => isPending && !isExpired;
}
