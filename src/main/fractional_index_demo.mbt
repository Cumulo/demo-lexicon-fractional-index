///|
using @css {respo_style}

///|

///|

///|

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
  dispatch : DispatchFn[ActionOp],
) -> RespoNode[ActionOp] {
  let cursor = states.path()
  let state = (states.cast_branch() : FractionalDemoState)
  let local_dispatch = dispatch

  // Initialize with some demo items if empty
  let items = if state.items.is_empty() {
    let initial_items = [
      { id: "item-0", key: "a", content: "First item", x: 50.0, y: 100.0 },
      { id: "item-1", key: "c", content: "Second item", x: 50.0, y: 200.0 },
      { id: "item-2", key: "e", content: "Third item", x: 50.0, y: 300.0 },
    ]
    dispatch(FractionalDemoStatesChange(@respo.RespoUpdateState{
      cursor,
      data: Some(@dom_ffi.js_obscure_to_v(FractionalDemoState::{
        ..state,
        items: initial_items,
      })),
      backup: (FractionalDemoState::{ ..state, items: initial_items }).to_json(),
    }))
    initial_items
  } else {
    state.items
  }
  let on_mouse_down = fn(
    item_id : String,
    e : RespoEvent,
    _dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    if e is MouseEvent(original_event~, ..) {
      original_event.prevent_default()
      // For simplicity, use fixed offset
      dispatch(FractionalDemoStatesChange(@respo.RespoUpdateState{
        cursor,
        data: Some(@dom_ffi.js_obscure_to_v(FractionalDemoState::{
          ..state,
          dragged_item: Some(item_id),
          drag_offset: (20.0, 10.0),
        })),
        backup: (FractionalDemoState::{ ..state, dragged_item: Some(item_id), drag_offset: (20.0, 10.0) }).to_json(),
      }))
    }
  }
  let on_mouse_move = fn(
    e : RespoEvent,
    _dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    if e is MouseEvent(original_event~, ..) {
      if state.dragged_item is Some(item_id) {
        let (offset_x, offset_y) = state.drag_offset
        let new_x = original_event.client_x() - offset_x
        let new_y = original_event.client_y() - offset_y

        // Update item position
        let updated_items = items.map(fn(item) {
          if item.id == item_id {
            { ..item, x: new_x, y: new_y }
          } else {
            item
          }
        })
        dispatch(FractionalDemoStatesChange(@respo.RespoUpdateState{
          cursor,
          data: Some(@dom_ffi.js_obscure_to_v(FractionalDemoState::{
            ..state,
            items: updated_items,
          })),
          backup: (FractionalDemoState::{ ..state, items: updated_items }).to_json(),
        }))
      }
    }
  }
  let on_mouse_up = fn(
    e : RespoEvent,
    _dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    if e is MouseEvent(original_event~, ..) {
      original_event.prevent_default()
      if state.dragged_item is Some(dragged_id) {
        // Find the item being dragged
        let dragged_item = items.find(fn(item) { item.id == dragged_id })
        if dragged_item is Some(item) {
          // Calculate new key based on y position relative to other items
          let sorted_items = items
            .filter(fn(i) { i.id != dragged_id })
            .sort_by(fn(a, b) { a.y.compare(b.y) })

          // Find position in sorted order
          let mut insert_index = 0
          for i = 0; i < sorted_items.length(); i = i + 1 {
            if item.y < sorted_items[i].y {
              break
            }
            insert_index = i + 1
          }

          // Generate new fractional index
          let new_key = generate_fractional_index(sorted_items, insert_index)

          // Update the dragged item with new key
          let updated_items = items.map(fn(i) {
            if i.id == dragged_id {
              { ..i, key: new_key }
            } else {
              i
            }
          })

          // Sort items by key
          let final_items = updated_items.sort_by(fn(a, b) {
            a.key.compare(b.key)
          })
          dispatch(FractionalDemoStatesChange(@respo.RespoUpdateState{
            cursor,
            data: Some(@dom_ffi.js_obscure_to_v(FractionalDemoState::{
              ..state,
              items: final_items,
              dragged_item: None,
            })),
            backup: (FractionalDemoState::{ ..state, items: final_items, dragged_item: None }).to_json(),
          }))
        }
      }
    }
  }
  let on_add_item = fn(
    e : RespoEvent,
    _dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    if e is Click(original_event~, ..) {
      original_event.prevent_default()
      let new_id = "item-\{state.next_id}"
      let new_content = "Item \{state.next_id + 1}"

      // Generate key for new item (insert at end)
      let sorted_items = items.sort_by(fn(a, b) { a.key.compare(b.key) })
      let new_key = generate_fractional_index(
        sorted_items,
        sorted_items.length(),
      )
      let new_item = {
        id: new_id,
        key: new_key,
        content: new_content,
        x: 50.0,
        y: (state.next_id * 80 + 100).to_double(),
      }
      let updated_items = items + [new_item]
      dispatch(FractionalDemoStatesChange(@respo.RespoUpdateState{
        cursor,
        data: Some(@dom_ffi.js_obscure_to_v(FractionalDemoState::{
          ..state,
          items: updated_items,
          next_id: state.next_id + 1,
        })),
        backup: (FractionalDemoState::{ ..state, items: updated_items, next_id: state.next_id + 1 }).to_json(),
      }))
    }
  }
  let on_reset = fn(
    e : RespoEvent,
    _dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    if e is Click(original_event~, ..) {
      original_event.prevent_default()
      let initial_items = [
        { id: "item-0", key: "a", content: "First item", x: 50.0, y: 100.0 },
        { id: "item-1", key: "c", content: "Second item", x: 50.0, y: 200.0 },
        { id: "item-2", key: "e", content: "Third item", x: 50.0, y: 300.0 },
      ]
      dispatch(FractionalDemoStatesChange(@respo.RespoUpdateState{
        cursor,
        data: Some(@dom_ffi.js_obscure_to_v(FractionalDemoState::{
          items: initial_items,
          dragged_item: None,
          drag_offset: (0.0, 0.0),
          next_id: 3,
        })),
        backup: (FractionalDemoState::{ items: initial_items, dragged_item: None, drag_offset: (0.0, 0.0), next_id: 3, }).to_json(),
      }))
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
          [
            // Individual items will be rendered here
          ]
        ),
      ],
    ),
  ])
}

///|
fn generate_fractional_index(
  items : Array[FractionalItem],
  insert_index : Int,
) -> String raise @respo_node.RespoCommonError {
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
      // If same length, try to increment last character
      if before.length() == 0 {
        raise @respo_node.RespoCommonError("Empty key in fractional indexing")
      }
      // Simple approach for middle insertion - just append a character to make it unique
      before + "x"
    }
  }
}
