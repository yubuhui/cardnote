import { Card, CardType } from '../model/Card';
import { CardType as CardTypeEnum } from '../model/CardTypeEnum';

@Component
export struct QuizCard {
  @Prop card: Card;
  @Prop showResult: boolean;
  @State selectedOptions: string[] = [];
  @State showFeedback: boolean = false;

  aboutToAppear() {
    const correctIdxs = this.getCorrectOriginalIndices();
    this.selectedOptions = correctIdxs.map((n: number): string => n.toString());
  }

  build() {
    Column() {
      // 题干标签
      Text(`【${this.getTypeLabel()}】`)
        .fontSize(12)
        .fontColor('#999')
        .margin({ bottom: 8 })

      // 题干
      Text(this.card.front)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333')
        .textAlign(TextAlign.Start)
        .width('100%')
        .margin({ bottom: 16 })

      // 选项列表（按 displayOrder 顺序显示）
      Column() {
        ForEach(this.getOrderedOptions(), (option: string, displayIdx: number) => {
          Button(option)
            .width('100%')
            .textAlign(TextAlign.Start)
            .fontSize(13)
            .borderRadius(8)
            .backgroundColor(this.getOptionColor(displayIdx))
            .fontColor(this.getOptionTextColor(displayIdx))
            .onClick(() => {
              this.toggleOption(displayIdx);
            })
            .margin({ bottom: 6 })
        }, (option: string, displayIdx: number): string => `${this.card.id}_${displayIdx}`)
      }
      .width('100%')

      // 对错反馈
      if (this.showResult && this.showFeedback) {
        Column() {
          Text(this.getFeedbackText())
            .fontSize(12)
            .fontColor(this.isCorrect() ? '#27AE60' : '#E74C3C')
            .backgroundColor(this.isCorrect() ? '#E8F5E9' : '#FDEDEC')
            .borderRadius(8)
            .padding(8)
            .width('100%')
            .textAlign(TextAlign.Center)

          if (this.card.analysis) {
            Text(`解析：${this.card.analysis}`)
              .fontSize(12)
              .fontColor('#666')
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .padding(8)
              .width('100%')
              .margin({ top: 6 })
          }
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(18)
    .shadow({ radius: 8, color: '#10000000', offsetX: 0, offsetY: 4 })
  }

  private getTypeLabel(): string {
    switch (this.card.type) {
      case CardTypeEnum.choice: return '选择题';
      case CardTypeEnum.fillBlank: return '填空题';
      default: return '问答题';
    }
  }

  private getCorrectOriginalIndices(): number[] {
    if (!this.card.correctAnswer || this.card.correctAnswer.trim() === '') {
      return [];
    }
    const parts: string[] = this.card.correctAnswer.split(',');
    const result: number[] = [];
    for (let i = 0; i < parts.length; i++) {
      const n: number = parseInt(parts[i].trim());
      if (!isNaN(n)) {
        result.push(n);
      }
    }
    return result;
  }

  /** 显示位置 displayIdx 对应的原始索引 */
  private getOriginalIndex(displayIdx: number): number {
    const displayOrder: number[] = this.card.displayOrder;
    if (displayOrder && displayOrder.length > 0 && displayIdx < displayOrder.length) {
      return displayOrder[displayIdx];
    }
    return displayIdx;
  }

  /** 显示位置 displayIdx 是否是正确答案 */
  private isOptionCorrect(displayIdx: number): boolean {
    const originalIdx: number = this.getOriginalIndex(displayIdx);
    const correctIndices: number[] = this.getCorrectOriginalIndices();
    for (let i = 0; i < correctIndices.length; i++) {
      if (correctIndices[i] === originalIdx) {
        return true;
      }
    }
    return false;
  }

  /** 是否多选题（正确答案 2 个及以上） */
  private isMultiCorrect(): boolean {
    return this.getCorrectOriginalIndices().length >= 2;
  }

  private getOptionColor(displayIdx: number): string {
    if (!this.showResult) {
      return '#FFFFFF';
    }
    const selectedOrigIdx: number = this.getOriginalIndex(displayIdx);
    const isSelected: boolean = this.selectedOptions.indexOf(selectedOrigIdx.toString()) >= 0;
    const isCorrect: boolean = this.isOptionCorrect(displayIdx);
    if (isSelected && isCorrect) {
      return '#E8F5E9'; // 选对 → 绿
    }
    if (isSelected && !isCorrect) {
      return '#FDEDEC'; // 选错 → 红
    }
    if (!isSelected && isCorrect) {
      if (this.isMultiCorrect()) {
        return '#FFF8E1'; // 多选题漏选 → 黄
      }
      return '#E8F5E9'; // 单选正确（未被选中情况极少）
    }
    return '#FFFFFF';
  }

  private getOptionTextColor(displayIdx: number): string {
    if (!this.showResult) {
      return '#333';
    }
    const selectedOrigIdx: number = this.getOriginalIndex(displayIdx);
    const isSelected: boolean = this.selectedOptions.indexOf(selectedOrigIdx.toString()) >= 0;
    const isCorrect: boolean = this.isOptionCorrect(displayIdx);
    if (isSelected && !isCorrect) {
      return '#E74C3C';
    }
    return '#333';
  }

  private getFeedbackText(): string {
    return this.isCorrect() ? '✅ 正确！' : '❌ 错误！';
  }

  private isCorrect(): boolean {
    const correctIndices: number[] = this.getCorrectOriginalIndices();
    if (correctIndices.length === 0 || this.selectedOptions.length === 0) {
      return false;
    }
    if (this.selectedOptions.length !== correctIndices.length) {
      return false;
    }
    for (let i = 0; i < correctIndices.length; i++) {
      if (this.selectedOptions.indexOf(correctIndices[i].toString()) < 0) {
        return false;
      }
    }
    return true;
  }

  private getOrderedOptions(): string[] {
    const options: string[] = this.card.options || [];
    const displayOrder: number[] = this.card.displayOrder;
    if (!displayOrder || displayOrder.length === 0) {
      return options;
    }
    const ordered: string[] = [];
    for (let i = 0; i < displayOrder.length; i++) {
      const origIdx: number = displayOrder[i];
      if (origIdx < options.length) {
        ordered.push(options[origIdx]);
      }
    }
    return ordered;
  }

  private toggleOption(displayIdx: number) {
    const originalIdx: number = this.getOriginalIndex(displayIdx);
    const idxStr: string = originalIdx.toString();
    const pos: number = this.selectedOptions.indexOf(idxStr);
    if (pos >= 0) {
      this.selectedOptions.splice(pos, 1);
    } else {
      this.selectedOptions.push(idxStr);
    }
  }
}
