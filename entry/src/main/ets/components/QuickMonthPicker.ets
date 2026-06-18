@CustomDialog
export struct QuickMonthPicker {
  controller: CustomDialogController;
  year: number = new Date().getFullYear();
  month: number = new Date().getMonth() + 1;
  confirm: (year: number, month: number) => void = (year: number, month: number) => {};

  build() {
    Column() {
      Text('选择月份')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 20, bottom: 16 })

      Row() {
        TextPicker({ range: this.getYearRange(), selected: this.getYearIndex() })
          .onChange((value: string | string[]) => {
            this.year = parseInt(value.toString());
          })
          .layoutWeight(1)

        TextPicker({ range: this.getMonthRange(), selected: this.month - 1 })
          .onChange((value: string | string[]) => {
            this.month = parseInt(value.toString());
          })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })

      Row() {
        Button('取消')
          .fontSize(14)
          .backgroundColor($r('app.color.transparent'))
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
          .onClick(() => {
            this.controller.close();
          })

        Button('确定')
          .fontSize(14)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .layoutWeight(1)
          .onClick(() => {
            this.confirm(this.year, this.month);
            this.controller.close();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 20 })
    }
    .width('100%')
  }

  private getYearRange(): string[] {
    const currentYear: number = new Date().getFullYear();
    const result: string[] = [];
    for (let i: number = currentYear - 10; i <= currentYear + 1; i++) {
      result.push(i.toString());
    }
    return result;
  }

  private getYearIndex(): number {
    const currentYear: number = new Date().getFullYear();
    return this.year - (currentYear - 10);
  }

  private getMonthRange(): string[] {
    const result: string[] = [];
    for (let i: number = 1; i <= 12; i++) {
      result.push(i.toString());
    }
    return result;
  }
}
