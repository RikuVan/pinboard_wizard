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
/// lines skipped. In unquoted values an inline `#` preceded by whitespace
/// starts a comment (dotenv convention); quoted values keep `#` intact.
/// Anything else is counted as ignored, never an error.
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

      var value = match.group(2)!.trim();
      if (!_isQuoteWrapped(value)) {
        value = _stripInlineComment(value);
      }
      variables[match.group(1)!] = _unquote(value);
    }

    return ParsedEnvFile(variables: variables, ignoredLines: ignored);
  }

  bool _isQuoteWrapped(String value) {
    if (value.length < 2) {
      return false;
    }
    final first = value[0];
    final last = value[value.length - 1];
    return (first == '"' && last == '"') || (first == "'" && last == "'");
  }

  String _unquote(String value) =>
      _isQuoteWrapped(value) ? value.substring(1, value.length - 1) : value;

  /// Cuts an unquoted value at the first `#` that starts the value or
  /// follows whitespace: `abc # comment` → `abc`, `# comment` → empty,
  /// but `abc#def` is kept whole.
  String _stripInlineComment(String value) {
    for (var i = 0; i < value.length; i++) {
      if (value[i] != '#') {
        continue;
      }
      if (i == 0 || value[i - 1] == ' ' || value[i - 1] == '\t') {
        return value.substring(0, i).trimRight();
      }
    }
    return value;
  }
}
