import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('document_markdown.dart tests', () {
    test('markdownToDocument()', () {
      final document = markdownToDocument(markdownDocument);
      final data = Map<String, Object>.from(json.decode(testDocument));

      expect(document.toJson(), data);
    });

    test('soft line break with two spaces', () {
      const markdown = 'first line  \nsecond line';
      final document = markdownToDocument(markdown);
      expect(document.root.children.length, 2);
      expect(document.root.children[0].delta?.toPlainText(), 'first line');
      expect(document.root.children[1].delta?.toPlainText(), 'second line');
    });

    test('documentToMarkdown()', () {
      final document = markdownToDocument(markdownDocument);
      final markdown = documentToMarkdown(document);

      expect(markdown, markdownDocumentEncoded);
    });

    test('complete markdown with children', () {
      const markdown = '''
first line
second line

textavantimage
![](https://example.com/image.png)
text after image
      ''';
      final document = markdownToDocument(markdown);
      // expect(document.root.children[0].type, ParagraphBlockKeys.type);s
      // expect(document.root.children[2].type, ImageBlockKeys.type);
      final str = documentToMarkdown(document);
      expect(str, markdown);
      // expect(document.root.children[0].delta?.toPlainText(), 'first line');
      // expect(document.root.children[1].delta?.toPlainText(), 'second line');
    });
  });

  test('doc to markdown with children', () {
      var doc = Document(root: paragraphNode());
      doc.root.insert(paragraphNode(text: 'first line'));
      doc.root.insert(paragraphNode(text: 'second line'));
      doc.root.insert(paragraphNode(text: ''));
      doc.root.insert(paragraphNode(text: 'textavantimage'));
      doc.root.insert(imageNode(url: 'https://example.com/image.png'));
      doc.root.insert(paragraphNode(text: ''));
      doc.root.insert(paragraphNode(text: 'text after image'));
      final markdown = documentToMarkdown(doc);
      print(markdown);
      // final document = markdownToDocument(markdown);
      // expect(document.root.children[0].type, ParagraphBlockKeys.type);s
      // expect(document.root.children[2].type, ImageBlockKeys.type);
      // final str = documentToMarkdown(document);
      // expect(str, markdown);
      // expect(document.root.children[0].delta?.toPlainText(), 'first line');
      // expect(document.root.children[1].delta?.toPlainText(), 'second line');
    });
}

const testDocument = '''{
  "document": {
    "type": "page",
    "children": [
      {
        "type": "heading",
        "data": {"level": 1, "delta": [{"insert": "Heading 1"}]}
      },
      {
        "type": "heading",
        "data": {"level": 2, "delta": [{"insert": "Heading 2"}]}
      },
      {
        "type": "heading",
        "data": {"level": 3, "delta": [{"insert": "Heading 3"}]}
      },
      {"type": "divider"}
    ]
  }
}''';

const markdownDocument = """
# Heading 1
## Heading 2
### Heading 3
---""";

const markdownDocumentEncoded = """
# Heading 1
## Heading 2
### Heading 3
---
""";
