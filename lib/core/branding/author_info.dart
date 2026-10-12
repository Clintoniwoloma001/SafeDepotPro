// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
/// Single source of truth for authorship and contact strings.
///
/// The integrity check in `lib/core/branding/build_integrity.dart` hashes these
/// exact values, and the footer and about page render the same constants, so
/// there is exactly one place to change them and one place the check protects.
library;

/// Copyright and license identifier used in every file header.
const String kCopyrightHolder = 'Flatra Tech Ltd';

/// Short byline shown in the footer of every primary screen.
const String kCreditLine = 'Made by ImaginirCo-Flatra';

/// Lead designer and developer.
const String kAuthorName = 'Clinton Iwoloma';

/// Professional title used in the extended credit.
const String kAuthorTitle = 'The Imaginr, CEO, Flatra Tech Ltd';

/// Contact number for the full attribution shown on the About page.
const String kContactPhone = '+2349025975247';

/// Full human-readable attribution, About page only.
///
/// Kept as one string so the header script and the About page cannot drift:
/// the copy is identical wherever it appears.
const String kFullAttribution =
    'Designed and developed by $kAuthorName — $kAuthorTitle. '
    'For more jobs and automation workflows contact $kContactPhone.';

/// Company contact route for licensing enquiries.
const String kContactEmail = 'clinton@flatratech.com';

/// Product identity, used for the legal notices.
const String kProductName = 'SafeDepot Pro';

/// Copyright statement used in the file header banner and the NOTICE file.
const String kCopyrightNotice =
    '© $kCopyrightHolder. All rights reserved.';

/// The exact header comment appended to every source file by
/// `tool/add_headers.dart`. Order matters — the script detects the banner by
/// matching these lines.
const List<String> kFileHeaderLines = [
  '// $kCopyrightNotice',
  '// Designed and developed by $kAuthorName — $kAuthorTitle.',
  '// Proprietary and confidential. Unauthorized copying, modification, '
      'distribution or reuse is prohibited.',
  '// Contact: $kContactPhone',
];
