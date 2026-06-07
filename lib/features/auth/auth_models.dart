import 'package:flutter/material.dart';

import 'auth_claims.dart';

/// Akshara ERP roles — persisted for multi-app routing (Parent, Teacher, etc.).
enum UserRole {
  parent,
  teacher,
  student,
  staff;

  String get label => switch (this) {
        UserRole.parent => 'Parent',
        UserRole.teacher => 'Teacher',
        UserRole.student => 'Student',
        UserRole.staff => 'Staff',
      };

  static UserRole? fromName(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final role in UserRole.values) {
      if (role.name == value) {
        return role;
      }
    }
    return null;
  }

  IconData get demoIcon => switch (this) {
        UserRole.parent => Icons.family_restroom_outlined,
        UserRole.teacher => Icons.school_outlined,
        UserRole.student => Icons.person_outline,
        UserRole.staff => Icons.badge_outlined,
      };
}

/// Roles selectable on the demo login screen.
const List<UserRole> kDemoLoginRoles = [
  UserRole.parent,
  UserRole.teacher,
  UserRole.student,
];

/// Child linked to a parent account (multi-child households).
class LinkedChild {
  const LinkedChild({
    required this.id,
    required this.name,
    required this.classLabel,
  });

  final String id;
  final String name;
  final String classLabel;

  LinkedChild copyWith({
    String? id,
    String? name,
    String? classLabel,
  }) {
    return LinkedChild(
      id: id ?? this.id,
      name: name ?? this.name,
      classLabel: classLabel ?? this.classLabel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkedChild &&
          id == other.id &&
          name == other.name &&
          classLabel == other.classLabel;

  @override
  int get hashCode => Object.hash(id, name, classLabel);
}

/// Mock authentication session state for the parent app (P-01 → P-03).
enum AuthStatus {
  /// Session not yet resolved from local storage (splash).
  unknown,

  /// No active session.
  unauthenticated,

  /// OTP sent; awaiting verification.
  otpPending,

  /// Session established (memory + persisted).
  authenticated,
}

/// Immutable auth snapshot consumed by router redirects and screens.
class AuthState {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.phoneNumber,
    this.displayName,
    this.role,
    this.selectedChild,
    this.linkedChildren = const [],
    this.claims,
  });

  final AuthStatus status;
  final String? phoneNumber;
  final String? displayName;
  final UserRole? role;
  final LinkedChild? selectedChild;
  final List<LinkedChild> linkedChildren;

  /// Mock JWT claims (userId, erpRole, tenant, permissions).
  final AuthClaims? claims;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  bool get isSessionResolved => status != AuthStatus.unknown;

  AuthState copyWith({
    AuthStatus? status,
    String? phoneNumber,
    String? displayName,
    UserRole? role,
    LinkedChild? selectedChild,
    List<LinkedChild>? linkedChildren,
    AuthClaims? claims,
    bool clearPhone = false,
    bool clearDisplayName = false,
    bool clearRole = false,
    bool clearSelectedChild = false,
    bool clearClaims = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneNumber: clearPhone ? null : (phoneNumber ?? this.phoneNumber),
      displayName:
          clearDisplayName ? null : (displayName ?? this.displayName),
      role: clearRole ? null : (role ?? this.role),
      selectedChild: clearSelectedChild
          ? null
          : (selectedChild ?? this.selectedChild),
      linkedChildren: linkedChildren ?? this.linkedChildren,
      claims: clearClaims ? null : (claims ?? this.claims),
    );
  }
}
