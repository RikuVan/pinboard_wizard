/// Result of parsing a `.env`-style file.
class ParsedEnvFile {
  /// Variable name → value (quotes stripped). Later duplicates win.
  final Map<String, String> variables;

  /// Number of non-empty, non-comment lines that could not be parsed.
  final int ignoredLines;

  const ParsedEnvFile({required this.variables, required this.ignoredLines});
}

/// Minimal `.env` parser: `KEY=VALUE` lines, optional `export ` prefix,
/// surrounding single/double quotes stripped, `#` comment lines and blank
/// lines skipped. Anything else is counted as ignored, never an error.
class EnvFileParser {
  static final RegExp _linePattern = RegExp(
    r'^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$',
  );

  ParsedEnvFile parse(String contents) {
    final variables = <String, String>{};
    var ignored = 0;

    for (final rawLine in contents.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final match = _linePattern.firstMatch(line);
      if (match == null) {
        ignored++;
        continue;
      }

      variables[match.group(1)!] = _unquote(match.group(2)!.trim());
    }

    return ParsedEnvFile(variables: variables, ignoredLines: ignored);
  }

  String _unquote(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }
}
