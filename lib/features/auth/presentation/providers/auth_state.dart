class AuthProfile {
  final String userId;
  final String name;
  final String? email;

  const AuthProfile({
    required this.userId,
    required this.name,
    this.email,
  });
}

class AuthState {
  /// Cold start only: hydrating token from secure storage (`tryAutoLogin`).
  final bool isInitializing;

  /// Password or OTP verification request in flight; does not replace the login UI.
  final bool isAuthenticating;

  final AuthProfile? profile;
  final Map<String, dynamic>? rawUser;

  const AuthState({
    required this.isInitializing,
    this.isAuthenticating = false,
    required this.profile,
    required this.rawUser,
  });

  const AuthState.initial()
      : this(
          isInitializing: true,
          isAuthenticating: false,
          profile: null,
          rawUser: null,
        );

  AuthState copyWith({
    bool? isInitializing,
    bool? isAuthenticating,
    AuthProfile? profile,
    Map<String, dynamic>? rawUser,
  }) {
    return AuthState(
      isInitializing: isInitializing ?? this.isInitializing,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      profile: profile ?? this.profile,
      rawUser: rawUser ?? this.rawUser,
    );
  }
}

