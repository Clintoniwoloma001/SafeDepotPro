// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

/// Minimal CSV reader for Base44 exports.
///
/// The exports are quote-delimited with a header row. Values are trimmed and a
/// leading UTF-8 BOM is dropped, because a BOM silently corrupts the first
/// column name otherwise.
library;

import 'dart:convert';
import 'dart:io';

class CsvReader {
  static List<Map<String, String>> read(File file) {
    final raw = file.readAsStringSync();
    final text = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
    final lines = const LineSplitter()
        .convert(text)
        .where((l) => l.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return const [];

    final header = _split(lines.first);
    return [
      for (final line in lines.skip(1))
        () {
          final cells = _split(line);
          return <String, String>{
            for (var i = 0; i < header.length; i++)
              if (i < cells.length) header[i]: cells[i],
          };
        }(),
    ];
  }

  /// Splits one CSV row, honouring double quotes and doubled quotes.
  static List<String> _split(String line) {
    final out = <String>[];
    var buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        out.add(buffer.toString().trim());
        buffer = StringBuffer();
      } else {
        buffer.write(ch);
      }
    }
    out.add(buffer.toString().trim());
    return out;
  }
}
