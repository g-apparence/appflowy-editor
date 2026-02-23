# Architecture Overview

## Project Structure

```
lib/
├── appflowy_editor.dart          # Main entry point & public exports
└── src/
    ├── core/                     # Core data model
    │   ├── document/             # Document, Node, Delta, Attributes, Path
    │   ├── location/             # Position, Selection
    │   └── transform/            # Operation, Transaction
    ├── editor_state.dart         # Central state management hub
    ├── editor/                   # UI layer
    │   ├── block_component/      # Built-in block renderers (paragraph, heading, list, image, table...)
    │   ├── command/              # High-level edit commands (selection_commands, text_commands)
    │   ├── editor_component/     # Editor widget + all services
    │   │   ├── entry/            # PageBlockComponent (root renderer)
    │   │   └── service/          # Keyboard, Selection, Scroll, IME, Shortcuts, Renderer
    │   ├── find_replace_menu/    # Find & replace UI
    │   ├── selection_menu/       # Slash command menu
    │   └── toolbar/              # Desktop FloatingToolbar + Mobile MobileToolbarV2
    ├── extensions/               # Extension methods on core types
    ├── history/                  # UndoManager, HistoryItem, FixedSizeStack
    ├── infra/                    # Infrastructure (clipboard, logging, SVG, mobile utils)
    ├── plugins/                  # Markdown, HTML, Quill Delta codecs
    ├── render/                   # SelectableMixin, ToolbarItem base
    ├── service/                  # Keybinding parsing, context menu
    └── flutter/                  # Flutter-specific utilities
```

## 4-Layer Architecture

```
┌─────────────────────────────────────────────────────┐
│  Plugins         Markdown / HTML / Quill codecs     │
│                  Toolbar items                       │
├─────────────────────────────────────────────────────┤
│  Services        Keyboard · Selection · Scroll      │
│                  IME/TextInput · Shortcuts           │
├─────────────────────────────────────────────────────┤
│  Editor          EditorState · BlockComponentBuilder │
│                  AppFlowyRichText · PageBlock        │
├─────────────────────────────────────────────────────┤
│  Core            Document · Node · Delta             │
│                  Path · Position · Selection         │
│                  Operation · Transaction             │
└─────────────────────────────────────────────────────┘
```

## Data Flow: Document → Rendering

```
Document
  └─ root Node (type: 'page')
      ├─ Node (type: 'paragraph')   ──→  ParagraphBlockComponentBuilder  ──→  Widget
      ├─ Node (type: 'heading')     ──→  HeadingBlockComponentBuilder    ──→  Widget
      └─ Node (type: 'bulleted_list') ──→ BulletedListBlockComponentBuilder ──→ Widget
```

1. `AppFlowyEditor` widget receives `EditorState` (which holds `Document`)
2. `PageBlockComponent` iterates root's children
3. For each child, `BlockComponentRendererService.build(context, node)` looks up the registered `BlockComponentBuilder` by `node.type`
4. Builder returns a widget wrapped in `BlockComponentContainer` (provides reactivity via `ChangeNotifierProvider<Node>`)
5. Text nodes use `AppFlowyRichText` which converts `node.delta` into Flutter `RichText` with styled `TextSpan`s

## Edit Flow: User Input → Document Mutation

```
User types / presses key
  ↓
Keyboard Service or IME (DeltaTextInputService)
  ↓
CharacterShortcutEvent or CommandShortcutEvent matched?
  ├─ Yes → handler(editorState) creates Transaction
  └─ No  → default text insertion creates Transaction
  ↓
Transaction contains Operations (Insert/Delete/Update/UpdateText)
  ↓
EditorState.apply(transaction)
  ├─ Broadcast "before" to transactionStream
  ├─ Apply each operation to Document (mutates Node tree)
  ├─ Broadcast "after" to transactionStream
  ├─ Record in UndoManager (with debounce-based history grouping)
  └─ Update selection to transaction.afterSelection
  ↓
Node.notifyListeners() → UI rebuilds affected widgets
```

## Key Entry Points

- **Widget**: `AppFlowyEditor` in `lib/src/editor/editor_component/service/editor.dart`
- **State**: `EditorState` in `lib/src/editor_state.dart`
- **Public API**: Everything exported from `lib/appflowy_editor.dart`
- **Block registration**: Pass `blockComponentBuilders` map to `AppFlowyEditor`
- **Shortcuts**: Pass `commandShortcutEvents` and `characterShortcutEvents` lists
