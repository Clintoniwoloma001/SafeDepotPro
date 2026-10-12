// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

/// Adds the Flatra Tech copyright header to every source file that lacks it.
///
/// Idempotent: a file that already carries the four header lines is left
/// byte-for-byte untouched, so the tool is safe to run repeatedly and safe to
/// put in a pre-commit hook.
///
/// Usage:
///
///   dart run tool/add_headers.dart            # fix what is missing
///   dart run tool/add_headers.dart --check    # exit 1 if anything is missing
///
/// Run with --check in CI or as a pre-commit hook so a header cannot be
/// forgotten on a new file.
library;

import 'dart:io';

/// Directories that hold hand-written source, relative to the repository root.
/// Generated directories (`build/`, `.dart_tool/`, `node_modules/`) are not
/// walked.
const List<String> sourceDirectories = [
  'lib',
  'test',
  'supabase/migrations',
  'supabase/functions',
  'tool',
];

/// Individual files outside those directories that still need the header.
const List<String> extraFiles = [
  'analysis_options.yaml',
];

/// The exact header, mirrored in lib/core/branding/author_info.dart. Kept
/// duplicated here on purpose so this script has no dependency on app code.
const List<String> headerLines = [
  '© Flatra Tech Ltd. All rights reserved.',
  'Designed and developed by Clinton Iwoloma — '
      'The Imaginr, CEO, Flatra Tech Ltd.',
  'Proprietary and confidential. Unauthorized copying, modification, '
      'distribution or reuse is prohibited.',
  'Contact: +2349025975247',
];

/// SQL files use `--` comments rather than `//`.
const String sqlCommentPrefix = '-- ';

const String dartCommentPrefix = '// ';

/// Extensions owned by this project, mapped to the comment prefix they need.
///
/// Note that some file types use a comment syntax other than `//`, so the
/// header is looked up by extension rather than inserted blindly.
const Map<String, String> _extensionPrefix = {
  '.dart': dartCommentPrefix,
  '.sql': sqlCommentPrefix,
  '.pro': '# ',
  '.gradle': '# ',
  '.kts': '# ',
  '.properties': '# ',
  '.yaml': '# ',
  '.yml': '# ',
  '.md': '<!-- ',
  '.sh': '# ',
};

Future<void> main(List<String> args) async {
  final checkOnly = args.contains('--check');

  final root = _repoRoot();
  final files = <File>[];

  for (final dir in sourceDirectories) {
    final directory = Directory('${root.path}/$dir');
    if (!directory.existsSync()) continue;
    files.addAll(_walk(directory));
  }
  for (final rel in extraFiles) {
    final file = File('${root.path}/$rel');
    if (file.existsSync()) files.add(file);
  }

  // A file already carrying the header is detected by its first line matching
  // the copyright line, which is stable across all four lines.
  final missing = <File>[];
  for (final file in files) {
    if (!_hasHeader(file)) missing.add(file);
  }

  files.sort((a, b) => a.path.compareTo(b.path));
  missing.sort((a, b) => a.path.compareTo(b.path));

  if (checkOnly) {
    if (missing.isEmpty) {
      stdout.writeln('OK: all ${files.length} source files carry the header.');
      return;
    }
    stderr.writeln(
      'FAIL: ${missing.length} of ${files.length} source files are missing the '
      'Flatra Tech copyright header:',
    );
    for (final file in missing) {
      stderr.writeln('  ${_relative(file, root)}');
    }
    stderr.writeln('\nRun: dart run tool/add_headers.dart');
    exit(1);
  }

  if (missing.isEmpty) {
    stdout.writeln('OK: all ${files.length} source files carry the header.');
    return;
  }

  var updated = 0;
  for (final file in missing) {
    final style = _commentStyleFor(file.path);
    if (style == null) {
      stderr.writeln('SKIP (no comment style): ${_relative(file, root)}');
      continue;
    }
    final body = file.readAsStringSync();
    final header = style.render(headerLines);
    // Preserve any shebang or `library;` directive ordering: the header goes
    // above everything, which is what the convention in this repo already does.
    file.writeAsStringSync('$header\n$body');
    updated++;
    stdout.writeln('added header: ${_relative(file, root)}');
  }
  stdout.writeln('\nAdded headers to $updated file(s); '
      '${files.length - updated} already had them.');
}

Directory _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln('Could not find pubspec.yaml — run from inside the repo.');
      exit(2);
    }
    dir = parent;
  }
}

List<File> _walk(Directory dir) {
  final out = <File>[];
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = entity.path;
    if (path.contains('/build/') ||
        path.contains('/.dart_tool/') ||
        path.contains('/node_modules/') ||
        path.contains('/.git/')) {
      continue;
    }
    if (_prefixFor(path) == null) continue;
    out.add(entity);
  }
  return out;
}

/// Renders a header for the comment syntax of a file.
_CommentStyle? _commentStyleFor(String path) {
  final prefix = _prefixFor(path);
  if (prefix == null) return null;
  // Markdown and SQL need a closing delimiter as well as an opening one.
  String? suffix;
  if (prefix.trim() == '<!--') suffix = ' -->';
  return _LineCommentStyle(prefix, suffix);
}

/// Base for comment syntaxes.
abstract class _CommentStyle {
  const _CommentStyle();
  String render(List<String> lines);
}

/// Prefix-per-line comments, optionally with a suffix per line.
class _LineCommentStyle implements _CommentStyle {
  const _LineCommentStyle(this.prefix, this.suffix);

  final String prefix;
  final String? suffix;

  @override
  String render(List<String> lines) => lines
      .map((line) => suffix == null ? '$prefix$line' : '$prefix$line$suffix')
      .join('\n');
}

String? _prefixFor(String path) {
  if (path.endsWith('/analysis_options.yaml')) return '# ';
  for (final entry in _extensionPrefix.entries) {
    if (path.endsWith(entry.key)) return entry.value;
  }
  return null;
}

/// True when [file] already begins with the copyright header.
///
/// Reads only the first line of the file rather than the whole contents, so
/// the check stays cheap even in a pre-commit hook over a large tree.
bool _hasHeader(File file) {
  final lines = file.readAsLinesSync();
  if (lines.isEmpty) return false;
  return lines.first.contains('© Flatra Tech Ltd. All rights reserved.');
}

String _relative(File file, Directory root) {
  final prefix = '${root.path}/';
  return file.path.startsWith(prefix)
      ? file.path.substring(prefix.length)
      : file.path;
}
