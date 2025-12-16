///|
// 三仙归洞 - Three Cups Magic Demo
// Demonstrates fractional indexing with animated cup shuffling

using @respo {type StateRef}

///|
// 注入下落动画的 CSS keyframes时使用动态偏移量
extern "js" fn inject_drop_animation(offset_x : Int, offset_y : Int) -> Unit =
  #| (offsetX, offsetY) => {
  #|   let style = document.getElementById('drop-animation-style');
  #|   if (!style) {
  #|     style = document.createElement('style');
  #|     style.id = 'drop-animation-style';
  #|     document.head.appendChild(style);
  #|   }
  #|   style.textContent = `
  #|     @keyframes cup-drop {
  #|       0% { transform: translate(${offsetX}px, ${offsetY}px); }
  #|       100% { transform: translate(0, 0); }
  #|     }
  #|     .cup-dropping {
  #|       animation: cup-drop 0.35s ease-out forwards;
  #|     }
  #|   `;
  #| }

///|
struct Cup {
  id : String
  key : String // 字典序 key，用于排序
  color : String // 碗的颜色标识
} derive(ToJson, @json.FromJson, Eq)

///|
// 用于存储 drop 动画数据（不序列化，避免影响 state 比较和存储）
struct DropAnimationData {
  mut drop_zone_idx : Int // drop 到哪个 zone
}

///|
impl Default for DropAnimationData with default() {
  { drop_zone_idx: 0 }
}

///|
struct DemoState {
  cups : Array[Cup]
  next_shuffle_seed : Int // 用于生成伪随机
  dragging_cup_id : String? // 正在拖拽的碗 ID
  drop_target_idx : Int? // 悬停的放置目标位置索引
  just_dropped_cup_id : String? // 刚刚放下的碗 ID，用于下落动画
  // 临时数据，不参与序列化
  drop_animation_data : StateRef[DropAnimationData]
} derive(ToJson, @json.FromJson)

///|
impl Default for DemoState with default() {
  {
    cups: [],
    next_shuffle_seed: 0,
    dragging_cup_id: None,
    drop_target_idx: None,
    just_dropped_cup_id: None,
    drop_animation_data: StateRef::new(DropAnimationData::default()),
  }
}

///|
// 初始的三个碗，使用 lexicon key_between 生成初始 key
fn initial_cups() -> Array[Cup] {
  // 使用 lexicon 生成 3 个初始 key
  let keys = @lexicon.n_keys_between(None, None, 3) catch {
    _ => ["a0", "a1", "a2"]
  }
  [
    { id: "cup-red", key: keys[0], color: "red" },
    { id: "cup-green", key: keys[1], color: "green" },
    { id: "cup-blue", key: keys[2], color: "blue" },
  ]
}

///|
// 使用 lexicon 生成介于两个 key 之间的新 key
fn generate_key_between(before : String?, after : String?) -> String {
  @lexicon.key_between(before, after) catch {
    _ =>
      // fallback
      match (before, after) {
        (None, None) => "a0"
        (Some(b), None) => b + "V"
        (None, Some(_)) => "a0"
        (Some(b), Some(_)) => b + "V"
      }
  }
}

///|
// 获取碗的背景颜色 - 基于 HSLuv 色彩空间选择，hue 相隔 120° 以获得最佳区分度
fn get_cup_bg_color(color : String) -> @css.CssColor {
  match color {
    // HSLuv H=12, S=90, L=65 → 明亮珊瑚红
    "red" => Hsl(12, 85, 58)
    // HSLuv H=132, S=85, L=55 → 明亮翠绿
    "green" => Hsl(145, 70, 48)
    // HSLuv H=252, S=90, L=60 → 明亮天蓝
    "blue" => Hsl(225, 75, 58)
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

// View

///|
fn comp_fractional_index_demo(
  states : @respo.RespoStatesTree,
) -> RespoNode[ActionOp] {
  let (state, cursor) : (DemoState, @respo_node.RespoCursor[DemoState]) = states.local_pair()

  // 初始化碗
  let cups = if state.cups.is_empty() { initial_cups() } else { state.cups }

  // 按 key 排序的碗列表（使用 lexical_compare 进行字典序比较）
  let sorted_cups = cups.copy()
  sorted_cups.sort_by(fn(a, b) { a.key.lexical_compare(b.key) })

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

      // 构建不包含被选中碗的排序列表
      let other_cups : Array[Cup] = sorted_cups.filter(fn(c) { c.id != cup.id })

      // 随机选择目标位置 (在 other_cups 中的插入位置)
      // 插入位置范围是 0 到 other_cups.length()
      let target_pos = pseudo_random(seed + 1, other_cups.length() + 1)

      // 计算新的 key（基于排除了被选中碗的列表）
      let (before_key, after_key) : (String?, String?) = if target_pos == 0 {
        // 移动到最前面
        (None, Some(other_cups[0].key))
      } else if target_pos >= other_cups.length() {
        // 移动到最后面
        (Some(other_cups[other_cups.length() - 1].key), None)
      } else {
        // 移动到中间
        let bk = other_cups[target_pos - 1].key
        let ak = other_cups[target_pos].key
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
      let next_state = {
        ..state,
        cups: new_cups,
        next_shuffle_seed: seed + 7,
        dragging_cup_id: None,
        drop_target_idx: None,
        just_dropped_cup_id: None,
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
      let next_state = {
        ..state,
        cups: initial_cups(),
        next_shuffle_seed: 42,
        dragging_cup_id: None,
        drop_target_idx: None,
        just_dropped_cup_id: None,
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
        // 获取最新的 cups
        let current_cups = if state.cups.is_empty() {
          initial_cups()
        } else {
          state.cups
        }
        let next_state = {
          ..state,
          cups: current_cups,
          dragging_cup_id: Some(cup.id),
          drop_target_idx: None,
          just_dropped_cup_id: None, // 清除之前的 drop 标记
        }
        dispatch.set_state(cursor, next_state)
      }
    }
  }

  // Drag end - 清除拖拽状态
  // 注意：drop 事件会在 drag end 之前触发并清除状态
  // 所以这里检查如果 dragging_cup_id 已经是 None，就不再设置状态
  let on_drag_end = fn(
    _e : RespoEvent,
    _dispatch : DispatchFn[ActionOp],
  ) -> Unit raise @respo_node.RespoCommonError {
    // drop 事件已经处理了状态更新，这里不需要做任何事
    // 避免用旧的闭包数据覆盖 drop 设置的新状态
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
        let current_cups = if state.cups.is_empty() {
          initial_cups()
        } else {
          state.cups
        }
        let next_state = {
          ..state,
          cups: current_cups,
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
    let current_cups = if state.cups.is_empty() {
      initial_cups()
    } else {
      state.cups
    }
    let next_state = { ..state, cups: current_cups, drop_target_idx: None }
    dispatch.set_state(cursor, next_state)
  }

  // 放置区域的 drop - 执行放置
  let make_zone_drop = fn(zone_idx : Int) {
    fn(
      e : RespoEvent,
      dispatch : DispatchFn[ActionOp],
    ) -> Unit raise @respo_node.RespoCommonError {
      @dom_ffi.log("drop event triggered, zone_idx: " + zone_idx.to_string())
      if e is Drag(original_event~, ..) {
        @dom_ffi.log("matched Drag event")
        original_event.prevent_default()

        // 从 dataTransfer 获取拖拽的碗 id
        let dt = original_event.data_transfer()
        let dragged_id = dt.get_data("text/plain")
        @dom_ffi.log("dragged_id: '" + dragged_id + "'")
        if dragged_id.is_empty() {
          @dom_ffi.log("dragged_id is empty, returning early")
          return
        }

        // 重新从 state 获取 cups（避免闭包捕获旧值的问题）
        let current_cups = if state.cups.is_empty() {
          initial_cups()
        } else {
          state.cups
        }

        // 重新计算排序
        let current_sorted = current_cups.copy()
        current_sorted.sort_by(fn(a, b) { a.key.lexical_compare(b.key) })

        // 找到被拖拽碗的当前位置
        let mut dragged_pos = 0
        for i = 0; i < current_sorted.length(); i = i + 1 {
          if current_sorted[i].id == dragged_id {
            dragged_pos = i
            break
          }
        }
        @dom_ffi.log(
          "dragged_pos: " +
          dragged_pos.to_string() +
          ", zone_idx: " +
          zone_idx.to_string(),
        )
        let is_adjacent = zone_idx == dragged_pos || zone_idx == dragged_pos + 1
        @dom_ffi.log("is_adjacent: " + is_adjacent.to_string())

        // 如果放到自己的相邻位置，不需要移动
        if is_adjacent {
          @dom_ffi.log("adjacent position, skipping move")
          let next_state = {
            ..state,
            cups: current_cups,
            dragging_cup_id: None,
            drop_target_idx: None,
            just_dropped_cup_id: None,
          }
          dispatch.set_state(cursor, next_state)
          return
        }
        @dom_ffi.log("proceeding with move...")

        // 构建不包含被拖拽碗的排序列表
        let other_cups : Array[Cup] = current_sorted.filter(fn(c) {
          c.id != dragged_id
        })
        @dom_ffi.log("other_cups length: " + other_cups.length().to_string())

        // 计算实际的插入位置：如果 zone_idx 在 dragged_pos 之后，需要减 1
        let insert_idx = if zone_idx > dragged_pos {
          zone_idx - 1
        } else {
          zone_idx
        }
        @dom_ffi.log("insert_idx: " + insert_idx.to_string())

        // 计算新的 key（基于排除了被拖拽碗的列表）
        let (before_key, after_key) : (String?, String?) = if insert_idx == 0 {
          // 放到最前面
          @dom_ffi.log("case: insert at front")
          (None, Some(other_cups[0].key))
        } else if insert_idx >= other_cups.length() {
          // 放到最后面
          @dom_ffi.log("case: insert at end")
          (Some(other_cups[other_cups.length() - 1].key), None)
        } else {
          // 放到中间：insert_idx-1 和 insert_idx 之间
          @dom_ffi.log("case: insert in middle")
          let bk = other_cups[insert_idx - 1].key
          let ak = other_cups[insert_idx].key
          (Some(bk), Some(ak))
        }
        @dom_ffi.log("generating new key...")
        let new_key = generate_key_between(before_key, after_key)
        @dom_ffi.log("new_key: " + new_key)

        // 更新碗的 key
        let new_cups = current_cups.map(fn(c) {
          if c.id == dragged_id {
            { ..c, key: new_key }
          } else {
            c
          }
        })
        @dom_ffi.log("setting state with new cups...")
        // 存储动画数据：drop zone 索引
        state.drop_animation_data.borrow().val.drop_zone_idx = zone_idx
        @dom_ffi.log("drop zone_idx: " + zone_idx.to_string())
        let next_state = {
          ..state,
          cups: new_cups,
          next_shuffle_seed: state.next_shuffle_seed + 1,
          dragging_cup_id: None,
          drop_target_idx: None,
          just_dropped_cup_id: Some(dragged_id), // 标记刚刚放下的碗及位置
        }
        dispatch.set_state(cursor, next_state)
        @dom_ffi.log("state set done with just_dropped_cup_id: " + dragged_id)
      }
    }
  }

  // 创建放置区域元素，带有 left 位置
  // dragging_rank: 正在拖拽的碗在 sorted_cups 中的位置，用于判断是否是无效放置位置
  let make_drop_zone = fn(
    zone_idx : Int,
    left_px : Float,
    dragging_rank : Int?,
  ) -> RespoNode[ActionOp] {
    let is_active = state.drop_target_idx == Some(zone_idx)
    // 判断是否是无效的放置位置（碗的相邻位置）
    let is_invalid_zone = match dragging_rank {
      Some(rank) => zone_idx == rank || zone_idx == rank + 1
      None => false
    }
    let bg_color : @css.CssColor = if is_active {
      if is_invalid_zone {
        Hsl(0, 0, 60) // 无效位置用暗灰色
      } else {
        Hsl(210, 90, 55) // 有效位置用亮蓝色
      }
    } else if is_dragging {
      if is_invalid_zone {
        Hsl(0, 0, 90) // 无效位置用更浅的灰色
      } else {
        Hsl(0, 0, 75) // 深灰色
      }
    } else {
      Hsl(0, 0, 85) // 浅灰色 - 始终可见
    }
    let indicator_height : Float = if is_active && not(is_invalid_zone) {
      120.0
    } else {
      90.0
    }
    let indicator_width : Float = if is_active && not(is_invalid_zone) {
      18.0
    } else {
      10.0
    }
    div(
      class_name=style_drop_zone,
      style=respo_style(left=left_px |> Px),
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
            width=indicator_width |> Px,
          ).add("pointer-events", "none"),
          [],
        ),
      ],
    )
  }

  // 布局常量
  let cup_width : Float = 180.0
  let zone_width : Float = 60.0 // 放置区域宽度
  let total_content_width = Float::from_int(cups.length()) * cup_width +
    Float::from_int(cups.length() + 1) * zone_width
  let start_offset : Float = (800.0 - total_content_width) / 2.0

  // 构建碗位置映射：cup.id -> 在 sorted_cups 中的位置 (rank)
  let cup_rank : Map[String, Int] = {}
  for idx, cup in sorted_cups {
    cup_rank[cup.id] = idx
  }

  // 获取正在拖拽的碗的 rank（用于判断无效放置位置）
  let dragging_rank : Int? = match state.dragging_cup_id {
    Some(id) => cup_rank.get(id)
    None => None
  }

  // 按 id 排序的碗列表 (DOM 顺序固定不变)
  let cups_by_id = cups.copy()
  cups_by_id.sort_by(fn(a, b) { a.id.compare(b.id) })

  // 先渲染所有放置区域 (按位置排序)
  let drop_zones : Array[RespoNode[ActionOp]] = []
  for zone_idx = 0; zone_idx <= sorted_cups.length(); zone_idx = zone_idx + 1 {
    let zone_left : Float = start_offset +
      Float::from_int(zone_idx) * (cup_width + zone_width)
    drop_zones.push(make_drop_zone(zone_idx, zone_left, dragging_rank))
  }

  // 渲染所有碗 (DOM 顺序按 id 固定，位置由 left 控制)
  let cup_elements : Array[RespoNode[ActionOp]] = []
  for cup in cups_by_id {
    let cup_is_dragging = state.dragging_cup_id == Some(cup.id)
    let cup_just_dropped = state.just_dropped_cup_id == Some(cup.id)
    // 根据碗在 sorted_cups 中的 rank 计算 left 位置
    let rank = cup_rank.get(cup.id).unwrap_or(0)
    let cup_left : Float = start_offset +
      zone_width +
      Float::from_int(rank) * (cup_width + zone_width)

    // 如果是刚放下的碗，计算从 drop zone 位置到最终位置的偏移并注入动画
    if cup_just_dropped {
      // 从 state 的 Ref 读取动画数据
      let anim_data = state.drop_animation_data.borrow().val
      let drop_zone_idx = anim_data.drop_zone_idx
      // drop zone 的中心 X 位置（相对于容器）
      let zone_center_x : Float = start_offset +
        Float::from_int(drop_zone_idx) * (cup_width + zone_width) +
        zone_width / 2.0
      // 碗的中心 X 位置（相对于容器）
      let cup_center_x : Float = cup_left + cup_width / 2.0
      // 偏移量 = drop zone 位置 - 碗最终位置（只需要 X 方向，Y 不变）
      let offset_x = (zone_center_x - cup_center_x).to_int()
      let offset_y = 0 // Y 方向不移动
      @dom_ffi.log(
        "animation: zone_center(" +
        zone_center_x.to_string() +
        ") - cup_center(" +
        cup_center_x.to_string() +
        ") = offset_x(" +
        offset_x.to_string() +
        ") [drop_zone_idx=" +
        drop_zone_idx.to_string() +
        ", new_rank=" +
        rank.to_string() +
        "]",
      )
      inject_drop_animation(offset_x, offset_y)
    }

    // 计算 transition：
    // - 正在拖拽的碗：无动画
    // - 刚刚放下的碗：无动画（用 CSS animation 实现下落）
    // - 其他碗：400ms 动画
    let cup_transition = if cup_is_dragging || cup_just_dropped {
      "none"
    } else {
      "left 0.4s ease, transform 0.2s ease"
    }
    // 刚放下的碗使用 CSS animation class
    let cup_class = if cup_just_dropped {
      style_cup + " cup-dropping"
    } else {
      style_cup
    }
    // 碗
    cup_elements.push(
      div(
        class_name=cup_class,
        draggable=true,
        on_drag_start=make_drag_start(cup),
        on_drag_end~,
        style=respo_style(
            left=cup_left |> Px,
            opacity=if cup_is_dragging { 0.4 } else { 1.0 },
            transition=cup_transition,
          )
          // 拖拽时禁用 pointer-events，让 drop zone 更容易被命中
          .add("pointer-events", if cup_is_dragging { "none" } else { "auto" })
          // 添加 data-cup-id 以便 JS 获取元素位置
          .add("data-cup-id", cup.id),
        [
          // 碗体（包含 key 标签在中间）
          div(
            class_name=style_cup_body,
            style=respo_style(background_color=get_cup_bg_color(cup.color)),
            [div(class_name=style_key_label, [text_node("\{cup.key}")])],
          ),
        ],
      ),
    )
  }

  // 合并放置区域和碗元素
  let cups_with_zones : Array[RespoNode[ActionOp]] = []
  cups_with_zones.append(drop_zones)
  cups_with_zones.append(cup_elements)
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
      div(
        style=respo_style(
          margin_top=8 |> Px,
          font_family="Source Code Pro, monospace",
        ),
        [
          text_node(
            sorted_cups.map(fn(c) { "\{c.color}(\{c.key})" }).join(" → "),
          ),
        ],
      ),
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

// styles

///|
// 静态样式定义
let style_container : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      padding=24 |> Px,
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
      width=860 |> Px,
      height=200 |> Px,
      background_color=Hsl(28, 24, 96),
      border_radius=14.0,
      margin_top=20 |> Px,
      display=Flex,
      justify_content=Center,
      align_items=FlexEnd, // Align to bottom
      padding_bottom=20 |> Px,
      box_shadow="0 12px 28px rgba(0,0,0,0.08)",
    ).add(
      "background-image", "radial-gradient(circle at 50% 35%, rgba(255,255,255,0.9), rgba(240,236,230,0.6) 55%, rgba(232,228,222,0.6) 100%)",
    ),
  ),
])

///|
let style_cups_row : String = @respo_node.static_style([
  ("&", respo_style(position=Relative, width=800 |> Px, height=140 |> Px)),
])

///|
let style_cup : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      position=Absolute,
      bottom=0 |> Px,
      width=180 |> Px,
      height=110 |> Px,
      cursor=Pointer,
      display=Flex,
      flex_direction=Column,
      align_items=Center,
      justify_content=FlexEnd,
      padding_bottom=6 |> Px,
      transition="left 0.3s ease, transform 0.2s ease",
    ),
  ),
  ("&:hover", respo_style(transform=TranslateY(-8))),
])

///|
let style_cup_body : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      width=160 |> Px,
      height=90 |> Px,
      border_radius=10.0,
      display=Flex,
      align_items=Center,
      justify_content=Center,
      box_shadow="inset 0 -16px 26px rgba(0,0,0,0.32), inset 0 6px 10px rgba(255,255,255,0.22), 0 10px 18px rgba(0,0,0,0.12)",
    )
    .add("border-bottom-left-radius", "32px")
    .add("border-bottom-right-radius", "32px")
    .add("border-top-left-radius", "20px")
    .add("border-top-right-radius", "20px")
    .add(
      "clip-path", "polygon(28% 0%, 72% 0%, 76% 10%, 88% 40%, 95% 80%, 98% 100%, 2% 100%, 5% 80%, 12% 40%, 24% 10%)",
    )
    .add(
      "background-image", "linear-gradient(145deg, rgba(255,255,255,0.18), rgba(0,0,0,0.08) 55%, rgba(0,0,0,0.22))",
    ),
  ),
])

///|
let style_key_label : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      font_size=20,
      color=Hsl(0, 0, 100),
      font_family="Source Code Pro, monospace",
      font_weight="900",
    )
    .add(
      "text-shadow", "0 1px 3px rgba(0,0,0,0.7), 0 0 10px rgba(0,0,0,0.35), 0 0 18px rgba(0,0,0,0.25)",
    )
    .add("letter-spacing", "0.7px"),
  ),
])

///|
let style_info_panel : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      margin_top=14 |> Px,
      padding=12 |> Px,
      background_color=Hsl(0, 0, 99),
      border_radius=10.0,
      min_width=380 |> Px,
      color=Hsl(0, 0, 38),
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
      position=Absolute,
      bottom=0 |> Px,
      width=60 |> Px,
      height=130 |> Px,
      display=Flex,
      align_items=Center,
      justify_content=Center,
      z_index=10,
    ),
  ),
])

///|
// 放置区域内的指示线 - 宽度和高度由动态样式控制
let style_drop_indicator : String = @respo_node.static_style([
  (
    "&",
    respo_style(
      width=10 |> Px,
      height=90 |> Px,
      border_radius=4.0,
      transition="all 0.15s ease",
    ),
  ),
])
