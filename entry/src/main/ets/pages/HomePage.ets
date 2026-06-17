import { Card, CardStatus } from '../model/Card';
import { Deck } from '../model/Deck';
import { CardViewModel } from '../viewmodel/CardViewModel';
import { StudyViewModel } from '../viewmodel/StudyViewModel';
import { MemoryRecordDao } from '../data/MemoryRecordDao';
import { StatsPage } from './StatsPage';
import { SettingsPage } from './SettingsPage';
import { HdsTabs, hdsMaterial } from '@kit.UIDesignKit';

const DECK_COLORS: string[] = ['#4A90D9', '#E85D75', '#50C878', '#FFB347', '#9B59B6', '#1ABC9C'];

interface CardSectionParams {
  title: string;
  circleColor: ResourceColor;
  status: CardStatus;
  isOpen: boolean;
  section: string;
}

// ==================== 卡片列表项组件 ====================
@Component
struct CardItem {
  @Prop cardId: number = 0;
  @Prop cardFront: string = '';
  @Prop nextReviewTime: number = 0;
  @Prop isMultiSelect: boolean = false;
  @Prop isSelected: boolean = false;
  onTap: () => void = () => {};
  onLongPress: () => void = () => {};

  private formatNextReviewTime(timestamp: number): string {
    const now: Date = new Date();
    const todayStart: number = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const todayEnd: number = todayStart + 24 * 60 * 60 * 1000;
    if (timestamp >= todayStart && timestamp < todayEnd) {
      return '今天';
    }
    const date: Date = new Date(timestamp);
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    return month.toString() + '月' + day.toString() + '日';
  }

  build() {
    Row() {
      if (this.isMultiSelect) {
        Checkbox()
          .select(this.isSelected)
          .hitTestBehavior(HitTestMode.None)
      }
      Row() {
        Text(this.cardFront)
          .fontSize(14)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Blank().width(8)
        Text(this.formatNextReviewTime(this.nextReviewTime))
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor($r('app.color.surface'))
          .borderRadius(4)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(10)
    .shadow({ radius: 3, color: $r('app.color.shadow'), offsetY: 1 })
    .margin({ bottom: 6 })
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        LongPressGesture({ repeat: false, duration: 400 })
          .onAction(() => { this.onLongPress(); }),
        TapGesture()
          .onAction(() => { this.onTap(); })
      )
    )
  }
}

@CustomDialog
struct AddDeckDialog {
  controller?: CustomDialogController;
  onConfirm: (name: string) => void = () => {};
  @State inputName: string = '';

  build() {
    Column() {
      Text('新建牌组').fontSize(18).fontWeight(FontWeight.Medium).margin({ bottom: 16 })
      TextInput({ placeholder: '请输入牌组名称', text: this.inputName })
        .onChange((value: string) => { this.inputName = value; })
        .width('100%').margin({ bottom: 20 })
      Row({ space: 12 }) {
        Button('取消').fontSize(14).backgroundColor($r('app.color.surface')).fontColor($r('app.color.text_secondary')).layoutWeight(1)
          .onClick(() => { this.controller?.close(); })
        Button('确定').fontSize(14).backgroundColor($r('app.color.primary')).fontColor($r('app.color.on_primary')).layoutWeight(1)
          .onClick(() => {
            if (this.inputName.trim()) {
              this.onConfirm(this.inputName.trim());
            }
            this.controller?.close();
          })
      }.width('100%')
    }.padding(20)
  }
}

@CustomDialog
struct DeckSettingsDialog {
  controller?: CustomDialogController;
  onSave: (newLimit: number, reviewLimit: number, deckId: number) => void = () => {};
  @Prop deckId: number = 0;
  @Prop deckName: string = '';
  @State newCardsPerDay: number = 20;
  @State reviewCardsPerDay: number = 100;

  build() {
    Column() {
      Text(`${this.deckName} 设置`)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 20 })

      // 每日新卡
      Column() {
        Row() {
          Text('每日新卡')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text(`${this.newCardsPerDay}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary'))
        }
        .width('100%')
        .margin({ bottom: 8 })

        Row({ space: 6 }) {
          Text('5')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
          Slider({ value: this.newCardsPerDay, min: 5, max: 100, step: 5 })
            .onChange((value: number) => { this.newCardsPerDay = value; })
            .layoutWeight(1)
          Text('100')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
      }
      .width('100%')
      .padding({ bottom: 12 })

      Divider()
        .width('100%')
        .strokeWidth(0.5)
        .color($r('app.color.outline'))
        .margin({ top: 4, bottom: 12 })

      // 每日复习
      Column() {
        Row() {
          Text('每日复习')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text(`${this.reviewCardsPerDay}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary'))
        }
        .width('100%')
        .margin({ bottom: 8 })

        Row({ space: 6 }) {
          Text('50')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
          Slider({ value: this.reviewCardsPerDay, min: 50, max: 1000, step: 50 })
            .onChange((value: number) => { this.reviewCardsPerDay = value; })
            .layoutWeight(1)
          Text('1000')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
      }
      .width('100%')

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(14)
          .height(40)
          .backgroundColor($r('app.color.surface'))
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
          .onClick(() => { this.controller?.close(); })
        Button('确定')
          .fontSize(14)
          .height(40)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .layoutWeight(1)
          .onClick(() => {
            this.onSave(this.newCardsPerDay, this.reviewCardsPerDay, this.deckId);
            this.controller?.close();
          })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .padding(20)
    .width('100%')
  }
}

@CustomDialog
struct MoveToDeckDialog {
  controller?: CustomDialogController;
  @Prop decks: Deck[] = [];
  onMoveToDeck: (deckIds: number[]) => void = () => {};
  @State selectedDeckIds: number[] = [];

  build() {
    Column() {
      Text('移动到牌组').fontSize(18).fontWeight(FontWeight.Medium).margin({ bottom: 16 })
      Scroll() {
        Column() {
          ForEach(this.decks, (deck: Deck) => {
            Row() {
              Checkbox()
                .select(this.selectedDeckIds.indexOf(deck.id) >= 0)
                .onChange((isOn: boolean) => {
                  if (isOn) {
                    this.selectedDeckIds = [...this.selectedDeckIds, deck.id];
                  } else {
                    this.selectedDeckIds = this.selectedDeckIds.filter(id => id !== deck.id);
                  }
                })
              Text(deck.name).fontSize(14).margin({ left: 8 })
            }.width('100%').padding({ top: 6, bottom: 6 })
          })
        }
      }.constraintSize({ maxHeight: 300 })
      Row({ space: 12 }) {
        Button('取消').fontSize(14).backgroundColor($r('app.color.surface')).fontColor($r('app.color.text_secondary')).layoutWeight(1)
          .onClick(() => { this.controller?.close(); })
        Button('确定').fontSize(14).backgroundColor($r('app.color.primary')).fontColor($r('app.color.on_primary')).layoutWeight(1)
          .onClick(() => {
            if (this.selectedDeckIds.length > 0) {
              this.onMoveToDeck(this.selectedDeckIds);
            }
            this.controller?.close();
          })
      }.width('100%').margin({ top: 16 })
    }.padding(20)
  }
}

@CustomDialog
struct DeckActionDialog {
  controller?: CustomDialogController;
  @Prop deckName: string = '';
  @Prop isDefault: boolean = false;
  onSettings: () => void = () => {};
  onDelete: () => void = () => {};

  build() {
    Column() {
      Text(this.deckName)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 20 })

      Row({ space: 12 }) {
        Button('牌组设置')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1.2, color: $r('app.color.primary'), style: BorderStyle.Solid })
          .borderRadius(20)
          .height(40)
          .layoutWeight(1)
          .onClick(() => {
            this.controller?.close();
            this.onSettings();
          })
        Button('删除牌组')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDefault ? $r('app.color.disabled') : $r('app.color.danger'))
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1.2, color: this.isDefault ? $r('app.color.disabled') : $r('app.color.danger'), style: BorderStyle.Solid })
          .borderRadius(20)
          .height(40)
          .layoutWeight(1)
          .enabled(!this.isDefault)
          .onClick(() => {
            this.controller?.close();
            this.onDelete();
          })
      }
      .width('100%')
      .margin({ bottom: 14 })

      Button('取消')
        .fontSize(14)
        .height(38)
        .backgroundColor($r('app.color.surface'))
        .fontColor($r('app.color.text_secondary'))
        .borderRadius(20)
        .width('100%')
        .onClick(() => { this.controller?.close(); })
    }
    .padding({ left: 24, right: 24, top: 20, bottom: 20 })
    .width('100%')
  }
}

@Entry
@Component
struct HomePage {
  @State cards: Card[] = [];
  @State decks: Deck[] = [];
  @State loading: boolean = true;
  @State unlearnedOpen: boolean = true;
  @State reviewingOpen: boolean = false;
  @State masteredOpen: boolean = false;
  @State selectedDeckId: number = 0;
  @State deletingDeckId: number = -1;
  @State editingDeckId: number = 0;
  @State editingDeckName: string = '';
  @State editingDeckDailyNew: number = 20;
  @State editingDeckDailyReview: number = 100;
  @State editingDeckIsDefault: boolean = false;
  @State currentTabIndex: number = 0;
  @State isMultiSelectMode: boolean = false;
  @State selectedCardIds: number[] = [];
  @StorageLink('dataVersion') @Watch('onDataVersionChange') dataVersion: number = 0;
  @State isSearching: boolean = false;
  @State searchQuery: string = '';
  private cardVm: CardViewModel = new CardViewModel();
  private studyVm: StudyViewModel = new StudyViewModel();
  private addDeckDialogController: CustomDialogController = new CustomDialogController({
    builder: AddDeckDialog({ onConfirm: (name: string) => { this.addDeck(name); } }),
    autoCancel: true, alignment: DialogAlignment.Center
  });
  private deckSettingsDialogController: CustomDialogController = new CustomDialogController({
    builder: DeckSettingsDialog({
      deckId: this.editingDeckId,
      deckName: this.editingDeckName,
      newCardsPerDay: this.editingDeckDailyNew,
      reviewCardsPerDay: this.editingDeckDailyReview,
      onSave: (newLimit: number, reviewLimit: number, deckId: number) => {
        this.saveDeckSettings(newLimit, reviewLimit, deckId);
      }
    }),
    autoCancel: true, alignment: DialogAlignment.Center
  });
  private deckActionDialogController: CustomDialogController = new CustomDialogController({
    builder: DeckActionDialog({
      deckName: this.editingDeckName,
      isDefault: this.editingDeckIsDefault,
      onSettings: () => { this.deckSettingsDialogController.open(); },
      onDelete: () => { this.deleteCurrentActionDeck(); }
    }),
    autoCancel: true, alignment: DialogAlignment.Center
  });
  private moveToDeckDialogController: CustomDialogController = new CustomDialogController({
    builder: MoveToDeckDialog({
      decks: this.decks,
      onMoveToDeck: (deckIds: number[]) => { this.batchMoveToDeck(deckIds); }
    }),
    autoCancel: true, alignment: DialogAlignment.Center
  });

  aboutToAppear() { this.loadHomeData(); }

  onPageShow() {
    this.lastLoadTime = 0;
    this.loadHomeData();
  }

  onBackPress(): boolean {
    if (this.isSearching) {
      this.exitSearch();
      return true;
    }
    return false;
  }

  private lastLoadTime: number = 0;

  onDataVersionChange() { this.debouncedLoadData(); }

  private debouncedLoadData(): void {
    const now: number = Date.now();
    if (now - this.lastLoadTime < 300) {
      return;
    }
    this.lastLoadTime = now;
    this.loadHomeData();
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  private showConfirmDialog(title: string, message: string, confirmText: string, confirmColor: ResourceColor,
    onConfirm: () => void, cancelText: string = '取消'): void {
    this.getUIContext().showAlertDialog({
      title: title,
      message: message,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: { value: confirmText, fontColor: confirmColor, action: onConfirm },
      secondaryButton: { value: cancelText, fontColor: $r('app.color.text_secondary'), action: () => {} },
    });
  }

  private getFilteredCards(): Card[] {
    return this.selectedDeckId === 0 ? this.cards : this.cards.filter(c => c.deckId === this.selectedDeckId);
  }

  async loadHomeData() {
    for (let attempt = 0; attempt < 3; attempt++) {
      try { this.decks = await this.cardVm.getAllDecks(); this.cards = await this.cardVm.getAllCards(); break; }
      catch (err) { console.error(`Load failed (${attempt + 1}/3):`, err); if (attempt < 2) await new Promise<void>(r => setTimeout(r, 800)); }
    }
    this.loading = false;
  }

  build() {
    Flex({ direction: FlexDirection.Column }) {
      HdsTabs({ index: this.currentTabIndex }) {
        TabContent() {
          Flex({ direction: FlexDirection.Column }) {
            if (this.isSearching) {
              Row() {
                Search({ placeholder: '搜索卡片内容', value: this.searchQuery })
                  .onChange((value: string) => { this.searchQuery = value; })
                  .layoutWeight(1)
                Button('取消')
                  .fontSize(14)
                  .fontColor($r('app.color.primary'))
                  .backgroundColor(Color.Transparent)
                  .margin({ left: 8 })
                  .onClick(() => { this.exitSearch(); })
              }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 8 }).backgroundColor($r('app.color.surface'))

              if (this.searchQuery.trim().length > 0) {
                Scroll() {
                  Column() {
                    ForEach(this.getSearchResults(), (card: Card) => {
                      Row() {
                        Text(card.front)
                          .fontSize(14)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .layoutWeight(1)
                        Text(this.decks.find((d: Deck) => d.id === card.deckId)?.name ?? '')
                          .fontSize(11)
                          .fontColor($r('app.color.text_secondary'))
                          .margin({ left: 8 })
                      }
                      .width('100%')
                      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
                      .backgroundColor($r('app.color.surface'))
                      .borderRadius(10)
                      .shadow({ radius: 3, color: $r('app.color.shadow'), offsetY: 1 })
                      .margin({ left: 16, right: 16, bottom: 6 })
                      .onClick(() => {
                        this.getUIContext().getRouter().pushUrl({ url: 'pages/LearningDetailPage', params: { cardId: card.id } });
                      })
                    }, (card: Card) => card.id.toString())
                  }.width('100%').justifyContent(FlexAlign.Start).padding({ top: 10, bottom: 68 })
                }.width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.TopStart)
              } else {
                Column() {
                  Text('输入关键词搜索卡片')
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))
                }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
              }
            } else {
            Column() {
              Row() {
                Text('卡片笔记').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).layoutWeight(1)
                Text('搜索').fontSize(14).fontColor($r('app.color.primary'))
                  .onClick(() => { this.enterSearch(); })
              }.width('100%').margin({ top: 8, bottom: 14 })
              Row({ space: 10 }) {
                Column() {
                  Text(`${this.cards.filter((c: Card) => c.status === CardStatus.reviewing).length}`).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary')).fontFamily('HarmonyHeiTi')
                  Text('待复习').fontSize(11).fontColor($r('app.color.text_secondary')).margin({ top: 2 })
                }.layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor($r('app.color.surface')).borderRadius(12).shadow({ radius: 6, color: $r('app.color.shadow'), offsetY: 2 })
                Column() {
                  Text(`${this.cards.filter((c: Card) => c.status === CardStatus.unlearned).length}`).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.warning')).fontFamily('HarmonyHeiTi')
                  Text('新卡片').fontSize(11).fontColor($r('app.color.text_secondary')).margin({ top: 2 })
                }.layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor($r('app.color.surface')).borderRadius(12).shadow({ radius: 6, color: $r('app.color.shadow'), offsetY: 2 })
                Column() {
                  Text(`${this.cards.length}`).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.success')).fontFamily('HarmonyHeiTi')
                  Text('总卡片').fontSize(11).fontColor($r('app.color.text_secondary')).margin({ top: 2 })
                }.layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor($r('app.color.surface')).borderRadius(12).shadow({ radius: 6, color: $r('app.color.shadow'), offsetY: 2 })
              }.width('100%')
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 14 }).backgroundColor($r('app.color.surface'))

            if (this.decks.length > 0) { this.buildDeckFilter() }
            if (this.isMultiSelectMode) { this.buildMultiSelectBar() }

            Scroll() {
              Column() {
                this.buildCardSection({ title: '未背诵', circleColor: $r('app.color.disabled'), status: CardStatus.unlearned, isOpen: this.unlearnedOpen, section: 'unlearned' })
                this.buildCardSection({ title: '复习中', circleColor: $r('app.color.primary'), status: CardStatus.reviewing, isOpen: this.reviewingOpen, section: 'reviewing' })
                this.buildCardSection({ title: '已掌握', circleColor: $r('app.color.success'), status: CardStatus.mastered, isOpen: this.masteredOpen, section: 'mastered' })
              }.width('100%').justifyContent(FlexAlign.Start).padding({ bottom: 68 })
            }.width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.TopStart)

            if (this.isMultiSelectMode) { this.buildBatchActionBar() } else { this.buildBottomBar() }
            }
          }.width('100%').height('100%').backgroundColor($r('app.color.background'))
        }.tabBar(this.buildTab('首页', 0))

        TabContent() { StatsPage() }.tabBar(this.buildTab('统计', 1))
        TabContent() { SettingsPage() }.tabBar(this.buildTab('设置', 2))
      }
      .barPosition(BarPosition.End).scrollable(false).barOverlap(true)
      .barFloatingStyle({ barBottomMargin: 3, systemMaterialEffect: { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE } })
      .layoutWeight(1)
      .onChange((index: number) => { this.currentTabIndex = index; })
    }.width('100%').height('100%').backgroundColor($r('app.color.background'))
  }

  @Builder buildDeckFilter() {
    Scroll() {
      Row({ space: 8 }) {
        Text('全部').fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor(this.selectedDeckId === 0 ? $r('app.color.on_primary') : $r('app.color.text_secondary'))
          .padding({ left: 16, right: 16, top: 7, bottom: 7 })
          .backgroundColor(this.selectedDeckId === 0 ? $r('app.color.primary') : $r('app.color.surface'))
          .borderRadius(16).onClick(() => { this.selectedDeckId = 0; })
        ForEach(this.decks, (deck: Deck) => {
          Text(deck.name).fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor(this.selectedDeckId === deck.id ? $r('app.color.on_primary') : $r('app.color.text_secondary'))
            .padding({ left: 16, right: 16, top: 7, bottom: 7 })
            .backgroundColor(this.selectedDeckId === deck.id ? $r('app.color.primary') : $r('app.color.surface'))
            .borderRadius(16).onClick(() => { this.selectedDeckId = deck.id; })
            .gesture(LongPressGesture({ repeat: false, duration: 400 }).onAction(() => { this.showDeckActionMenu(deck); }))
        }, (deck: Deck) => `${deck.id}_${deck.updatedAt}`)
        Text('+').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_secondary')).width(30).height(30).textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.surface')).borderRadius(15).onClick(() => { this.addDeckDialogController.open(); })
      }.padding({ left: 16, right: 16, top: 8, bottom: 10 })
    }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).constraintSize({ maxHeight: 60 }).backgroundColor($r('app.color.surface'))
  }

  @Builder buildMultiSelectBar() {
    Row() {
      Text(`已选 ${this.selectedCardIds.length} 项`).fontSize(13).fontColor($r('app.color.text_secondary'))
      Blank()
      Text('全选').fontSize(13).fontColor($r('app.color.primary')).onClick(() => { this.selectedCardIds = this.getFilteredCards().map(c => c.id); })
      Blank().width(16)
      Text('取消').fontSize(13).fontColor($r('app.color.danger')).onClick(() => { this.exitMultiSelectMode(); })
    }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 }).backgroundColor($r('app.color.surface'))
  }

  @Builder buildCardSection($$: CardSectionParams) {
    Column() {
      Row() {
        Row({ space: 6 }) {
          Row().width(6).height(6).borderRadius(3).backgroundColor($$.circleColor)
          Text($$.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          Text(`(${this.getFilteredCards().filter(c => c.status === $$.status).length})`).fontSize(12).fontColor($r('app.color.text_secondary'))
        }
        Blank()
        Text($$.isOpen ? '▼' : '▶').fontSize(10).fontColor($r('app.color.disabled'))
      }.width('100%').padding({ top: 14, bottom: 10, left: 4, right: 4 })
      .onClick(() => {
        if ($$.section === 'unlearned') this.unlearnedOpen = !this.unlearnedOpen;
        else if ($$.section === 'reviewing') this.reviewingOpen = !this.reviewingOpen;
        else if ($$.section === 'mastered') this.masteredOpen = !this.masteredOpen;
      })
      if ($$.isOpen) {
        ForEach(this.getFilteredCards().filter(c => c.status === $$.status), (card: Card) => {
          CardItem({
            cardId: card.id, cardFront: card.front, nextReviewTime: card.nextReviewTime,
            isMultiSelect: this.isMultiSelectMode, isSelected: this.isCardSelected(card.id),
            onTap: () => {
              this.deletingDeckId = -1;
              if (this.isMultiSelectMode) { this.toggleCardSelection(card.id); }
              else { this.getUIContext().getRouter().pushUrl({ url: 'pages/LearningDetailPage', params: { cardId: card.id } }); }
            },
            onLongPress: () => { if (!this.isMultiSelectMode) this.enterMultiSelectMode(card.id); }
          })
        }, (card: Card) => `${card.id}_${card.updatedAt}`)
      }
    }.width('100%').padding({ left: 16, right: 16, top: 4, bottom: 16 })
    .backgroundColor($r('app.color.surface')).borderRadius(14).margin({ top: 10 }).shadow({ radius: 4, color: $r('app.color.shadow'), offsetY: 1 })
  }

  @Builder buildBottomBar() {
    Row() {
      if (this.cards.length > 0) {
        Button('开始学习').layoutWeight(1).height(46).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_primary'))
          .backgroundColor($r('app.color.primary')).borderRadius(23).shadow({ radius: 8, color: $r('app.color.shadow'), offsetY: 3 })
          .onClick(() => { this.getUIContext().getRouter().pushUrl({ url: 'pages/LearningPage', params: { selectedDeckId: this.selectedDeckId } }); })
        Blank().width(12)
      }
      Button('新建卡片').layoutWeight(1).height(46).fontSize(14).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary')).backgroundColor($r('app.color.surface'))
        .border({ width: 1.5, color: $r('app.color.primary'), style: BorderStyle.Solid }).borderRadius(23)
        .onClick(() => { this.getUIContext().getRouter().pushUrl({ url: 'pages/EditorPage' }); })
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 68 }).backgroundColor($r('app.color.surface')).shadow({ radius: 6, color: $r('app.color.shadow'), offsetY: -2 })
  }

  @Builder buildBatchActionBar() {
    Row({ space: 8 }) {
      Button('重学').layoutWeight(1).height(42).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary'))
        .backgroundColor($r('app.color.surface')).border({ width: 1.2, color: $r('app.color.primary'), style: BorderStyle.Solid }).borderRadius(21)
        .onClick(() => { this.batchRelearn(); })
      Button('晋级').layoutWeight(1).height(42).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary'))
        .backgroundColor($r('app.color.surface')).border({ width: 1.2, color: $r('app.color.primary'), style: BorderStyle.Solid }).borderRadius(21)
        .onClick(() => { this.batchPromote(); })
      Button('移动').layoutWeight(1).height(42).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary'))
        .backgroundColor($r('app.color.surface')).border({ width: 1.2, color: $r('app.color.primary'), style: BorderStyle.Solid }).borderRadius(21)
        .onClick(() => { this.moveToDeckDialogController.open(); })
      Button('删除').layoutWeight(1).height(42).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_primary'))
        .backgroundColor($r('app.color.danger')).borderRadius(21)
        .onClick(() => { this.batchDelete(); })
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 68 }).backgroundColor($r('app.color.surface')).shadow({ radius: 6, color: $r('app.color.shadow'), offsetY: -2 })
  }

  @Builder buildTab(label: string, index: number) {
    Column() {
      Text(label).fontSize(11).fontWeight(FontWeight.Medium)
        .fontColor(this.currentTabIndex === index ? $r('app.color.primary') : $r('app.color.text_secondary'))
      if (this.currentTabIndex === index) {
        Row().width(4).height(4).borderRadius(2).backgroundColor($r('app.color.primary')).margin({ top: 2 })
      }
    }.width('100%').justifyContent(FlexAlign.Center)
  }

  isCardSelected(cardId: number): boolean { return this.selectedCardIds.indexOf(cardId) >= 0; }
  toggleCardSelection(cardId: number) { const i = this.selectedCardIds.indexOf(cardId); this.selectedCardIds = i >= 0 ? this.selectedCardIds.filter(id => id !== cardId) : [...this.selectedCardIds, cardId]; }
  enterMultiSelectMode(cardId: number) { this.isMultiSelectMode = true; this.selectedCardIds = [cardId]; }
  exitMultiSelectMode() { this.isMultiSelectMode = false; this.selectedCardIds = []; }

  async addDeck(name: string) {
    if (!name.trim()) return;
    const deck: Deck = { id: 0, name: name.trim(), color: DECK_COLORS[Math.floor(Math.random() * DECK_COLORS.length)], createdAt: 0, updatedAt: 0 };
    await this.cardVm.createDeck(deck);
    await this.loadHomeData();
  }

  async batchPromote() {
    for (const id of this.selectedCardIds) {
      const card = this.cards.find(c => c.id === id);
      if (card && card.status !== CardStatus.mastered) {
        card.status = card.status === CardStatus.unlearned ? CardStatus.reviewing : CardStatus.mastered;
        await this.cardVm.updateCard(card);
      }
    }
    const promotedCount: number = this.selectedCardIds.length;
    this.exitMultiSelectMode();
    await this.loadHomeData();
    this.showToast(`已将 ${promotedCount} 张卡片晋级`);
  }

  async batchRelearn() {
    this.showConfirmDialog('清除学习数据',
      `将删除选中的 ${this.selectedCardIds.length} 张卡片的所有记忆记录，并重置学习进度。确定继续吗？`,
      '确定', $r('app.color.primary'),
          async () => {
            const recordDao = new MemoryRecordDao();
            for (const id of this.selectedCardIds) {
              const card = this.cards.find(c => c.id === id);
              if (card) {
                await recordDao.deleteByCardId(card.id);
                card.status = CardStatus.unlearned;
                card.interval = 0;
                card.repetitions = 0;
                card.easeFactor = 2.5;
                card.nextReviewTime = Date.now();
                await this.cardVm.updateCard(card);
              }
            }
        this.exitMultiSelectMode();
        await this.loadHomeData();
      });
  }

  async batchDelete() {
    this.showConfirmDialog('删除卡片',
      `确定要删除选中的 ${this.selectedCardIds.length} 张卡片吗？此操作不可撤销。`,
      '删除', $r('app.color.danger'),
      async () => {
        for (const id of this.selectedCardIds) { await this.cardVm.deleteCard(id); }
        this.exitMultiSelectMode(); await this.loadHomeData();
      });
  }

  async batchMoveToDeck(deckIds: number[]) {
    if (deckIds.length === 0) return;
    const count: number = this.selectedCardIds.length;
    for (const cardId of this.selectedCardIds) {
      const card = this.cards.find(c => c.id === cardId);
      if (card) { card.deckId = deckIds[0]; await this.cardVm.updateCard(card); }
    }
    this.exitMultiSelectMode(); await this.loadHomeData();
    this.showToast(`已将 ${count} 张卡片移动`);
  }

  showDeckActionMenu(deck: Deck) {
    this.editingDeckId = deck.id;
    this.editingDeckName = deck.name;
    this.editingDeckIsDefault = deck.isDefault ?? false;
    this.editingDeckDailyNew = deck.dailyNewCards ?? 20;
    this.editingDeckDailyReview = deck.dailyReviewCards ?? 100;
    this.deckActionDialogController.open();
  }

  deleteCurrentActionDeck() {
    const deck = this.decks.find(d => d.id === this.editingDeckId);
    if (deck) {
      this.deleteDeck(deck);
    }
  }

  async deleteDeck(deck: Deck) {
    if (deck.isDefault) {
      this.showToast('系统默认牌组不可删除');
      return;
    }
    const cardCount: number = this.cards.filter(c => c.deckId === deck.id).length;
    this.showConfirmDialog('删除牌组',
      cardCount > 0
        ? `牌组「${deck.name}」下有 ${cardCount} 张卡片，删除牌组将同时删除所有卡片。确定继续吗？`
        : `确定删除牌组「${deck.name}」吗？`,
      '删除', $r('app.color.danger'),
      async () => {
        await this.cardVm.deleteDeck(deck.id);
        if (this.selectedDeckId === deck.id) {
          this.selectedDeckId = 0;
        }
        await this.loadHomeData();
        this.showToast('牌组已删除');
      });
  }

  async saveDeckSettings(newLimit: number, reviewLimit: number, deckId: number) {
    await this.cardVm.updateDeckSettings(deckId, newLimit, reviewLimit);
    await this.loadHomeData();
    this.showToast('牌组设置已保存');
  }

  private enterSearch(): void {
    this.isSearching = true;
    this.searchQuery = '';
  }

  private exitSearch(): void {
    this.isSearching = false;
    this.searchQuery = '';
  }

  private getSearchResults(): Card[] {
    const q: string = this.searchQuery.trim().toLowerCase();
    if (q.length === 0) {
      return [];
    }
    const results: Card[] = [];
    for (let i: number = 0; i < this.cards.length; i++) {
      const card: Card = this.cards[i];
      if (card.front.toLowerCase().indexOf(q) >= 0 ||
          card.analysis.toLowerCase().indexOf(q) >= 0) {
        results.push(card);
      }
    }
    return results;
  }
}