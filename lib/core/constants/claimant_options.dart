/// Government-issued ID types accepted for claimant verification in the
/// Philippines. Matches the standard "valid ID" list LGUs and banks use for
/// over-the-counter identity checks.
const List<String> philippineIdTypes = [
  'Philippine Passport',
  "Driver's License",
  'UMID (SSS/GSIS/PhilHealth/Pag-IBIG)',
  'PhilSys National ID',
  'PhilHealth ID',
  'Postal ID',
  "Voter's ID / Voter's Certification",
  'PRC ID',
  'TIN ID',
  'Senior Citizen ID',
  'PWD ID',
  'Barangay ID',
  'Other',
];

/// Common relationships between a representative claimant and the applicant.
const List<String> claimantRelations = [
  'Spouse',
  'Child',
  'Parent',
  'Sibling',
  'Grandchild',
  'Grandparent',
  'Guardian',
  'Relative',
  'Other',
];
