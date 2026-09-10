import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Enables a part of the String `text` to be differently styled.
///
/// Set [highlightedSemanticsId] together with [onHighlightedTap] to expose the
/// highlighted substring as its own tappable Semantics node (with the given
/// `identifier`). This is what Maestro's `tapOn: id:` matches against on iOS,
/// where a plain `RichText`+`TapGestureRecognizer` collapses into a single
/// `StaticText` accessibility node and is therefore not targetable by id.
/// When the parameter is omitted the original `RichText`+`TextSpan`+
/// `TapGestureRecognizer` rendering is preserved for backward compatibility.
class TextSubstringHighlighting extends StatelessWidget {
  final String text;
  final String highlightedText;
  final TextStyle? style;
  final TextStyle? highlightedStyle;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final VoidCallback? onHighlightedTap;
  final String? highlightedSemanticsId;

  const TextSubstringHighlighting({
    super.key,
    required this.text,
    required this.highlightedText,
    this.style,
    this.highlightedStyle,
    this.textAlign = .start,
    this.maxLines,
    this.overflow = .visible,
    this.onHighlightedTap,
    this.highlightedSemanticsId,
  });

  @override
  Widget build(BuildContext context) {
    // RichText does not inherit DefaultTextStyle, so merge the caller's style
    // onto it: keeps the app font family (and other inherited attributes) for
    // every caller that only overrides size or colour.
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final effectiveHighlightedStyle =
        highlightedStyle ?? effectiveStyle.copyWith(fontWeight: .bold);

    final startIndex = text.indexOf(highlightedText);

    // just return plain text if substring not found.
    if (startIndex == -1) {
      return Text(
        text,
        style: effectiveStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final before = text.substring(0, startIndex);
    final after = text.substring(startIndex + highlightedText.length);

    // Opt-in path: expose the highlighted substring as its own Semantics
    // node so Maestro can target it via `tapOn: id:`. We render the tappable
    // chunk through a WidgetSpan so it stays inline with the surrounding
    // copy and word-wrapping behaviour is preserved.
    final useSemanticsTap = highlightedSemanticsId != null && onHighlightedTap != null;

    return RichText(
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(
        style: effectiveStyle,
        children: [
          TextSpan(text: before),
          if (useSemanticsTap)
            WidgetSpan(
              alignment: .baseline,
              baseline: .alphabetic,
              child: Semantics(
                identifier: highlightedSemanticsId,
                button: true,
                child: GestureDetector(
                  behavior: .opaque,
                  onTap: onHighlightedTap,
                  child: Text(
                    highlightedText,
                    style: effectiveHighlightedStyle,
                  ),
                ),
              ),
            )
          else
            TextSpan(
              text: highlightedText,
              style: effectiveHighlightedStyle,
              recognizer: onHighlightedTap != null
                  ? (TapGestureRecognizer()..onTap = onHighlightedTap)
                  : null,
            ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}
