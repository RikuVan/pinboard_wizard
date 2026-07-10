import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/env_import/env_file_parser.dart';

void main() {
  final parser = EnvFileParser();

  test('parses simple KEY=VALUE lines', () {
    final result = parser.parse('PINBOARD_API_TOKEN=user:abc123\n');
    expect(result.variables, {'PINBOARD_API_TOKEN': 'user:abc123'});
    expect(result.ignoredLines, 0);
  });

  test('strips export prefix', () {
    final result = parser.parse('export OPENAI_API_KEY=sk-123');
    expect(result.variables, {'OPENAI_API_KEY': 'sk-123'});
  });

  test('strips matching single and double quotes', () {
    final result = parser.parse(
      'A="double quoted"\nB=\'single quoted\'\nC="unbalanced\'',
    );
    expect(result.variables['A'], 'double quoted');
    expect(result.variables['B'], 'single quoted');
    expect(result.variables['C'], '"unbalanced\''); // mismatched quotes kept
  });

  test('skips blank lines and comments without counting them as ignored', () {
    final result = parser.parse('\n# a comment\n\nKEY=value\n');
    expect(result.variables, {'KEY': 'value'});
    expect(result.ignoredLines, 0);
  });

  test('counts unparseable lines as ignored', () {
    final result = parser.parse('not a var line\nKEY=value\n:::\n');
    expect(result.variables, {'KEY': 'value'});
    expect(result.ignoredLines, 2);
  });

  test('tolerates CRLF line endings', () {
    final result = parser.parse('A=1\r\nB=2\r\n');
    expect(result.variables, {'A': '1', 'B': '2'});
  });

  test('later duplicate keys win', () {
    final result = parser.parse('A=first\nA=second\n');
    expect(result.variables['A'], 'second');
  });

  test('keeps = signs inside values', () {
    final result = parser.parse('TOKEN=abc=def==');
    expect(result.variables['TOKEN'], 'abc=def==');
  });

  test('trims whitespace around key and value', () {
    final result = parser.parse('  KEY  =  value  ');
    expect(result.variables, {'KEY': 'value'});
  });
}
