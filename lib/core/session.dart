// DDE-Mart handyman app — session management (original).
//
// Access tokens are long-lived, but they can still die server-side
// (password reset, admin revoke, account wipe). Any 401 outside the auth
// endpoints therefore means "signed out everywhere": drop the local session
// so the router gate sends the user back to sign-in instead of failing
// every screen forever.

/// True when an HTTP failure must invalidate the local session.
bool shouldForceSignOut({required int? status, required String path}) {
  if (status != 401) return false;
  // Auth endpoints 401 for bad credentials/codes — that must NOT wipe an
  // existing session (e.g. verifying a new number while signed in).
  const authPaths = ['/auth/', '/work/auth/', '/otp'];
  for (final prefix in authPaths) {
    if (path.contains(prefix)) return false;
  }
  return true;
}
