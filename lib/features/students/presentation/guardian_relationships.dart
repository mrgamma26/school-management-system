import 'package:flutter/material.dart';

/// Relationship of a guardian to the student, as stored in
/// `studentguardian.relationship` and accepted by `admit_student`.
const guardianRelationships = <String, String>{
  'MOTHER': 'Mother',
  'FATHER': 'Father',
  'SISTER': 'Sister',
  'BROTHER': 'Brother',
  'GRANDMOTHER': 'Grandmother',
  'GRANDFATHER': 'Grandfather',
  'AUNTIE': 'Auntie',
  'UNCLE': 'Uncle',
  'GUARDIAN': 'Guardian',
  'OTHER': 'Other',
};

/// Older values still on existing links; shown only when already selected.
const _legacyRelationships = <String, String>{
  'PARENT': 'Parent',
  'SIBLING': 'Sibling',
  'GRANDPARENT': 'Grandparent',
  'UNCLE/AUNT': 'Uncle/Aunt',
};

const defaultGuardianRelationship = 'GUARDIAN';

/// Dropdown items for the relationship list. A [current] value that is not in
/// the list (an older link) is kept as an extra item so the field still shows
/// it.
List<DropdownMenuItem<String>> relationshipMenuItems(String? current) => [
  for (final e in guardianRelationships.entries)
    DropdownMenuItem(value: e.key, child: Text(e.value)),
  if (current != null && !guardianRelationships.containsKey(current))
    DropdownMenuItem(
      value: current,
      child: Text(_legacyRelationships[current] ?? current),
    ),
];
