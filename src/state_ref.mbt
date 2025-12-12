///|
/// StateRef wraps a mutable Ref while serializing to an empty JSON object.
/// Use it for ephemeral fields that should not affect persisted snapshots.
pub struct StateRef[T] {
  cell : Ref[T]
}

///|
fn[T] StateRef::new(value : T) -> StateRef[T] {
  { cell: Ref::new(value) }
}

///|
/// Returns the underlying Ref so callers can mutate the payload directly.
fn[T] StateRef::borrow(self : StateRef[T]) -> Ref[T] {
  self.cell
}

///|
impl[T : Default] Default for StateRef[T] with default() {
  StateRef::new(T::default())
}

///|
impl[T] ToJson for StateRef[T] with to_json(_self) {
  let empty_object : Map[String, Json] = {}
  Json::object(empty_object)
}

///|
impl[T : Default] @json.FromJson for StateRef[T] with from_json(_json, _path) {
  StateRef::default()
}
