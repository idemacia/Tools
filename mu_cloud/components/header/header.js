Component({
  properties: {
    title: {
      type: String,
      value: '标题'
    },
    showBack: {
      type: Boolean,
      value: false
    }
  },
  methods: {
    handleBack() {
      wx.navigateBack()
    }
  }
})
