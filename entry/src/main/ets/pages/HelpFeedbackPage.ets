
@Entry
@Component
struct HelpFeedbackPage {
  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('‹')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .width(36)
          .onClick(() => {
          this.getUIContext().getRouter().back();
        })
        Text('帮助与反馈')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Row().width(36)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 46, bottom: 12 })
      .backgroundColor($r('app.color.surface'))

      // 内容区域
      Column() {
        Column() {
          Text('Bug反馈邮箱')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .margin({ bottom: 6 })
          Text('huangbh2001@qq.com')
            .fontSize(15)
            .fontColor($r('app.color.primary'))
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(12)
        .margin(12)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('app.color.background'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
  }
}
