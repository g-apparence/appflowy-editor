# Plugins & Extensions

## Plugin Architecture

Plugins live in `lib/src/plugins/` and follow the **Codec pattern**: `Codec<Document, String>` with separate encoder and decoder.

Exports from `lib/src/plugins/plugins.dart`:
- Markdown (bidirectional)
- HTML (bidirectional)
- Quill Delta (encoder only)

## Markdown Plugin
**File**: `lib/src/plugins/markdown/document_markdown.dart`

```dart
// Document → Markdown
final md = documentToMarkdown(document, customParsers: [...]);

// Markdown → Document
final doc = markdownToDocument(markdown, customParsers: [...]);
```

### Decoder (Markdown → Document)
**Class**: `DocumentMarkdownDecoder`

Flow: Markdown string → `markdown` package parses to HTML AST → parsers convert to Nodes.

**Built-in parsers** (in `lib/src/plugins/markdown/decoder/parser/`):
| Parser | Handles |
|--------|---------|
| `MarkdownParagraphParserV2` | `<p>` → paragraph nodes (splits on `<br>`, extracts `<img>`) |
| `MarkdownHeadingParserV2` | `<h1>`-`<h6>` → heading nodes with level attribute |
| `MarkdownUnorderedListParserV2` | `<ul><li>` → bulleted_list nodes |
| `MarkdownOrderedListParserV2` | `<ol><li>` → numbered_list nodes |
| `MarkdownTodoListParserV2` | `- [ ]` / `- [x]` → todo_list nodes |
| `MarkdownBlockQuoteParserV2` | `<blockquote>` → quote nodes |
| `MarkdownTableListParserV2` | `<table>` → table/table_cell nodes |
| `MarkdownDividerParserV2` | `---` / `***` / `___` → divider nodes |
| `MarkdownImageParserV2` | `![alt](url)` → image nodes |

**DeltaMarkdownDecoder**: Converts inline HTML (`<strong>`, `<em>`, `<code>`, `<a>`, etc.) to Delta attributes (bold, italic, code, href...).

### Encoder (Document → Markdown)
**Class**: `DocumentMarkdownEncoder`

Uses `NodeParser` implementations per node type:
`TextNodeParser`, `HeadingNodeParser`, `BulletedListNodeParser`, `NumberedListNodeParser`, `TodoListNodeParser`, `QuoteNodeParser`, `CodeBlockNodeParser`, `ImageNodeParser`, `TableNodeParser`, `DividerNodeParser`

**DeltaMarkdownEncoder**: Converts Delta attributes back to markdown inline syntax (`**bold**`, `*italic*`, `` `code` ``, `[text](url)`).

### Custom Parsers
Both encoder and decoder accept `customParsers` to handle custom node types.

## HTML Plugin
**File**: `lib/src/plugins/html/`

Bidirectional HTML ↔ Document conversion. Supports tables, lists, formatting, images, nested structures.

```dart
final html = documentToHTML(document);
final doc = htmlToDocument(html);
```

## Quill Delta Plugin
**File**: `lib/src/plugins/quill_delta/quill_delta_encoder.dart`

Converts Quill Delta format → AppFlowy Document. Maps Quill attributes (bold, italic, list, header, indent, blockquote) to AppFlowy node types and attributes.

## Toolbar System

### Desktop: FloatingToolbar
**File**: `lib/src/editor/toolbar/desktop/floating_toolbar.dart`

- Appears above selected text when selection is **not collapsed**
- Rendered as an **overlay** positioned relative to selection rectangles
- Uses 200ms debounce to avoid flicker during selection changes
- Auto-dismisses on: collapsed selection, block selection, or `selectionExtraInfoDisableToolbar`

**Built-in toolbar items** (`lib/src/editor/toolbar/desktop/items/`):
Format (bold/italic/underline/strikethrough/code), heading, list, alignment, color, link, quote, divider.

### Mobile: MobileToolbarV2
**File**: `lib/src/editor/toolbar/mobile/mobile_toolbar_v2.dart`

- Renders **above the keyboard**
- Observes keyboard height via `KeyboardHeightObserver`
- Grid-based layout of toolbar items
- Auto-hides when keyboard dismisses

**Built-in mobile items** (`lib/src/editor/toolbar/mobile/toolbar_items/`):
Blocks, text decoration, code, color, link, list, heading, quote, divider, todo list.

### Custom Toolbar Items
Desktop items implement `ToolbarItem`. Mobile items use `MobileToolbarItem`. Both are passed as lists to the toolbar widget.

## Adding New Block Types

1. **Define a node type string** (e.g. `'my_block'`)
2. **Create a `BlockComponentBuilder`** implementing `build()`, `validate()`, optionally `showActions()`
3. **Register it** in the `blockComponentBuilders` map passed to `AppFlowyEditor`
4. **Add markdown support** (optional): create a decoder parser + encoder NodeParser
5. **Add toolbar item** (optional): create ToolbarItem / MobileToolbarItem

## Adding New Shortcuts

**Command shortcut** (key combo):
```dart
CommandShortcutEvent(
  key: 'my_shortcut',
  command: 'ctrl+shift+k',
  macOSCommand: 'cmd+shift+k',
  handler: (editorState) {
    // Create transaction, apply changes
    return KeyEventResult.handled;
  },
)
```
Add to `commandShortcutEvents` list in `AppFlowyEditor`.

**Character shortcut** (auto-format on typing):
```dart
CharacterShortcutEvent(
  key: 'my_format',
  character: '~',
  handler: (editorState) async {
    // Check context, apply formatting
    return true; // handled
  },
)
```
Add to `characterShortcutEvents` list in `AppFlowyEditor`.
