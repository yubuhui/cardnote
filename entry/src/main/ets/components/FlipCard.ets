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
          .fontColor('#333')
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
                .fontColor('#999')
                .textAlign(TextAlign.Start)
                .width('100%')
                .margin({ bottom: 6 })
              Text(this.card.front)
                .fontSize(14)
                .fontColor('#666')
                .lineHeight(22)
                .textAlign(TextAlign.Start)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#F5F6FA')
            .borderRadius(10)

            // 答案
            Column() {
              Text('答案')
                .fontSize(11)
                .fontColor('#999')
                .textAlign(TextAlign.Start)
                .width('100%')
                .margin({ bottom: 6 })
              Text(this.card.correctAnswer)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333')
                .lineHeight(24)
                .textAlign(TextAlign.Start)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#E8F5E9')
            .borderRadius(10)

            // 解析（可选）
            if (this.card.analysis) {
              Column() {
                Text('解析')
                  .fontSize(11)
                  .fontColor('#999')
                  .textAlign(TextAlign.Start)
                  .width('100%')
                  .margin({ bottom: 6 })
                Text(this.card.analysis)
                  .fontSize(13)
                  .fontColor('#666')
                  .lineHeight(20)
                  .textAlign(TextAlign.Start)
                  .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFF8E1')
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
    .backgroundColor(Color.White)
    .borderRadius(18)
    .shadow({ radius: 8, color: '#10000000', offsetX: 0, offsetY: 4 })
    .onClick(() => {
      this.isFlipped = true;
    })
  }
}
