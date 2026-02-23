# Editor Services

## EditorState — Central Hub
**File**: `lib/src/editor_state.dart`

Owns the document, selection, services, undo manager, and transaction stream.

```dart
final editorState = EditorState(document: document);

editorState.document              // The Document
editorState.selection             // Current Selection? (via selectionNotifier)
editorState.editable              // Whether editing is enabled
editorState.toggledStyle          // Pending format state (e.g. bold toggled but not yet typed)
editorState.undoManager           // UndoManager instance
editorState.transactionStream     // Stream<(TransactionTime, Transaction)>
editorState.service               // EditorService (selection, keyboard, scroll, renderer)
```

### Applying Changes
```dart
final t = editorState.transaction;
t.insertText(node, 0, 'Hello', attributes: {'bold': true});
t.afterSelection = Selection.collapsed(Position(path: [0], offset: 5));
await editorState.apply(t);
```

`apply()` does: broadcast before → apply ops to document → broadcast after → record undo → update selection.

Options: `isRemote` (skip undo, adjust selection), `ApplyOptions(recordUndo, recordRedo)`, `withUpdateSelection`, `skipHistoryDebounce`.

## Transaction System
**File**: `lib/src/core/transform/transaction.dart`, `operation.dart`

### 4 Operation Types
| Type | Fields | Inverse |
|------|--------|---------|
| `InsertOperation` | path, nodes | DeleteOperation |
| `DeleteOperation` | path, nodes | InsertOperation |
| `UpdateOperation` | path, attributes, oldAttributes | UpdateOperation (swapped) |
| `UpdateTextOperation` | path, delta, inverted | UpdateTextOperation (swapped) |

### Transaction Builder
```dart
final t = editorState.transaction;
t.insertNode([0], paragraphNode);        // Insert node
t.deleteNode(node);                       // Delete node
t.updateNode(node, {'level': 2});        // Update attributes
t.insertText(node, 0, 'text');           // Insert text at offset
t.deleteText(node, 0, 5);               // Delete 5 chars at offset 0
t.formatText(node, 0, 5, {'bold': true}); // Bold first 5 chars
t.replaceText(node, 0, 5, 'new');        // Replace text range
t.mergeText(nodeA, nodeB);               // Merge two text nodes
```

**Auto-composition**: Consecutive `UpdateTextOperation`s on the same path are automatically composed into a single operation.
**Path transformation**: Operations auto-transform paths to avoid conflicts with prior operations in the same transaction.

## Services

### EditorService
**File**: `lib/src/editor/editor_component/service/editor_service.dart`

Service locator accessed via `editorState.service`:
- `selectionService` → `AppFlowySelectionService`
- `keyboardService` → `AppFlowyKeyboardService`
- `scrollService` → `AppFlowyScrollService`
- `rendererService` → `BlockComponentRendererService`

### Keyboard Service
**File**: `lib/src/editor/editor_component/service/keyboard_service.dart`

Handles hardware keyboard events. Supports **interceptors** (`AppFlowyKeyboardServiceInterceptor`) for:
- `interceptInsert()`, `interceptDelete()`, `interceptReplace()` — text edits
- `interceptNonTextUpdate()` — cursor movements
- `interceptPerformAction()` — Enter, Tab actions
- `interceptFloatingCursor()` — mobile drag cursor

### Selection Service
**File**: `lib/src/editor/editor_component/service/selection_service.dart`

Manages cursor and selection state:
- `updateSelection()`, `clearSelection()`, `clearCursor()`
- `currentSelectedNodes` — ordered list of selected nodes
- `getNodeInOffset()`, `getPositionInOffset()` — hit testing (global coords → node/position)
- Gesture interceptors for tap, double-tap, pan, drag-and-drop

### Scroll Service
**File**: `lib/src/editor/editor_component/service/scroll_service.dart`

Scroll control: `scrollTo(dy)`, `jumpTo(index)`, `jumpToTop()`, `jumpToBottom()`, `goBallistic(velocity)`.

### Text Input Service (IME)
**File**: `lib/src/editor/editor_component/service/ime/delta_input_service.dart`

Processes OS-level text input as `TextEditingDelta` objects:
- `TextEditingDeltaInsertion` → `onInsert()`
- `TextEditingDeltaDeletion` → `onDelete()`
- `TextEditingDeltaReplacement` → `onReplace()`
- `TextEditingDeltaNonTextUpdate` → `onNonTextUpdate()`

Handles IME composition (e.g. CJK input) via `composingTextRange`.

## Shortcut System

### CommandShortcutEvent (keyboard combos)
**File**: `lib/src/editor/editor_component/service/shortcuts/command_shortcut_event.dart`

Synchronous handlers triggered by key combos. Platform-specific bindings.

```dart
CommandShortcutEvent(
  key: 'undo',
  command: 'ctrl+z',          // Windows/Linux
  macOSCommand: 'cmd+z',      // macOS
  handler: (editorState) { ... return KeyEventResult.handled; },
)
```

Built-in commands (~28): backspace, delete, arrow keys, home/end, page up/down, copy/cut/paste, undo/redo, select all, find/replace, markdown formatting triggers.

Location: `lib/src/editor/editor_component/service/shortcuts/command/`

### CharacterShortcutEvent (auto-format on typing)
**File**: `lib/src/editor/editor_component/service/shortcuts/character_shortcut_event.dart`

Async handlers triggered by single character input. Used for markdown auto-formatting:
- `**text**` → bold, `*text*` → italic, `~~text~~` → strikethrough
- `` `text` `` → code, `[text](url)` → link
- `/` → slash command menu

Location: `lib/src/editor/editor_component/service/shortcuts/character/`

## Undo/Redo
**File**: `lib/src/history/undo_manager.dart`

```dart
await editorState.undoManager.undo();
await editorState.undoManager.redo();
```

- **HistoryItem**: Groups operations + before/after selection. Sealed after `minHistoryItemDuration` (200ms) to group rapid edits.
- **FixedSizeStack**: Max 20 items (FIFO eviction).
- **Undo**: Pops item, inverts all operations in reverse order, applies as transaction (recorded in redo stack).
- **Redo**: Same in reverse direction.

Keybindings: `ctrl+z / cmd+z` (undo), `ctrl+y or ctrl+shift+z / cmd+shift+z` (redo).

## Block Component Rendering
**File**: `lib/src/editor/editor_component/service/renderer/block_component_service.dart`

Registry pattern mapping `node.type` → `BlockComponentBuilder`:

```dart
final builders = {
  'paragraph': ParagraphBlockComponentBuilder(),
  'heading': HeadingBlockComponentBuilder(),
  'bulleted_list': BulletedListBlockComponentBuilder(),
  'numbered_list': NumberedListBlockComponentBuilder(),
  'todo_list': TodoListBlockComponentBuilder(),
  'quote': QuoteBlockComponentBuilder(),
  'divider': DividerBlockComponentBuilder(),
  'image': ImageBlockComponentBuilder(),
  'table': TableBlockComponentBuilder(),
};
```

Each builder implements:
- `build(BlockComponentContext)` → returns the widget
- `validate(Node)` → checks if node is renderable
- `showActions(Node)` → whether to show action buttons
- `configuration` → padding, alignment, text direction defaults

**BlockComponentContainer** wraps each block with `ChangeNotifierProvider<Node>` for automatic rebuild on node changes.

**AppFlowyRichText** (`lib/src/editor/block_component/rich_text/appflowy_rich_text.dart`):
Converts `node.delta` → `TextSpan` tree → Flutter `RichText`. Handles selection rectangles, cursor positioning, and hit testing via `SelectableMixin`.
