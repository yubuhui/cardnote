
@Component
export struct RatingButtons {
  @Prop visible: boolean = false;

  // 回调函数
  onForget?: () => void;
  onHard?: () => void;
  onGood?: () => void;
  onEasy?: () => void;

  build() {
    Row() {
      this.buildButton('忘记', '1 分钟', 0, $r('app.color.danger'));
      this.buildButton('困难', '10 分钟', 1, $r('app.color.warning'));
      this.buildButton('良好', '1 天', 2, $r('app.color.success'));
      this.buildButton('容易', '4 天', 3, $r('app.color.success'));
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceAround)
    .backgroundColor($r('app.color.surface'))
    .padding({ top: 12, bottom: 12 })
    .border({ width: { top: 1 }, color: $r('app.color.outline') })
  }

  @Builder
  buildButton(label: string, interval: string, rating: number, color: ResourceColor) {
    Column() {
      Text(label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.on_primary'))
      Text(interval)
        .fontSize(9)
        .fontColor($r('app.color.on_primary'))
        .fontWeight(FontWeight.Normal)
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(color)
    .borderRadius(10)
    .margin({ left: 4, right: 4 })
    .onClick(() => {
      this.handleRating(rating);
    })
    .stateStyles({
      pressed: {
        .scale({ x: 0.95, y: 0.95 })
        .brightness(0.85)
      },
      normal: {
        .scale({ x: 1, y: 1 })
        .brightness(1)
      }
    })
  }

  private handleRating(rating: number) {
    switch (rating) {
      case 0:
        if (this.onForget) this.onForget();
        break;
      case 1:
        if (this.onHard) this.onHard();
        break;
      case 2:
        if (this.onGood) this.onGood();
        break;
      case 3:
        if (this.onEasy) this.onEasy();
        break;
    }
  }
}
