import { Card, CardStatus } from '../model/Card';
import { Deck } from '../model/Deck';
import { StudyViewModel } from '../viewmodel/StudyViewModel';
import { RatingButtons } from '../components/RatingButtons';
import { Rating } from '../data/SM2Algorithm';
import { CardType as CardTypeEnum } from '../model/CardTypeEnum';
import { parseFillBlanks, TextSegment } from '../utils/FillBlankParser';
import { shuffleFisherYates } from '../utils/ArrayUtils';

@Entry
@Component
struct LearningPage {
  @State dueCards: Card[] = [];
  @State currentIndex: number = 0;
  @State showAnswer: boolean = false;
  @State showRating: boolean = false;
  @State selectedChoiceIndex: number = -1;  // 选择题中用户选中的选项序号
  @State studyViewModel: StudyViewModel = new StudyViewModel();
  @State currentCard: Card | null = null;
  @State currentDeck: Deck | null = null;
  @State showMenu: boolean = false;
  @State lastRatedCardSnapshot: Card | null = null;
  @State canUndo: boolean = false;
  @StorageLink('isForeground') isForeground: boolean = true;
  private timerId: number = -1;
  private cardActiveSeconds: number = 0;
  private lastInteractionTime: number = 0;

  aboutToAppear() {
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    const deckId: number = (params && params['selectedDeckId'] !== undefined)
      ? (params['selectedDeckId'] as number) : 0;
    // selectedDeckId === 0 表示"全部牌组"，传 undefined 给后端
    const deckIds: number[] | undefined = (deckId > 0) ? [deckId] : undefined;
    this.loadDueCards(deckIds);
  }

  aboutToDisappear() {
    this.stopCardTimer();
  }

  async loadDueCards(deckIds?: number[]) {
    try {
      this.dueCards = await this.studyViewModel.getDueCards(deckIds);
      // 选择题 → 生成乱序 displayOrder
      for (let i = 0; i < this.dueCards.length; i++) {
        if (this.dueCards[i].type === CardTypeEnum.choice) {
          this.ensureDisplayOrderShuffled(this.dueCards[i]);
        }
      }
      if (this.dueCards.length > 0) {
        this.currentIndex = 0;
        this.currentCard = this.dueCards[0];
        this.currentDeck = await this.studyViewModel.getDeckById(this.currentCard.deckId);
        this.startCardTimer();
      }
    } catch (err) {
      console.error('Load due cards failed:', err);
    }
  }

  /** 选择题 → 每次都重新乱序，保证每次学习选项顺序不同 */
  private ensureDisplayOrderShuffled(card: Card): void {
    const opts: string[] = card.options || [];
    if (opts.length < 2) {
      return;
    }
    const order: number[] = [];
    for (let i = 0; i < opts.length; i++) {
      order.push(i);
    }
    card.displayOrder = shuffleFisherYates(order);
  }

  build() {
    Column() {
      // 顶部导航
      this.buildHeader()

      // 进度条
      this.buildProgressBar()

      // 卡片区域
      if (this.currentCard) {
        Column() {
          this.buildCardArea()
        }
        .layoutWeight(1)
        .width('100%')
        .onTouch(() => { this.onUserInteraction() })
      } else {
        // 空状态
        Column({ space: 12 }) {
          Text('🎉')
            .fontSize(48)
          Text('暂无待复习卡片')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      // 查看答案按钮
      if (this.currentCard && !this.showRating) {
        this.buildShowAnswerButton()
      }

      // 评分按钮
      if (this.showRating && this.currentCard) {
        RatingButtons({
          visible: true,
          onForget: (): void => { this.handleRating(Rating.forget); },
          onHard: (): void => { this.handleRating(Rating.hard); },
          onGood: (): void => { this.handleRating(Rating.good); },
          onEasy: (): void => { this.handleRating(Rating.easy); },
        })
        .width('100%')
        .margin({ bottom: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  buildHeader() {
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
      .backgroundColor($r('app.color.surface'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.getUIContext().getRouter().back();
      })
      if (this.currentDeck) {
        Text(this.currentDeck.name)
          .fontSize(16)
          .fontColor($r('app.color.primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      } else {
        Row().layoutWeight(1)
      }
      Text('⋮')
        .fontSize(18)
        .fontColor($r('app.color.text_secondary'))
        .padding({ left: 4, right: 4 })
        .onClick(() => {
          this.showMenu = !this.showMenu;
        })
        .bindPopup(this.showMenu, {
          builder: this.buildDropdownMenu,
          placement: Placement.BottomRight,
          maskColor: $r('app.color.transparent'),
          popupColor: $r('app.color.surface'),
          enableArrow: false,
          radius: 10,
          onStateChange: (e) => {
            if (!e.isVisible) {
              this.showMenu = false;
            }
          }
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 18, right: 18, top: 46, bottom: 10 })
    .backgroundColor($r('app.color.surface'))
  }

  @Builder
  buildDropdownMenu() {
    Column() {
      if (this.canUndo) {
        Row() {
          Text('撤销回答')
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .onClick(() => {
          this.showMenu = false;
          this.undoLastAnswer();
        })

        Divider()
          .height(1)
          .color($r('app.color.outline'))
          .margin({ left: 14, right: 14 })
      }

      Row() {
        Text('编辑卡片')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .onClick(() => {
        this.showMenu = false;
        this.goToEditCard();
      })
    }
    .width(140)
    .padding({ top: 4, bottom: 4 })
  }

  goToEditCard() {
    if (this.currentCard) {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/EditorPage',
        params: { cardId: this.currentCard.id }
      });
    }
  }

  @Builder
  buildProgressBar() {
    Row() {
      Row()
        .width(`${((this.currentIndex + 1) / Math.max(this.dueCards.length, 1)) * 100}%`)
        .height(3)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(2)
    }
    .width('100%')
    .height(3)
    .backgroundColor($r('app.color.outline'))
  }

  @Builder
  buildCardArea() {
    if (this.currentCard && this.currentCard.type === CardTypeEnum.essay) {
      // 问答题
      Column({ space: 12 }) {
        // 问题
        Column() {
          Text('问题')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Start)
            .width('100%')
            .margin({ bottom: 6 })
          Text(this.currentCard.front)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(24)
            .textAlign(TextAlign.Start)
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.background'))
        .borderRadius(10)
        .flexShrink(0)

        if (this.showAnswer) {
          // 答案
          Column() {
            Text('答案')
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Start)
              .width('100%')
              .margin({ bottom: 6 })
            Text(this.currentCard.correctAnswer)
              .fontSize(15)
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
          .flexShrink(0)

          // 解析（可选）
          if (this.currentCard.analysis) {
            Column() {
              Text('解析')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Start)
                .width('100%')
                .margin({ bottom: 6 })
              Text(this.currentCard.analysis)
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
            .flexShrink(0)
          }
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(18)
      .shadow({ radius: 8, color: $r('app.color.shadow'), offsetX: 0, offsetY: 4 })
      .margin({ top: 16, bottom: 12 })
      .constraintSize({ maxHeight: 420 })
    } else if (this.currentCard && this.currentCard.type === CardTypeEnum.fillBlank) {
      // 填空题
      this.buildFillBlankCard()
    } else if (this.currentCard && this.currentCard.type === CardTypeEnum.choice) {
      // 选择题
      this.buildChoiceCard()
    }
  }

  @Builder
  buildFillBlankCard() {
    Column({ space: 12 }) {
      // 题干（含挖空）
      Column() {
        Text('填空题')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Start)
          .width('100%')
          .margin({ bottom: 6 })
        // 渲染带挖空的文本
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(
            parseFillBlanks(this.currentCard!.front),
            (seg: TextSegment, index: number) => {
              if (seg.isBlank) {
                Text(this.showAnswer ? seg.text : '□')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.showAnswer ? $r('app.color.primary') : $r('app.color.text_primary'))
                  .backgroundColor(this.showAnswer ? $r('app.color.surface') : $r('app.color.surface'))
                  .borderRadius(4)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .margin({ left: 2, right: 2 })
              } else {
                Text(seg.text)
                  .fontSize(15)
                  .fontColor($r('app.color.text_primary'))
                  .lineHeight(24)
              }
            },
            (_: TextSegment, index: number): string => index.toString()
          )
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.background'))
      .borderRadius(10)
      .flexShrink(0)

      if (this.showAnswer) {
        // 正确答案提示
        Column() {
          Text('答案')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Start)
            .width('100%')
            .margin({ bottom: 6 })
          Text(this.currentCard!.correctAnswer)
            .fontSize(15)
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
        .flexShrink(0)

        // 解析（可选）
        if (this.currentCard!.analysis) {
          Column() {
            Text('解析')
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Start)
              .width('100%')
              .margin({ bottom: 6 })
            Text(this.currentCard!.analysis)
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
          .flexShrink(0)
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(18)
    .shadow({ radius: 8, color: $r('app.color.shadow'), offsetX: 0, offsetY: 4 })
    .margin({ top: 16, bottom: 12 })
    .constraintSize({ maxHeight: 420 })
  }

  @Builder
  buildChoiceCard() {
    Column({ space: 12 }) {
      // 题干
      Column() {
        Text('选择题')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Start)
          .width('100%')
          .margin({ bottom: 6 })
        Text(this.currentCard!.front)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(24)
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.background'))
      .borderRadius(10)
      .flexShrink(0)

      // 选项列表（按 displayOrder 打乱）
      Column({ space: 8 }) {
        ForEach(this.getOrderedOptions(), (opt: string, idx: number) => {
          this.buildChoiceOption(opt, idx)
        }, (opt: string, idx: number): string => `${this.currentCard!.id}_${idx}`)
      }
      .width('100%')

      if (this.showAnswer) {
        // 解析（可选）
        if (this.currentCard!.analysis) {
          Column() {
            Text('解析')
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Start)
              .width('100%')
              .margin({ bottom: 6 })
            Text(this.currentCard!.analysis)
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
          .flexShrink(0)
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(18)
    .shadow({ radius: 8, color: $r('app.color.shadow'), offsetX: 0, offsetY: 4 })
    .margin({ top: 16, bottom: 12 })
    .constraintSize({ maxHeight: 480 })
  }

  /** 按 displayOrder 排序的选项数组 */
  private getOrderedOptions(): string[] {
    const card: Card = this.currentCard!;
    if (!card.displayOrder || card.displayOrder.length === 0) {
      return card.options || [];
    }
    const ordered: string[] = [];
    for (let i = 0; i < card.displayOrder.length; i++) {
      const originalIdx: number = card.displayOrder[i];
      if (originalIdx < card.options.length) {
        ordered.push(card.options[originalIdx]);
      }
    }
    return ordered;
  }

  /** 选择题 → 正确答案的原始索引数组 */
  private getChoiceCorrectIndices(): number[] {
    const ca: string = this.currentCard!.correctAnswer;
    if (!ca || ca.trim().length === 0) {
      return [];
    }
    const result: number[] = [];
    const parts: string[] = ca.split(',');
    for (let i = 0; i < parts.length; i++) {
      const n: number = parseInt(parts[i].trim());
      if (!isNaN(n)) {
        result.push(n);
      }
    }
    return result;
  }

  /** 选择题 → 显示在 idx 位置的选项是否是正确答案 */
  private isChoiceOptionCorrect(idx: number): boolean {
    const displayOrder: number[] = this.currentCard!.displayOrder;
    let originalIdx: number = idx;
    if (displayOrder && displayOrder.length > 0 && idx < displayOrder.length) {
      originalIdx = displayOrder[idx];
    }
    const correctIndices: number[] = this.getChoiceCorrectIndices();
    for (let i = 0; i < correctIndices.length; i++) {
      if (correctIndices[i] === originalIdx) {
        return true;
      }
    }
    return false;
  }

  /** 选择题 → 正确答案的显示文本 */
  private getChoiceCorrectDisplayText(): string {
    const card: Card = this.currentCard!;
    const correctIndices: number[] = this.getChoiceCorrectIndices();
    if (correctIndices.length === 0) {
      return card.correctAnswer; // 非索引格式直接返回原文
    }
    const options: string[] = card.options || [];
    const texts: string[] = [];
    for (let i = 0; i < correctIndices.length; i++) {
      const origIdx: number = correctIndices[i];
      if (origIdx < options.length) {
        texts.push(options[origIdx]);
      }
    }
    return texts.length > 0 ? texts.join('；') : card.correctAnswer;
  }

  /** 选择题 → 当前选中项是否答对 */
  private isSelectedChoiceCorrect(): boolean {
    if (this.selectedChoiceIndex < 0) {
      return false;
    }
    const displayOrder: number[] = this.currentCard!.displayOrder;
    let selectedOrigIdx: number = this.selectedChoiceIndex;
    if (displayOrder && displayOrder.length > 0 && this.selectedChoiceIndex < displayOrder.length) {
      selectedOrigIdx = displayOrder[this.selectedChoiceIndex];
    }
    const correctIndices: number[] = this.getChoiceCorrectIndices();
    for (let i = 0; i < correctIndices.length; i++) {
      if (correctIndices[i] === selectedOrigIdx) {
        return true;
      }
    }
    return false;
  }

  /** 选择题 → 是否多选题（正确答案 2 个及以上） */
  private isMultiCorrectChoice(): boolean {
    return this.getChoiceCorrectIndices().length >= 2;
  }

  /** 选择题 → 选项背景色 */
  private getChoiceOptionBgColor(idx: number): ResourceColor {
    if (!this.showAnswer) {
      return idx === this.selectedChoiceIndex ? $r('app.color.surface') : $r('app.color.surface');
    }
    const isCorrect: boolean = this.isChoiceOptionCorrect(idx);
    const isSelected: boolean = idx === this.selectedChoiceIndex;

    if (isSelected && isCorrect) {
      return $r('app.color.success_bg'); // 选对 → 绿
    }
    if (isSelected && !isCorrect) {
      return $r('app.color.danger_bg'); // 选错 → 红
    }
    if (!isSelected && isCorrect) {
      if (this.isMultiCorrectChoice()) {
        return $r('app.color.warning_bg'); // 多选题漏选 → 黄
      }
      return $r('app.color.success_bg'); // 单选正确但未选中（不可能），保持绿
    }
    return $r('app.color.surface'); // 无关选项
  }

  /** 选择题 → 选项边框颜色 */
  private getChoiceOptionBorderColor(idx: number): ResourceColor {
    if (!this.showAnswer) {
      return idx === this.selectedChoiceIndex ? $r('app.color.primary') : $r('app.color.outline');
    }
    const isCorrect: boolean = this.isChoiceOptionCorrect(idx);
    const isSelected: boolean = idx === this.selectedChoiceIndex;

    if (isSelected && isCorrect) {
      return $r('app.color.outline'); // 选对 → 绿边框
    }
    if (isSelected && !isCorrect) {
      return $r('app.color.danger'); // 选错 → 红边框
    }
    if (!isSelected && isCorrect) {
      if (this.isMultiCorrectChoice()) {
        return $r('app.color.warning'); // 多选题漏选 → 黄边框
      }
      return $r('app.color.outline'); // 单选正确 → 绿边框
    }
    return $r('app.color.outline');
  }

  /** 选择题 → 选项边框宽度 */
  private getChoiceOptionBorderWidth(idx: number): number {
    if (!this.showAnswer) {
      return idx === this.selectedChoiceIndex ? 1.5 : 0.5;
    }
    const isCorrect: boolean = this.isChoiceOptionCorrect(idx);
    const isSelected: boolean = idx === this.selectedChoiceIndex;
    if (isSelected || isCorrect) {
      return 1.5;
    }
    return 0.5;
  }
  @Builder
  buildChoiceOption(opt: string, idx: number) {
    Row() {
      Text(String.fromCharCode(65 + idx) + '.')
        .fontSize(13)
        .fontColor(idx === this.selectedChoiceIndex ? $r('app.color.primary') : $r('app.color.text_secondary'))
        .fontWeight(idx === this.selectedChoiceIndex ? FontWeight.Bold : FontWeight.Normal)
        .width(28)
        .textAlign(TextAlign.Start)

      Text(opt)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .borderRadius(8)
    .border({
      width: this.getChoiceOptionBorderWidth(idx),
      color: this.getChoiceOptionBorderColor(idx)
    })
    .backgroundColor(this.getChoiceOptionBgColor(idx))
    .onClick(() => {
      if (!this.showAnswer) {
        this.onUserInteraction();
        // 再点一次取消选中
        this.selectedChoiceIndex = (this.selectedChoiceIndex === idx) ? -1 : idx;
      }
    })
  }

  @Builder
  buildShowAnswerButton() {
    Column() {
      Button('查看答案')
        .width('80%')
        .height(48)
        .backgroundColor($r('app.color.primary'))
        .fontColor($r('app.color.on_primary'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .borderRadius(10)
        .onClick(() => {
          this.onUserInteraction();
          this.showAnswer = true;
          this.showRating = true;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
    .margin({ bottom: 12 })
  }

  // ====== 学习计时器 ======

  private startCardTimer(): void {
    this.stopCardTimer();
    this.cardActiveSeconds = 0;
    this.lastInteractionTime = Date.now();
    this.timerId = setInterval(() => { this.timerTick() }, 1000);
  }

  private stopCardTimer(): number {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    return this.cardActiveSeconds;
  }

  private timerTick(): void {
    if (!this.isForeground) {
      return;
    }
    const now: number = Date.now();
    if (now - this.lastInteractionTime > 60000) {
      return; // 1分钟以上无交互，暂停累计
    }
    this.cardActiveSeconds++;
  }

  private onUserInteraction(): void {
    this.lastInteractionTime = Date.now();
  }

  // 处理评分
  async handleRating(rating: Rating) {
    if (!this.currentCard) {
      return;
    }
    this.onUserInteraction();
    const duration: number = this.stopCardTimer();
    // 保存评分前卡片快照（用于撤销）
    this.saveCardSnapshot(this.currentCard);
    try {
      await this.studyViewModel.recordRating(this.currentCard.id, rating, duration);
      this.canUndo = true;
      this.nextCard();
    } catch (err) {
      console.error('Record rating failed:', JSON.stringify(err));
      // 恢复计时器（让用户可以重试）
      this.startCardTimer();
    }
  }

  // 保存卡片快照
  saveCardSnapshot(card: Card) {
    this.lastRatedCardSnapshot = {
      id: card.id,
      deckId: card.deckId,
      type: card.type,
      front: card.front,
      options: [...card.options],
      correctAnswer: card.correctAnswer,
      displayOrder: [...card.displayOrder],
      analysis: card.analysis,
      status: card.status,
      easeFactor: card.easeFactor,
      interval: card.interval,
      repetitions: card.repetitions,
      nextReviewTime: card.nextReviewTime,
      createdAt: card.createdAt,
      updatedAt: card.updatedAt,
    };
  }

  // 撤销上一次回答
  async undoLastAnswer() {
    if (!this.lastRatedCardSnapshot || this.currentIndex <= 0) {
      return;
    }
    // 恢复卡片到评分前状态
    await this.studyViewModel.undoRating(
      this.lastRatedCardSnapshot.id,
      this.lastRatedCardSnapshot
    );
    // 回到上一张卡片
    this.currentIndex -= 1;
    this.currentCard = this.dueCards[this.currentIndex];
    await this.updateCurrentDeck();
    this.showAnswer = false;
    this.showRating = false;
    this.selectedChoiceIndex = -1;
    this.canUndo = false;
    this.lastRatedCardSnapshot = null;
  }

  nextCard() {
    this.currentIndex++;
    if (this.currentIndex < this.dueCards.length) {
      this.currentCard = this.dueCards[this.currentIndex];
      this.updateCurrentDeck();
      this.showAnswer = false;
      this.showRating = false;
      this.selectedChoiceIndex = -1;
      this.startCardTimer();
    } else {
      // 学习完成
      this.currentCard = null;
      this.currentDeck = null;
      this.showAnswer = false;
      this.showRating = false;
      this.stopCardTimer();
    }
  }

  async updateCurrentDeck() {
    if (this.currentCard) {
      this.currentDeck = await this.studyViewModel.getDeckById(this.currentCard.deckId);
    }
  }
}
