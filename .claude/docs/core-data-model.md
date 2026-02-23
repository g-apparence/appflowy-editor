# Core Data Model

## Document
**File**: `lib/src/core/document/document.dart`

Container for the entire document tree. Has a single `root` node (type `'page'`).

```dart
final document = Document.blank(withInitialText: true);
final document = Document.fromJson(jsonMap);

document.root;                    // Root Node
document.nodeAtPath([0, 2]);     // Node at specific path
document.first;                   // First child of root
document.isEmpty;                 // No children in root
document.toJson();                // Serialize
```

Direct mutation methods exist (`insert`, `delete`, `update`, `updateText`) but should always go through **EditorState.apply(Transaction)** instead.

## Node
**File**: `lib/src/core/document/node.dart`

A tree node representing a block in the document. Extends `ChangeNotifier`.

```dart
node.type          // 'paragraph', 'heading', 'bulleted_list', 'image', ...
node.id            // Unique 6-char nano ID
node.parent        // Parent Node (null for root)
node.children      // List<Node> children
node.attributes    // Map<String, dynamic> metadata
node.delta         // Delta? text content (shorthand for attributes['delta'])
node.path          // List<int> computed path from root (e.g. [0, 2, 1])
```

**Tree operations**: `insert()`, `insertAfter()`, `insertBefore()`, `unlink()`
**Serialization**: `toJson()`, `Node.fromJson()`
**Reactivity**: `notify()` triggers `ChangeNotifier` listeners → UI rebuild

### Example Node JSON
```json
{
  "type": "paragraph",
  "attributes": {
    "delta": [
      { "insert": "Hello " },
      { "insert": "world", "attributes": { "bold": true } }
    ]
  },
  "children": []
}
```

## Delta (Text Content)
**File**: `lib/src/core/document/text_delta.dart`

Rich text representation using 3 operation types (Quill Delta format):

| Operation | Purpose | Example |
|-----------|---------|---------|
| `TextInsert(text, attributes?)` | Add text with optional formatting | `{"insert": "Hello", "attributes": {"bold": true}}` |
| `TextRetain(length, attributes?)` | Keep N chars, optionally restyle | `{"retain": 5, "attributes": {"italic": true}}` |
| `TextDelete(length)` | Remove N characters | `{"delete": 3}` |

**Key Delta methods**:
```dart
delta.toPlainText()                    // Strip formatting
delta.compose(other)                   // Apply another delta on top
delta.diff(other)                      // Find differences
delta.invert(base)                     // Create inverse (for undo)
delta.slice(start, end)                // Extract range
delta.sliceAttributes(index)           // Get attributes at offset
```

## Attributes
**File**: `lib/src/core/document/attributes.dart`

Just a `typedef Attributes = Map<String, dynamic>`. Used for both node metadata and text formatting.

**Common text attributes** (defined in `AppFlowyRichTextKeys`):
`bold`, `italic`, `underline`, `strikethrough`, `code`, `href`, `backgroundColor`, `textColor`, `fontFamily`, `fontSize`

**Common node attributes**:
`delta` (text content), `level` (heading level), `url` (image src), `checked` (todo state), `textDirection`, `align`

Helpers: `composeAttributes()`, `invertAttributes()`, `diffAttributes()`, `isAttributesEqual()`

## Path
**File**: `lib/src/core/document/path.dart`

`typedef Path = List<int>` — index-based address of a node from root.

```
Root (page)
  ├─ [0] paragraph "Hello"
  ├─ [1] heading "Title"
  └─ [2] bulleted_list
      ├─ [2, 0] list item A
      └─ [2, 1] list item B
```

Extensions: `path.next`, `path.previous`, `path.parent`, `path.child(i)`, `path > otherPath`, `path.isAncestorOf(other)`

## Position
**File**: `lib/src/core/location/position.dart`

Pinpoints a cursor location: **which node** (path) + **which character** (offset).

```dart
Position(path: [0], offset: 5)   // 5th character in first paragraph
Position.invalid()                // Sentinel value (path: [-1])
```

## Selection
**File**: `lib/src/core/location/selection.dart`

A range between two positions.

```dart
selection.start / .end        // Position endpoints
selection.isCollapsed         // Cursor (start == end)
selection.isSingle            // Both positions in same node
selection.isForward           // End is before start (backward drag)
selection.normalized          // Always start <= end
selection.startIndex          // Normalized start offset
selection.endIndex            // Normalized end offset
selection.collapse()          // Collapse to cursor
```

## Relationships

```
Document ──has──→ root: Node (type 'page')
                    │
Node ──has──→ children: [Node]
  │──has──→ attributes: Attributes (Map)
  │──has──→ delta: Delta? (from attributes['delta'])
  │──computed──→ path: Path (List<int>)
  │
Delta ──contains──→ [TextInsert, TextRetain, TextDelete]
  │
Position ──references──→ path: Path + offset: int
  │
Selection ──contains──→ start: Position + end: Position
```
