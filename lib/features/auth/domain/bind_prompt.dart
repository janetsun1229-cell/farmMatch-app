/// Soft bind prompts from GAME_FEATURES §5.14.
///
/// Level 5 offers cloud save and can be skipped. Level 8, if still unbound,
/// offers bind plus friend gifts. Level 10 never forces a login.
enum BindPromptKind { none, cloudSave, inviteFriends }

class BindPromptGate {
  const BindPromptGate._();

  static const cloudSaveLevel = 5;
  static const inviteLevel = 8;

  static BindPromptKind evaluate({
    required int clearedLevel,
    required bool bound,
    required bool cloudSaveDismissed,
    required bool inviteDismissed,
  }) {
    if (bound) return BindPromptKind.none;
    if (clearedLevel == cloudSaveLevel && !cloudSaveDismissed) {
      return BindPromptKind.cloudSave;
    }
    if (clearedLevel == inviteLevel && !inviteDismissed) {
      return BindPromptKind.inviteFriends;
    }
    return BindPromptKind.none;
  }
}

class BindCopy {
  const BindCopy._();

  static const cloudSaveBody =
      'Save your progress? Link X or Facebook. You can skip.';
  static const inviteBody =
      'Invite friends — gift free daily tools & keep progress safe.';
}
