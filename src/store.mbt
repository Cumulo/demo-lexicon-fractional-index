///|
struct Store {
  states : @respo.RespoStatesTree
} derive(ToJson, @json.FromJson, Eq)

///|
impl Default for Store with default() -> Store {
  { states: @respo.RespoStatesTree::default() }
}

///|
enum ActionOp {
  StatesChange(@respo.RespoUpdateState)
}

///|
impl @respo_node.RespoAction for ActionOp with build_states_action(cursor, a, j) {
  StatesChange({ cursor, data: a.map(@dom_ffi.js_obscure_to_v), backup: j })
}

///|
impl Show for ActionOp with output(self, logger) -> Unit {
  let s = match self {
    StatesChange(state) =>
      "StatesChange(\{state.cursor} \{state.backup.to_json()})"
  }
  logger.write_string(s)
}

///|
fn Store::get_states(self : Store) -> @respo.RespoStatesTree {
  self.states
}

///|
/// Immutable update: returns a new Store with the action applied
fn Store::update(self : Store, op : ActionOp) -> Store {
  match op {
    StatesChange(change) => { states: self.states.set_in(change) }
  }
}
