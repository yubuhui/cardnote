
@Component
export struct RatingButtons {
  @Prop visible: boolean = false;
  @State forgetPressed: boolean = false;
  @State hardPressed: boolean = false;
  @State goodPressed: boolean = false;
  @State easyPressed: boolean = false;

  // 回调函数
  onForget?: () => void;
  onHard?: () => void;
  onGood?: () => void;
  onEasy?: () => void;

  build() {
    Row() {
      this.buildButton('忘记', '1 分钟', 0, $r('app.color.danger'), this.forgetPressed);
      this.buildButton('困难', '10 分钟', 1, $r('app.color.warning'), this.hardPressed);
      this.buildButton('良好', '1 天', 2, $r('app.color.success'), this.goodPressed);
      this.buildButton('容易', '4 天', 3, $r('app.color.success'), this.easyPressed);
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceAround)
    .backgroundColor($r('app.color.surface'))
    .padding({ top: 12, bottom: 12 })
    .border({ width: { top: 1 }, color: $r('app.color.outline') })
  }

  @Builder
  buildButton(label: string, interval: string, rating: number, color: ResourceColor, isPressed: boolean) {
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
    .scale({
      x: isPressed ? 0.95 : 1,
      y: isPressed ? 0.95 : 1,
    })
    .transition(TransitionEffect.OPACITY.animation({ duration: 100 }))
  }

  private handleRating(rating: number) {
    switch (rating) {
      case 0:
        this.forgetPressed = true;
        if (this.onForget) this.onForget();
        setTimeout(() => { this.forgetPressed = false; }, 100);
        break;
      case 1:
        this.hardPressed = true;
        if (this.onHard) this.onHard();
        setTimeout(() => { this.hardPressed = false; }, 100);
        break;
      case 2:
        this.goodPressed = true;
        if (this.onGood) this.onGood();
        setTimeout(() => { this.goodPressed = false; }, 100);
        break;
      case 3:
        this.easyPressed = true;
        if (this.onEasy) this.onEasy();
        setTimeout(() => { this.easyPressed = false; }, 100);
        break;
    }
  }
}
