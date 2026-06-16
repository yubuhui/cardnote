import { Card, CardStatus } from '../model/Card';
import { CardType, CardType as CardTypeEnum } from '../model/CardTypeEnum';
import { Deck } from '../model/Deck';
import { CardViewModel } from '../viewmodel/CardViewModel';
import { extractBlankAnswers } from '../utils/FillBlankParser';

import { KeyboardAvoidMode } from '@kit.ArkUI';

class OptionItem {
  text: string = '';

  constructor(text: string) {
    this.text = text;
  }
}

@Entry
@Component
struct EditorPage {
  private cardId: number | null = null;
  @State card: Card | null = null;
  @State mode: string = '新增';
  @State frontText: string = '';
  @State backText: string = '';
  @State analysisText: string = '';
  @State selectedType: number = 0;
  @State selectedDeck: Deck | null = null;
  @State optionItems: OptionItem[] = [];
  @State selectedOptionIndexes: number[] = [];
  private cardVm: CardViewModel = new CardViewModel();
  private deckList: Deck[] = [];
  private frontTextController: TextAreaController = new TextAreaController();

  aboutToAppear() {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    if (params && params['cardId']) {
      this.cardId = params['cardId'] as number;
      this.mode = '编辑';
    }
    this.loadDecks();
    if (this.cardId) {
      this.loadCard();
    }
  }

  async loadDecks() {
    this.deckList = await this.cardVm.getAllDecks();
    if (this.deckList.length > 0) {
      this.selectedDeck = this.deckList[0];
    }
  }

  async loadCard() {
    if (this.cardId) {
      const c: Card | null = await this.cardVm.getById(this.cardId);
      if (c) {
        this.card = c;
        this.frontText = c.front;
        this.analysisText = c.analysis || '';
        this.selectedType = c.type;
        this.selectedDeck = await this.cardVm.getDeckById(c.deckId);
        if (c.type === CardTypeEnum.choice) {
          this.optionItems = [...c.options].map(text => new OptionItem(text));
          this.selectedOptionIndexes = c.correctAnswer
            ? c.correctAnswer.split(',').map(s => parseInt(s, 10)).filter(n => !isNaN(n))
            : [];
          this.backText = '';
        } else {
          this.backText = c.correctAnswer;
        }
      }
    }
  }

  build() {
    Column() {
      // 导航栏
      this.buildNavigationBar()

      // 滚动区
      Scroll() {
        Column({ space: 14 }) {
          this.buildDeckCard()
          this.buildTypeBar()
          this.buildFrontCard()
          this.buildAnswerSection()
          this.buildAnalysisCard()
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .align(Alignment.Top)
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .layoutWeight(1)

      // 底部栏
      this.buildBottomBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  // ==================== 导航栏 ====================
  @Builder
  buildNavigationBar() {
    Row() {
      // 圆形返回按钮
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

      Text(this.mode === '编辑' ? '编辑卡片' : '新增卡片')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 右侧占位，与左侧按钮等宽，保证标题居中
      Row()
        .width(36)
        .height(36)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 46, bottom: 12 })
    .backgroundColor($r('app.color.surface'))
  }

  // ==================== 牌组选择卡片 ====================
  @Builder
  buildDeckCard() {
    Column() {
      Row({ space: 8 }) {
        Text('所属牌组')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .fontWeight(FontWeight.Medium)
      }
      .margin({ bottom: 8 })

      Select(this.deckList.map((deck: Deck) => {
        const opt: SelectOption = { value: deck.name };
        return opt;
      }))
        .value(this.selectedDeck?.name)
        .selected(this.deckList.findIndex(d => d.id === this.selectedDeck?.id))
        .onSelect((index: number) => {
          this.selectedDeck = this.deckList[index];
        })
        .width('100%')
        .optionWidth(OptionWidthMode.FIT_TRIGGER)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(12)
        .border({ width: 1, color: $r('app.color.outline') })
        .padding({ left: 14, right: 14 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
    .shadow({ radius: 3, color: $r('app.color.shadow'), offsetY: 1 })
  }

  // ==================== 题型选择栏 ====================
  @Builder
  buildTypeBar() {
    Row({ space: 8 }) {
      this.buildTypeChip('问答题', 0)
      this.buildTypeChip('选择题', 1)
      this.buildTypeChip('填空题', 2)
    }
    .width('100%')
  }

  @Builder
  buildTypeChip(label: string, type: number) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(14)
        .fontWeight(this.selectedType === type ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selectedType === type ? $r('app.color.on_primary') : $r('app.color.text_secondary'))
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(this.selectedType === type ? $r('app.color.primary') : $r('app.color.surface'))
    .borderRadius(14)
    .border({ width: 1, color: this.selectedType === type ? $r('app.color.primary') : $r('app.color.outline') })
    .onClick(() => {
      this.selectedType = type;
    })
  }

  // ==================== 题干卡片 ====================
  @Builder
  buildFrontCard() {
    Column() {
      Row({ space: 6 }) {
        Text('问题（题干）')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)
      }
      .margin({ bottom: 10 })

      TextArea({ placeholder: '输入问题内容...', text: this.frontText, controller: this.frontTextController })
        .backgroundColor($r('app.color.surface'))
        .borderRadius(10)
        .border({ width: 1.5, color: $r('app.color.outline') })
        .height('auto')
        .constraintSize({ minHeight: 90 })
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.disabled'))
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .onChange((value: string) => {
          this.frontText = value;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
    .shadow({ radius: 3, color: $r('app.color.shadow'), offsetY: 1 })
  }

  // ==================== 答案区域 ====================
  @Builder
  buildAnswerSection() {
    if (this.selectedType === CardTypeEnum.choice) {
      this.buildChoiceCard()
    } else if (this.selectedType === CardTypeEnum.fillBlank) {
      this.buildFillBlankCard()
    } else {
      this.buildAnswerCard()
    }
  }

  // 问答题答案
  @Builder
  buildAnswerCard() {
    Column() {
      Row({ space: 6 }) {
        Text('答案')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)
      }
      .margin({ bottom: 10 })

      TextArea({ placeholder: '输入答案...', text: this.backText })
        .backgroundColor($r('app.color.surface'))
        .borderRadius(10)
        .border({ width: 1.5, color: $r('app.color.outline') })
        .height('auto')
        .constraintSize({ minHeight: 80 })
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.disabled'))
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .onChange((value: string) => {
          this.backText = value;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
    .shadow({ radius: 3, color: $r('app.color.shadow'), offsetY: 1 })
  }

  // 选择题编辑器
  @Builder
  buildChoiceCard() {
    Column() {
      Row({ space: 6 }) {
        Text('选项（勾选为正确答案）')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)

        Blank()

        if (this.selectedOptionIndexes.length > 0) {
          Text('已选 ' + this.selectedOptionIndexes.length.toString() + ' 项')
            .fontSize(11)
            .fontColor($r('app.color.primary'))
            .fontWeight(FontWeight.Medium)
        } else {
          Text('未选择答案')
            .fontSize(11)
            .fontColor($r('app.color.warning'))
        }
      }
      .width('100%')
      .margin({ bottom: 10 })

      ForEach(this.optionItems, (item: OptionItem, index: number) => {
        Row({ space: 10 }) {
          // 选项徽章 A/B/C/D（点击切换正确答案）
          Text(this.optionLabel(index))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.selectedOptionIndexes.includes(index) ? $r('app.color.on_primary') : $r('app.color.text_secondary'))
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.selectedOptionIndexes.includes(index) ? $r('app.color.primary') : $r('app.color.surface'))
            .borderRadius(16)
            .onClick(() => {
              const pos = this.selectedOptionIndexes.indexOf(index);
              if (pos >= 0) {
                this.selectedOptionIndexes.splice(pos, 1);
              } else {
                this.selectedOptionIndexes.push(index);
              }
            })

          // 选项文本 + 删除按钮（叠放，删除在右上角）
          Stack({ alignContent: Alignment.TopEnd }) {
            TextArea({ placeholder: `选项 ${this.optionLabel(index)}`, text: item.text })
              .width('100%')
              .backgroundColor($r('app.color.surface'))
              .borderRadius(10)
              .border({
                width: 1.5,
                color: this.selectedOptionIndexes.includes(index) ? $r('app.color.primary') : $r('app.color.outline')
              })
              .height('auto')
              .constraintSize({ minHeight: 44 })
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.disabled'))
              .padding({ left: 12, right: 30, top: 12, bottom: 12 })
              .onChange((value: string) => {
                this.optionItems[index].text = value;
              })

            Image($r('sys.symbol.xmark_circle_fill'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.disabled'))
              .margin({ top: 6, right: 6 })
              .onClick(() => {
                this.optionItems.splice(index, 1);
                this.selectedOptionIndexes = this.selectedOptionIndexes
                  .filter(i => i !== index)
                  .map(i => i > index ? i - 1 : i);
              })
          }
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ top: 6, bottom: 6 })
      }, (item: OptionItem, index: number) => index.toString())

      // 添加选项
      Button() {
        Row({ space: 6 }) {
          Image($r('sys.symbol.plus_circle'))
            .width(16)
            .height(16)
            .fillColor($r('app.color.primary'))
          Text('添加选项')
            .fontSize(13)
            .fontColor($r('app.color.primary'))
            .fontWeight(FontWeight.Medium)
        }
      }
      .width('100%')
      .height(44)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(10)
      .border({ width: 1.5, color: $r('app.color.primary'), style: BorderStyle.Dashed })
      .margin({ top: 4 })
      .onClick(() => {
        this.optionItems.push(new OptionItem(''));
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
    .shadow({ radius: 3, color: $r('app.color.shadow'), offsetY: 1 })
  }

  // 填空题提示卡片
  @Builder
  buildFillBlankCard() {
    Column() {
      Row({ space: 6 }) {
        Text('挖空标记')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .margin({ bottom: 10 })

      // 蓝色提示条
      Column() {
        Row({ space: 6 }) {
          Text('使用 [[答案]] 标记挖空位置')
            .fontSize(12)
            .fontColor($r('app.color.primary'))
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)

          Button('插入 [[ ]]')
            .fontSize(11)
            .fontColor($r('app.color.on_primary'))
            .backgroundColor($r('app.color.primary'))
            .borderRadius(8)
            .height(28)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              this.frontText += '[[]]';
              setTimeout(() => {
                this.frontTextController.caretPosition(this.frontText.length - 2);
              }, 50);
            })
        }
        .width('100%')

        Text('示例：我[[爱]]你 → 背诵时显示为「我▽你」')
          .fontSize(11)
          .fontColor($r('app.color.disabled'))
          .margin({ top: 6 })
      }
      .width('100%')
      .padding(14)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(12)
      .border({ width: 1, color: $r('app.color.outline') })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
    .shadow({ radius: 3, color: $r('app.color.shadow'), offsetY: 1 })
  }

  // ==================== 解析卡片 ====================
  @Builder
  buildAnalysisCard() {
    Column() {
      Row({ space: 6 }) {
        Text('解析（可选）')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)
      }
      .margin({ bottom: 10 })

      TextArea({ placeholder: '输入解析内容...', text: this.analysisText })
        .backgroundColor($r('app.color.surface'))
        .borderRadius(10)
        .border({ width: 1.5, color: $r('app.color.outline') })
        .height('auto')
        .constraintSize({ minHeight: 60 })
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.disabled'))
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .onChange((value: string) => {
          this.analysisText = value;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
    .shadow({ radius: 3, color: $r('app.color.shadow'), offsetY: 1 })
  }

  // ==================== 底部操作栏 ====================
  @Builder
  buildBottomBar() {
    Row({ space: 12 }) {
      if (this.card) {
        Button() {
          Row({ space: 6 }) {
            Text('删除')
              .fontSize(15)
              .fontColor($r('app.color.danger'))
              .fontWeight(FontWeight.Medium)
          }
        }
        .layoutWeight(1)
        .height(50)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(25)
        .border({ width: 1.5, color: $r('app.color.outline') })
        .shadow({ radius: 4, color: $r('app.color.shadow'), offsetY: 2 })
        .onClick(() => {
          this.getUIContext().showAlertDialog({
            title: '删除卡片',
            message: `确定要删除「${this.card!.front}」吗？删除后不可恢复。`,
            autoCancel: true,
            alignment: DialogAlignment.Center,
            primaryButton: {
              value: '取消',
              action: () => {}
            },
            secondaryButton: {
              value: '删除',
              fontColor: $r('app.color.danger'),
              action: async () => {
                await this.cardVm.deleteCard(this.card!.id);
                this.getUIContext().getRouter().back();
              }
            }
          });
        })
      }

      Button() {
        Row({ space: 6 }) {
          Text('保存')
            .fontSize(15)
            .fontColor($r('app.color.on_primary'))
            .fontWeight(FontWeight.Medium)
        }
      }
      .layoutWeight(1)
      .height(50)
      .backgroundColor($r('app.color.primary'))
      .borderRadius(25)
      .shadow({ radius: 8, color: $r('app.color.shadow'), offsetY: 4 })
      .onClick(() => {
        this.saveCard();
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 14 })
    .backgroundColor($r('app.color.background'))
  }

  private optionLabel(index: number): string {
    return String.fromCharCode(65 + index);
  }

  async saveCard() {
    if (!this.frontText) {
      this.getUIContext().getPromptAction().showToast({ message: '请输入问题（题干）' });
      return;
    }
    let correctAnswer = this.backText;
    let options: string[] = [];

    if (this.selectedType === CardTypeEnum.choice) {
      if (this.optionItems.length === 0 || this.selectedOptionIndexes.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '请添加选项并勾选正确答案' });
        return;
      }
      options = this.optionItems.map(item => item.text);
      correctAnswer = this.selectedOptionIndexes.join(',');
    } else if (this.selectedType === CardTypeEnum.fillBlank) {
      correctAnswer = extractBlankAnswers(this.frontText);
      if (!correctAnswer) {
        this.getUIContext().getPromptAction().showToast({ message: '请使用 [[答案]] 标记挖空位置' });
        return;
      }
    } else {
      if (!this.backText) {
        this.getUIContext().getPromptAction().showToast({ message: '请输入答案' });
        return;
      }
    }

    const now: number = Date.now();
    const card: Card = {
      id: this.card?.id || 0,
      deckId: this.selectedDeck?.id || 1,
      type: this.selectedType as CardType,
      front: this.frontText,
      options: options,
      correctAnswer: correctAnswer,
      displayOrder: [],
      analysis: this.analysisText,
      status: this.card?.status || CardStatus.unlearned,
      easeFactor: this.card?.easeFactor || 2.5,
      interval: this.card?.interval || 0,
      repetitions: this.card?.repetitions || 0,
      nextReviewTime: this.card?.nextReviewTime || now,
      createdAt: this.card?.createdAt || now,
      updatedAt: now,
    };
    if (this.card) {
      await this.cardVm.updateCard(card);
    } else {
      await this.cardVm.createCard(card);
    }
    this.getUIContext().getRouter().back();
  }
}
