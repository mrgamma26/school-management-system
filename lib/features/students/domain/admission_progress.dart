// Progress of the student admission workspace, derived from what is typed so
// far. Pure Dart so the stage ticks and the "still needed" list can be tested
// without building the page.
//
// Required to submit (matches `_submit` in the form page): the student's first
// and last name and date of birth, plus at least one guardian - either an
// existing guardian that is linked, or a new guardian with first name, last
// name and email. A class placement is optional.

/// One new-guardian card as typed by the administrator.
class NewGuardianDraft {
  final String firstName;
  final String lastName;
  final String email;

  /// True when any field of the card (including phone / address) is filled in.
  final bool touched;

  const NewGuardianDraft({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.touched = false,
  });

  bool get complete =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      email.trim().isNotEmpty;
}

class AdmissionProgress {
  /// Stage numbers used by the workspace.
  static const studentStage = 0;
  static const guardianStage = 1;
  static const classStage = 2;
  static const accessStage = 3;
  static const reviewStage = 4;

  final bool studentReady;
  final bool guardianReady;
  final bool classChosen;
  final int existingGuardians;
  final int newGuardians;
  final List<String> blockers;

  const AdmissionProgress._({
    required this.studentReady,
    required this.guardianReady,
    required this.classChosen,
    required this.existingGuardians,
    required this.newGuardians,
    required this.blockers,
  });

  factory AdmissionProgress.from({
    required String firstName,
    required String lastName,
    required bool hasDateOfBirth,
    required int existingGuardians,
    required Iterable<NewGuardianDraft> newGuardianDrafts,
    required bool classChosen,
  }) {
    final drafts = newGuardianDrafts.toList();
    final completeNew = drafts.where((g) => g.complete).length;
    final halfFilled = drafts.where((g) => g.touched && !g.complete).length;
    final studentReady =
        firstName.trim().isNotEmpty &&
        lastName.trim().isNotEmpty &&
        hasDateOfBirth;
    final guardianReady =
        (existingGuardians > 0 || completeNew > 0) && halfFilled == 0;

    final blockers = <String>[
      if (firstName.trim().isEmpty) "Student's first name",
      if (lastName.trim().isEmpty) "Student's last name",
      if (!hasDateOfBirth) 'Date of birth',
      if (existingGuardians == 0 && completeNew == 0)
        'A linked or new guardian',
      if (halfFilled > 0) 'Finish or clear the partly filled guardian',
    ];
    return AdmissionProgress._(
      studentReady: studentReady,
      guardianReady: guardianReady,
      classChosen: classChosen,
      existingGuardians: existingGuardians,
      newGuardians: completeNew,
      blockers: blockers,
    );
  }

  /// Every required item is in place.
  bool get canSubmit => studentReady && guardianReady;

  /// First stage that still needs attention; the class stage is suggested
  /// (not required) once the required stages are done.
  int get currentStage {
    if (!studentReady) return studentStage;
    if (!guardianReady) return guardianStage;
    if (!classChosen) return classStage;
    return reviewStage;
  }

  /// Stages that show a tick. Class is only ticked once a class is chosen;
  /// access follows the guardian; review follows everything required.
  Set<int> get completedStages => {
    if (studentReady) studentStage,
    if (guardianReady) guardianStage,
    if (classChosen) classStage,
    if (guardianReady) accessStage,
    if (canSubmit) reviewStage,
  };

  /// Number of guardians that will be linked by the submission.
  int get guardiansToLink => existingGuardians + newGuardians;
}
