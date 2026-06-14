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
            .fontColor('#1A1A1A')
            .textAlign(TextAlign.Center)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('#E0E0E0')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.back();
        })
        Text('帮助与反馈')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Row().width(36)
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .border({ width: { bottom: 0.5 }, color: '#E0E0E0' })

      // 内容区域
      Column() {
        Column() {
          Text('Bug反馈邮箱')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#666')
            .margin({ bottom: 6 })
          Text('huangbh2001@qq.com')
            .fontSize(15)
            .fontColor('#4A90D9')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(12)
        .margin(12)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor('#F5F6FA')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}
