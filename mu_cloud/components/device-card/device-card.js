Component({
  properties: {
    image: { type: String, value: '' },
    name: { type: String, value: '' },
    status: { type: String, value: '' },
    /** 页面类型：socket | smartled，用于匹配抽离前的 .card 样式 */
    variant: { type: String, value: 'smartled' }
  }
})
