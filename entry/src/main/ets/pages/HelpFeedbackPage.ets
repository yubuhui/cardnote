import { router } from '@kit.ArkUI';

/** 帮助与反馈页面 */
@Entry
@Component
struct HelpFeedbackPage {
  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Row() {
          Text('‹')
            .fontSize(22)
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor($r('app.color.nav_back_bg'))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.back();
        })
        Text('帮助与反馈')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Row().width(36)
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.card_background'))
      .border({ width: { bottom: 0.5 }, color: $r('app.color.sync_divider_strong') })

      // 内容区域
      Column() {
        Column() {
          Text('Bug反馈邮箱')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ bottom: 6 })
          Text('huangbh2001@qq.com')
            .fontSize(15)
            .fontColor($r('app.color.primary_color'))
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .margin(12)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('app.color.background_color'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
