import 'package:flutter/widgets.dart';

/// Splits [text] into spans, wrapping every case-insensitive occurrence of
/// [query] in [highlightStyle] and the rest in [baseStyle]. Used to make the
/// part of a search result that matched the query stand out.
///
/// Returns a single [baseStyle] span when [query] (trimmed) is empty or does
/// not appear in [text]. The original casing of [text] is preserved — only the
/// comparison is lower-cased.
List<TextSpan> highlightSpans(
  String text,
  String query, {
  required TextStyle baseStyle,
  required TextStyle highlightStyle,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final haystack = text.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;

  while (true) {
    final match = haystack.indexOf(needle, start);
    if (match < 0) {
      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      }
      break;
    }
    if (match > start) {
      spans.add(TextSpan(text: text.substring(start, match), style: baseStyle));
    }
    final end = match + needle.length;
    spans.add(TextSpan(text: text.substring(match, end), style: highlightStyle));
    start = end;
  }

  return spans;
}
