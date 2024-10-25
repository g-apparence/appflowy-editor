import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:markdown/markdown.dart' as md;

class MarkdownImageParserV2 extends CustomMarkdownParser {
  const MarkdownImageParserV2();

  @override
  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  }) {
    if (element is! md.Element) {
      return [];
    }
    List<Node> results = [];
    final imgNode = tranformElement(element);
    if(imgNode != null) {
      results.add(imgNode);
    }
    for (final child in element.children!) {
      final node = tranformElement(child);
      if(node != null) {
        results.add(node);
      }
    }
    return results;
  }

  Node? tranformElement(md.Node element) {
    if (element is! md.Element) {
      return null;
    }
    if (element.tag != 'img' || element.attributes['src'] == null) {
      return null;
    }
    // temporary for firebase images
    final url = element.attributes['src']!.replaceFirstMapped(
      RegExp('(/o/)(.*)'),
      (match) => '${match[1]}${match[2]?.replaceAll('/', '%2F')}',
    );
    return imageNode(url: url);
  }
}
