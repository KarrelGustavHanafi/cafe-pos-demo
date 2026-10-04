enum UserRole {
  owner,
  cashier,
}

class User {
  final String username;
  final String displayName;
  final UserRole role;

  const User({
    required this.username,
    required this.displayName,
    required this.role,
  });

  bool get isOwner => role == UserRole.owner;
  bool get isCashier => role == UserRole.cashier;
}
