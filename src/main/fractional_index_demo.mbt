///|
// Using @lexicon_fractional_index - module not available, implementing basic fractional indexing

///|
struct FractionalItem {
  id : String
  key : String
  content : String
  x : Double
  y : Double
} derive(ToJson, @json.FromJson)

///|
struct FractionalDemoState {
  items : Array[FractionalItem]
  dragged_item : String?
  drag_offset : (Double, Double)
  next_id : Int
} derive(Default, ToJson, @json.FromJson)

///|
fn comp_fractional_index_demo(
  states : @respo.RespoStatesTree,
) -> RespoNode[ActionOp] raise @respo_node.RespoCommonError {
  let cursor : @respo_node.RespoCursor[FractionalDemoState] = states.path()
  let state : FractionalDemoState = states.cast_branch()

  // Use items from state, or initialize with defaults
  let items = if state.items.is_empty() {
    // Items will be initialized on first interaction
    [
      { id: "item-0", key: "a", content: "First item", x: 50.0, y: 100.0 },
      { id: "item-1", key: "c", content: "Second item", x: 50.0, y: 200.0 },
      { id: "item-2", key: "e", content: "Third item", x: 50.0, y: 300.0 },
    ]
  } else {
    state.items
  }
  let on_add_item = fn(
    e : RespoEvent,
    dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    if e is Click(original_event~, ..) {
      original_event.prevent_default()
      // Get current items from state, or use defaults
      let current_items = if state.items.is_empty() {
        [
          { id: "item-0", key: "a", content: "First item", x: 50.0, y: 100.0 },
          { id: "item-1", key: "c", content: "Second item", x: 50.0, y: 200.0 },
          { id: "item-2", key: "e", content: "Third item", x: 50.0, y: 300.0 },
        ]
      } else {
        state.items
      }
      let current_next_id = if state.items.is_empty() { 3 } else { state.next_id }
      let new_id = "item-\{current_next_id}"
      let new_content = "Item \{current_next_id + 1}"

      // Generate key for new item (insert at end)
      let sorted_items = current_items.copy()
      sorted_items.sort_by(fn(a, b) { a.key.compare(b.key) })
      let new_key = generate_fractional_index(
        sorted_items,
        sorted_items.length(),
      )
      let new_item : FractionalItem = {
        id: new_id,
        key: new_key,
        content: new_content,
        x: 50.0,
        y: (current_next_id * 80 + 100).to_double(),
      }
      let updated_items = current_items + [new_item]
      let next_state = FractionalDemoState::{
        items: updated_items,
        dragged_item: None,
        drag_offset: (0.0, 0.0),
        next_id: current_next_id + 1,
      }
      dispatch.set_state(cursor, next_state)
    }
  }
  let on_reset = fn(
    e : RespoEvent,
    dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    if e is Click(original_event~, ..) {
      original_event.prevent_default()
      let initial_items : Array[FractionalItem] = [
        { id: "item-0", key: "a", content: "First item", x: 50.0, y: 100.0 },
        { id: "item-1", key: "c", content: "Second item", x: 50.0, y: 200.0 },
        { id: "item-2", key: "e", content: "Third item", x: 50.0, y: 300.0 },
      ]
      let next_state = FractionalDemoState::{
        items: initial_items,
        dragged_item: None,
        drag_offset: (0.0, 0.0),
        next_id: 3,
      }
      dispatch.set_state(cursor, next_state)
    }
  }
  div([
    div([
      button(
        inner_text="Add Item",
        class_name=@respo.ui_button,
        style=respo_style(margin=4 |> Px),
        on_click=on_add_item,
      ),
      button(
        inner_text="Reset",
        class_name=@respo.ui_button,
        style=respo_style(margin=4 |> Px),
        on_click=on_reset,
      ),
    ]),
    div(
      style=respo_style(
        position=Relative,
        height=600 |> Px,
        border_color=Hsluv(0, 0, 80),
        background_color=Hsluv(0, 0, 98),
      ),
      [
        div([
          "Drag items to reorder them. Keys are generated using lexicographic fractional indexing."
          |> text_node,
          @respo_node.br(),
          "Current order (by key):" |> text_node,
        ]),
        div(
          style=respo_style(margin_top=20 |> Px),
          items.map(fn(item) {
            div(
              style=respo_style(
                padding=10 |> Px,
                margin=5 |> Px,
                background_color=Hsluv(200, 50, 90),
                border_radius=4.0,
              ),
              ["\{item.content} (key: \{item.key})" |> text_node],
            )
          }),
        ),
      ],
    ),
  ])
}

///|
fn generate_fractional_index(
  items : Array[FractionalItem],
  insert_index : Int,
) -> String {
  // Simple fractional index generation
  // This is a basic implementation - in a real app you'd use the lexicon-fractional-index functions
  if insert_index == 0 {
    // Insert at beginning
    if items.is_empty() {
      "a"
    } else {
      "a" + "a" // Simple: just add 'a' prefix
    }
  } else if insert_index >= items.length() {
    // Insert at end
    if items.is_empty() {
      "a"
    } else {
      let last_key = items[items.length() - 1].key
      last_key + "a" // Simple: append 'a' to last key
    }
  } else {
    // Insert in middle
    let before = items[insert_index - 1].key
    let after = items[insert_index].key
    // Simple approach: try to find a key between before and after
    if before.length() < after.length() {
      before + "m" // Use 'm' as middle character
    } else {
      // Simple approach for middle insertion - just append a character to make it unique
      before + "x"
    }
  }
}
