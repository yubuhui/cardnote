import { Card } from '../model/Card';

@Component
export struct FlipCard {
  @Prop card: Card;
  @Prop showAnswer: boolean;
  @State isFlipped: boolean = false;

  build() {
    Column() {
      // 正面
      if (!this.showAnswer && !this.isFlipped) {
        Text(this.card.front)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Start)
          .lineHeight(26)
          .padding(24)
          .width('100%')
          .height('100%')
      }

      // 背面（问题 + 答案 + 解析）
      if (this.showAnswer || this.isFlipped) {
        Scroll() {
          Column({ space: 12 }) {
            // 问题
            Column() {
              Text('问题')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Start)
                .width('100%')
                .margin({ bottom: 6 })
              Text(this.card.front)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .lineHeight(22)
                .textAlign(TextAlign.Start)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.background'))
            .borderRadius(10)

            // 答案
            Column() {
              Text('答案')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Start)
                .width('100%')
                .margin({ bottom: 6 })
              Text(this.card.correctAnswer)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .lineHeight(24)
                .textAlign(TextAlign.Start)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.success_bg'))
            .borderRadius(10)

            // 解析（可选）
            if (this.card.analysis) {
              Column() {
                Text('解析')
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
                  .textAlign(TextAlign.Start)
                  .width('100%')
                  .margin({ bottom: 6 })
                Text(this.card.analysis)
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .lineHeight(20)
                  .textAlign(TextAlign.Start)
                  .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.warning_bg'))
              .borderRadius(10)
            }
          }
          .width('100%')
          .padding(16)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius(18)
    .shadow({ radius: 8, color: $r('app.color.shadow'), offsetX: 0, offsetY: 4 })
    .onClick(() => {
      this.isFlipped = true;
    })
  }
}
