Component({
  properties: {
    title: { type: String, value: '' },
    /** 为 true 时不加卡片背景，仅展示标题+插槽（用于 slot 内已是完整卡片的场景） */
    bare: { type: Boolean, value: false },
    /** 为 true 时标题与插槽内容同一行显示（用于滑块等控制） */
    inlineTitle: { type: Boolean, value: false }
  }
})
