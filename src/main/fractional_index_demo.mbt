///|
// 三仙归洞 - Three Cups Magic Demo
// Demonstrates fractional indexing with animated cup shuffling

///|
struct Cup {
  id : String
  key : String // 字典序 key，用于排序
  color : String // 碗的颜色标识
} derive(ToJson, @json.FromJson, Eq)

///|
struct DemoState {
  cups : Array[Cup]
  next_shuffle_seed : Int // 用于生成伪随机
  dragging_cup_id : String? // 正在拖拽的碗 ID
  drop_target_idx : Int? // 悬停的放置目标位置索引
} derive(Default, ToJson, @json.FromJson)

///|
// 静态样式定义
let style_container : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      padding=20 |> Px,
      display=Flex,
      flex_direction=Column,
      align_items=Center,
    ),
  ),
])

///|
let style_stage : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      position=Relative,
      width=500 |> Px,
      height=300 |> Px,
      background_color=Hsl(30, 20, 95),
      border_radius=8.0,
      margin_top=20 |> Px,
      display=Flex,
      justify_content=Center,
      align_items=FlexEnd,
      padding_bottom=40 |> Px,
    ),
  ),
])

///|
let style_cups_row : String = @respo_node.static_style([
  ("&", respo_style(display=Flex, gap=Px(0), align_items=FlexEnd)),
])

///|
let style_cup : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      width=80 |> Px,
      height=120 |> Px,
      cursor=Pointer,
      display=Flex,
      flex_direction=Column,
      align_items=Center,
      justify_content=FlexEnd,
      padding_bottom=8 |> Px,
      transition="transform 0.3s ease, box-shadow 0.2s ease",
    ),
  ),
  ("&:hover", respo_style(transform=TranslateY(-10))),
])

///|
let style_cup_body : String = @respo_node.static_style([
  ("&", respo_style(width=70 |> Px, height=90 |> Px, border_radius=8.0)),
])

///|
let style_key_label : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      font_size=12,
      color=Hsl(0, 0, 40),
      margin_top=8 |> Px,
      font_family="monospace",
    ),
  ),
])

///|
let style_info_panel : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      margin_top=20 |> Px,
      padding=16 |> Px,
      background_color=Hsl(0, 0, 98),
      border_radius=8.0,
      min_width=400 |> Px,
    ),
  ),
])

///|
let style_button_row : String = @respo_node.static_style([
  ("&", respo_style(display=Flex, gap=Px(12), margin_top=16 |> Px)),
])

///|
// 放置区域样式 - 碗之间的间隙，足够宽以便容易命中
let style_drop_zone : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      width=60 |> Px,
      height=140 |> Px,
      display=Flex,
      align_items=Center,
      justify_content=Center,
      transition="all 0.2s ease",
    ),
  ),
])

///|
// 放置区域内的指示线
let style_drop_indicator : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      width=8 |> Px,
      height=80 |> Px,
      border_radius=4.0,
      transition="all 0.2s ease",
    ),
  ),
])

///|
// 初始的三个碗
fn initial_cups() -> Array[Cup] {
  [
    { id: "cup-red", key: "a", color: "red" },
    { id: "cup-green", key: "m", color: "green" },
    { id: "cup-blue", key: "z", color: "blue" },
  ]
}

///|
// 生成介于两个 key 之间的新 key
fn generate_key_between(before : String?, after : String?) -> String {
  match (before, after) {
    (None, None) => "m"
    (None, Some(a)) =>
      // 在最前面插入
      if a.length() > 0 {
        let first_char = a.get_char(0)
        match first_char {
          Some(c) if c > 'a' =>
            // 用前一个字符
            (c.to_int() - 1).unsafe_to_char().to_string()
          _ => "a" + "m" // 加后缀
        }
      } else {
        "a"
      }
    (Some(b), None) =>
      // 在最后面插入
      b + "m"
    (Some(b), Some(_a)) =>
      // 在中间插入
      b + "n"
  }
}

///|
// 获取碗的背景颜色
fn get_cup_bg_color(color : String) -> @css.CssColor {
  match color {
    "red" => Hsl(10, 70, 50)
    "green" => Hsl(120, 60, 45)
    "blue" => Hsl(240, 70, 50)
    _ => Hsl(0, 0, 60)
  }
}

///|
// 简单的伪随机数生成 (基于种子)
fn pseudo_random(seed : Int, max : Int) -> Int {
  let a = 1103515245
  let c = 12345
  let m = 2147483647
  let next = (a * seed + c) % m
  (next % max).abs()
}

///|
fn comp_fractional_index_demo(
  states : @respo.RespoStatesTree,
) -> RespoNode[ActionOp] {
  let (state, cursor) : (DemoState, @respo_node.RespoCursor[DemoState]) = states.local_pair()

  // 初始化碗
  let cups = if state.cups.is_empty() { initial_cups() } else { state.cups }

  // 按 key 排序的碗列表
  let sorted_cups = cups.copy()
  sorted_cups.sort_by(fn(a, b) { a.key.compare(b.key) })

  // 随机移动一个碗
  let on_shuffle = fn(
    e : RespoEvent,
    dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    if e is Click(..) {
      let seed = state.next_shuffle_seed
      // 随机选择一个碗
      let cup_index = pseudo_random(seed, cups.length())
      let cup = sorted_cups[cup_index]

      // 随机选择目标位置 (不同于当前位置)
      let mut target_pos = pseudo_random(seed + 1, cups.length())
      if target_pos == cup_index && cups.length() > 1 {
        target_pos = (target_pos + 1) % cups.length()
      }

      // 计算新的 key
      let (before_key, after_key) : (String?, String?) = if target_pos == 0 {
        // 移动到最前面
        (None, Some(sorted_cups[0].key))
      } else if target_pos >= cups.length() - 1 {
        // 移动到最后面
        (Some(sorted_cups[cups.length() - 1].key), None)
      } else {
        // 移动到中间
        let bk = sorted_cups[target_pos - 1].key
        let ak = sorted_cups[target_pos].key
        (Some(bk), Some(ak))
      }
      let new_key = generate_key_between(before_key, after_key)

      // 更新碗的 key
      let new_cups = cups.map(fn(c) {
        if c.id == cup.id {
          { ..c, key: new_key }
        } else {
          c
        }
      })
      let next_state = DemoState::{
        cups: new_cups,
        next_shuffle_seed: seed + 7,
        dragging_cup_id: None,
        drop_target_idx: None,
      }
      dispatch.set_state(cursor, next_state)
    }
  }

  // 重置
  let on_reset = fn(
    e : RespoEvent,
    dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    if e is Click(..) {
      let next_state = DemoState::{
        cups: initial_cups(),
        next_shuffle_seed: 42,
        dragging_cup_id: None,
        drop_target_idx: None,
      }
      dispatch.set_state(cursor, next_state)
    }
  }

  // Drag start - 记录正在拖拽的碗
  let make_drag_start = fn(cup : Cup) {
    fn(
      e : RespoEvent,
      dispatch : DispatchFn[ActionOp],
    ) -> Unit raise @respo_node.RespoCommonError {
      if e is Drag(original_event~, ..) {
        // 设置拖拽数据
        let dt = original_event.data_transfer()
        dt.set_data("text/plain", cup.id)
        dt.set_effect_allowed("move")
        let next_state = DemoState::{
          ..state,
          cups,
          dragging_cup_id: Some(cup.id),
        }
        dispatch.set_state(cursor, next_state)
      }
    }
  }

  // Drag end - 清除拖拽状态
  let on_drag_end = fn(
    _e : RespoEvent,
    dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    let next_state = DemoState::{ ..state, cups, dragging_cup_id: None }
    dispatch.set_state(cursor, next_state)
  }

  // Drag over - 允许放置
  let on_drag_over : (RespoEvent, DispatchFn[ActionOp]) -> Unit raise @respo_node.RespoCommonError = fn(
    e,
    _dispatch,
  ) {
    if e is Drag(original_event~, ..) {
      original_event.prevent_default()
    }
  }

  // 判断是否正在拖拽
  let is_dragging = state.dragging_cup_id is Some(_)

  // 放置区域的 drag enter - 高亮显示
  let make_zone_drag_enter = fn(zone_idx : Int) {
    fn(
      e : RespoEvent,
      dispatch : DispatchFn[ActionOp],
    ) -> Unit raise @respo_node.RespoCommonError {
      if e is Drag(original_event~, ..) {
        original_event.prevent_default()
        let next_state = DemoState::{
          ..state,
          cups,
          drop_target_idx: Some(zone_idx),
        }
        dispatch.set_state(cursor, next_state)
      }
    }
  }

  // 放置区域的 drag leave - 取消高亮
  let on_zone_drag_leave = fn(
    _e : RespoEvent,
    dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    let next_state = DemoState::{ ..state, cups, drop_target_idx: None }
    dispatch.set_state(cursor, next_state)
  }

  // 放置区域的 drop - 执行放置
  let make_zone_drop = fn(zone_idx : Int) {
    fn(
      e : RespoEvent,
      dispatch : DispatchFn[ActionOp],
    ) -> Unit raise @respo_node.RespoCommonError {
      if e is Drag(original_event~, ..) {
        original_event.prevent_default()
        let dragged_cup_id = state.dragging_cup_id
        if dragged_cup_id is None {
          return
        }
        let dragged_id = dragged_cup_id.unwrap()

        // 找到被拖拽碗的当前位置
        let mut dragged_pos = 0
        for i = 0; i < sorted_cups.length(); i = i + 1 {
          if sorted_cups[i].id == dragged_id {
            dragged_pos = i
            break
          }
        }

        // 如果放到自己的相邻位置，不需要移动
        if zone_idx == dragged_pos || zone_idx == dragged_pos + 1 {
          let next_state = DemoState::{
            ..state,
            cups,
            dragging_cup_id: None,
            drop_target_idx: None,
          }
          dispatch.set_state(cursor, next_state)
          return
        }

        // 计算新的 key
        let (before_key, after_key) : (String?, String?) = if zone_idx == 0 {
          // 放到最前面
          (None, Some(sorted_cups[0].key))
        } else if zone_idx >= sorted_cups.length() {
          // 放到最后面
          (Some(sorted_cups[sorted_cups.length() - 1].key), None)
        } else {
          // 放到中间：zone_idx-1 和 zone_idx 之间
          let bk = sorted_cups[zone_idx - 1].key
          let ak = sorted_cups[zone_idx].key
          (Some(bk), Some(ak))
        }
        let new_key = generate_key_between(before_key, after_key)

        // 更新碗的 key
        let new_cups = cups.map(fn(c) {
          if c.id == dragged_id {
            { ..c, key: new_key }
          } else {
            c
          }
        })
        let next_state = DemoState::{
          cups: new_cups,
          next_shuffle_seed: state.next_shuffle_seed + 1,
          dragging_cup_id: None,
          drop_target_idx: None,
        }
        dispatch.set_state(cursor, next_state)
      }
    }
  }

  // 创建放置区域元素
  let make_drop_zone = fn(zone_idx : Int) -> RespoNode[ActionOp] {
    let is_active = state.drop_target_idx == Some(zone_idx)
    let bg_color : @css.CssColor = if is_active {
      Hsl(210, 90, 55) // 亮蓝色
    } else if is_dragging {
      Hsl(0, 0, 75) // 深灰色
    } else {
      Hsl(0, 0, 85) // 浅灰色 - 始终可见
    }
    let indicator_height : Float = if is_active { 100.0 } else { 70.0 }
    div(
      class_name=style_drop_zone,
      on_drag_over~,
      on_drag_enter=make_zone_drag_enter(zone_idx),
      on_drag_leave=on_zone_drag_leave,
      on_drop=make_zone_drop(zone_idx),
      [
        div(
          class_name=style_drop_indicator,
          style=respo_style(
            background_color=bg_color,
            height=indicator_height |> Px,
          ).add("pointer-events", "none"),
          [],
        ),
      ],
    )
  }

  // 构建碗和放置区域交错的列表
  let cups_with_zones : Array[RespoNode[ActionOp]] = []
  // 第一个放置区域（最左边）
  cups_with_zones.push(make_drop_zone(0))
  for idx, cup in sorted_cups {
    let cup_is_dragging = state.dragging_cup_id == Some(cup.id)
    // 碗
    cups_with_zones.push(
      div(
        class_name=style_cup,
        draggable=true,
        on_drag_start=make_drag_start(cup),
        on_drag_end~,
        style=respo_style(opacity=if cup_is_dragging { 0.4 } else { 1.0 }),
        [
          // 碗体
          div(
            class_name=style_cup_body,
            style=respo_style(
              background_color=get_cup_bg_color(cup.color),
              box_shadow="inset 0 -20px 30px rgba(0,0,0,0.3)",
            ),
            [],
          ),
          // Key 标签
          div(class_name=style_key_label, [text_node("key: \{cup.key}")]),
        ],
      ),
    )
    // 碗后面的放置区域
    cups_with_zones.push(make_drop_zone(idx + 1))
  }
  div(class_name=style_container, [
    // 标题
    div([
      @respo_node.h1(inner_text="三仙归洞 - Three Cups Magic", []),
      p(inner_text="拖拽碗到灰色指示条可以改变位置", []),
    ]),
    // 舞台
    div(class_name=style_stage, [
      div(class_name=style_cups_row, cups_with_zones),
    ]),
    // 信息面板
    div(class_name=style_info_panel, [
      div([text_node("当前排序 (按 key 字典序):")]),
      div(style=respo_style(margin_top=8 |> Px, font_family="monospace"), [
        text_node(
          sorted_cups.map(fn(c) { "\{c.color}(\{c.key})" }).join(" → "),
        ),
      ]),
      // 按钮行
      div(class_name=style_button_row, [
        button(
          inner_text="随机洗牌",
          class_name=@respo.ui_button_primary,
          on_click=on_shuffle,
        ),
        button(
          inner_text="重置",
          class_name=@respo.ui_button,
          on_click=on_reset,
        ),
      ]),
    ]),
  ])
}
