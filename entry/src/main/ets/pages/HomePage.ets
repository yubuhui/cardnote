import { router } from '@kit.ArkUI';
import { Card, CardStatus } from '../model/Card';
import { Deck } from '../model/Deck';
import { CardViewModel } from '../viewmodel/CardViewModel';
import { StudyViewModel } from '../viewmodel/StudyViewModel';
import { MemoryRecordDao } from '../data/MemoryRecordDao';
import { StatsPage } from './StatsPage';
import { SettingsPage } from './SettingsPage';
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';

const PRIMARY = '#4A90D9';
const PRIMARY_DARK = '#3A7BC8';
const BG_GRAY = '#F2F3F7';
const CARD_WHITE = '#FFFFFF';
const TEXT_PRIMARY = '#1A1A1A';
const TEXT_SECONDARY = '#8E8E93';
const TEXT_TERTIARY = '#A0A0A0';

interface CardSectionParams {
  title: string;
  circleColor: string;
  status: CardStatus;
  isOpen: boolean;
  section: string;
}

// ==================== 卡片列表项组件 ====================
@Component
struct CardItem {
  @Prop cardId: number = 0;
  @Prop cardFront: string = '';
  @Prop cardStatus: CardStatus = CardStatus.unlearned;
  @Prop isMultiSelect: boolean = false;
  @Prop isSelected: boolean = false;
  onTap: () => void = () => {};
  onLongPress: () => void = () => {};

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
        Text(this.cardStatus === CardStatus.unlearned ? '未背诵' :
             this.cardStatus === CardStatus.reviewing ? '待复习' : '已掌握')
          .fontSize(10)
          .fontColor(this.cardStatus === CardStatus.unlearned ? '#9E9E9E' :
                     this.cardStatus === CardStatus.reviewing ? PRIMARY : '#34C759')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(this.cardStatus === CardStatus.unlearned ? '#F0F0F0' :
                           this.cardStatus === CardStatus.reviewing ? '#E8F0FE' : '#E8F8ED')
          .borderRadius(4)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(CARD_WHITE)
    .borderRadius(10)
    .shadow({ radius: 3, color: '#08000000', offsetY: 1 })
    .margin({ bottom: 6 })
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        LongPressGesture({ repeat: false, duration: 400 })
          .onAction(() => {
            this.onLongPress();
          }),
        TapGesture()
          .onAction(() => {
            this.onTap();
          })
      )
    )
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
  @State currentTabIndex: number = 0;
  @State isMultiSelectMode: boolean = false;
  @State selectedCardIds: number[] = [];
  @Provide statsRefreshSignal: number = 0;
  private cardVm: CardViewModel = new CardViewModel();
  private studyVm: StudyViewModel = new StudyViewModel();
  private addDeckDialogController: CustomDialogController = new CustomDialogController({
    builder: AddDeckDialog({ onConfirm: (name: string) => { this.addDeck(name); } }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  private deckSettingsDialogController: CustomDialogController = new CustomDialogController({
    builder: DeckSettingsDialog({
      onSave: (newLimit: number, reviewLimit: number, deckId: number) => {
        this.saveDeckSettings(newLimit, reviewLimit, deckId);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });
  private moveToDeckDialogController: CustomDialogController = new CustomDialogController({
    builder: MoveToDeckDialog({
      decks: $decks,
      onMoveToDeck: (deckIds: number[]) => { this.batchMoveToDeck(deckIds); }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

  aboutToAppear() {
    this.loadHomeData();
  }

  onPageShow() {
    this.loadHomeData();
    this.statsRefreshSignal++;
  }

  private getFilteredCards(): Card[] {
    if (this.selectedDeckId === 0) {
      return this.cards;
    }
    return this.cards.filter(c => c.deckId === this.selectedDeckId);
  }

  async loadHomeData() {
    const maxRetries: number = 3;
    const retryDelay: number = 800;
    for (let attempt: number = 0; attempt < maxRetries; attempt++) {
      try {
        this.decks = await this.cardVm.getAllDecks();
        this.cards = await this.cardVm.getAllCards();
        break;
      } catch (err) {
        console.error(`Load home data failed (attempt ${attempt + 1}/${maxRetries}):`, err);
        if (attempt < maxRetries - 1) {
          await new Promise<void>(resolve => setTimeout(resolve, retryDelay));
        }
      }
    }
    this.loading = false;
  }

  build() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Start }) {
      HdsTabs({ index: this.currentTabIndex }) {
        TabContent() {
          Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Start }) {
            // 顶部区域 —— 统计栏
            Column() {
              Text('CardNote')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
        
                .margin({ top: 8, bottom: 14 })
                .alignSelf(ItemAlign.Start)
              Row({ space: 10 }) {
                // 待复习
                Column() {
                  Text(`${this.cards.filter((c: Card) => c.status === CardStatus.reviewing).length}`)
                    .fontSize(26).fontWeight(FontWeight.Bold).fontColor(PRIMARY).fontFamily('HarmonyHeiTi')
                  Text('待复习').fontSize(11).fontColor(TEXT_SECONDARY).margin({ top: 2 })
                }
                .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor(CARD_WHITE).borderRadius(12)
                .shadow({ radius: 6, color: '#14000000', offsetY: 2 })
                // 新卡片
                Column() {
                  Text(`${this.cards.filter((c: Card) => c.status === CardStatus.unlearned).length}`)
                    .fontSize(26).fontWeight(FontWeight.Bold).fontColor('#FF9500').fontFamily('HarmonyHeiTi')
                  Text('新卡片').fontSize(11).fontColor(TEXT_SECONDARY).margin({ top: 2 })
                }
                .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor(CARD_WHITE).borderRadius(12)
                .shadow({ radius: 6, color: '#14000000', offsetY: 2 })
                // 总卡片
                Column() {
                  Text(`${this.cards.length}`)
                    .fontSize(26).fontWeight(FontWeight.Bold).fontColor('#34C759').fontFamily('HarmonyHeiTi')
                  Text('总卡片').fontSize(11).fontColor(TEXT_SECONDARY).margin({ top: 2 })
                }
                .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor(CARD_WHITE).borderRadius(12)
                .shadow({ radius: 6, color: '#14000000', offsetY: 2 })
              }
              .width('100%')
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 14 })
            .backgroundColor(CARD_WHITE)

            // 牌组筛选
            if (this.decks.length > 0) {
              this.buildDeckFilter()
            }

            // 多选提示栏
            if (this.isMultiSelectMode) {
              this.buildMultiSelectBar()
            }

            // 卡片列表区域
            Scroll() {
              Column() {
                this.buildCardSection({ title: '未背诵', circleColor: '#9E9E9E', status: CardStatus.unlearned, isOpen: this.unlearnedOpen, section: 'unlearned' })
                this.buildCardSection({ title: '复习中', circleColor: PRIMARY, status: CardStatus.reviewing, isOpen: this.reviewingOpen, section: 'reviewing' })
                this.buildCardSection({ title: '已掌握', circleColor: '#34C759', status: CardStatus.mastered, isOpen: this.masteredOpen, section: 'mastered' })
              }
              .width('100%')
              .padding({ bottom: 72 })
            }
            .width('100%')
            .align(Alignment.Top)
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)

            // 底部栏
            if (this.isMultiSelectMode) {
              this.buildBatchActionBar()
            } else {
              this.buildBottomBar()
            }
          }
          .width('100%')
          .height('100%')
          .backgroundColor(BG_GRAY)
        }
        .tabBar(this.buildTab('首页', 0))

        TabContent() {
          StatsPage()
        }
        .tabBar(this.buildTab('统计', 1))

        TabContent() {
          SettingsPage()
        }
        .tabBar(this.buildTab('设置', 2))
      }
      .barPosition(BarPosition.End)
      .scrollable(false)
      .barOverlap(true)
      .barFloatingStyle({
        barBottomMargin: 28,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .layoutWeight(1)
      .onChange((index: number) => {
        this.currentTabIndex = index;
        if (index === 1) {
          this.statsRefreshSignal++;
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG_GRAY)
  }

  // ==================== 牌组筛选 ====================
  @Builder
  buildDeckFilter() {
    Scroll() {
      Row({ space: 8 }) {
        // 全部
        Text('全部')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedDeckId === 0 ? Color.White : '#555')
          .padding({ left: 16, right: 16, top: 7, bottom: 7 })
          .backgroundColor(this.selectedDeckId === 0 ? PRIMARY : '#EDEDEF')
          .borderRadius(16)
          .onClick(() => {
            this.selectedDeckId = 0;
          })

        ForEach(this.decks, (deck: Deck) => {
          Text(deck.name)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selectedDeckId === deck.id ? Color.White : '#555')
              .padding({ left: 16, right: 16, top: 7, bottom: 7 })
              .backgroundColor(this.selectedDeckId === deck.id ? PRIMARY : '#EDEDEF')
              .borderRadius(16)
              .onClick(() => {
                this.selectedDeckId = deck.id;
              })
              .gesture(
                LongPressGesture({ repeat: false, duration: 400 })
                  .onAction(() => {
                    this.showDeckActionMenu(deck);
                  })
              )
        }, (deck: Deck) => deck.id.toString())

        // 添加牌组
        Text('+')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#888')
          .width(30)
          .height(30)
          .textAlign(TextAlign.Center)
          .backgroundColor('#EDEDEF')
          .borderRadius(15)
          .onClick(() => {
            this.addDeckDialogController.open();
          })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 10 })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .constraintSize({ maxHeight: 60 })
    .backgroundColor(CARD_WHITE)
  }

  // ==================== 多选栏 ====================
  @Builder
  buildMultiSelectBar() {
    Row() {
      Text(`已选 ${this.selectedCardIds.length} 项`)
        .fontSize(13)
        .fontColor(TEXT_SECONDARY)
      Blank()
      Text('全选')
        .fontSize(13)
        .fontColor(PRIMARY)
        .onClick(() => {
          const filtered = this.getFilteredCards();
          this.selectedCardIds = filtered.map(c => c.id);
        })
      Blank().width(16)
      Text('取消')
        .fontSize(13)
        .fontColor('#EF4444')
        .onClick(() => {
          this.exitMultiSelectMode();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor('#F0F4FF')
  }

  // ==================== 通用卡片分区 ====================
  @Builder
  buildCardSection($$: CardSectionParams) {
    Column() {
      // 区块标题行
      Row() {
        Row({ space: 6 }) {
          Circle({ width: 6, height: 6 })
            .fill($$.circleColor)
          Text($$.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_PRIMARY)
          Text(`(${this.getFilteredCards().filter(c => c.status === $$.status).length})`)
            .fontSize(12)
            .fontColor(TEXT_SECONDARY)
        }
        Blank()
        Text($$.isOpen ? '▼' : '▶')
          .fontSize(10)
          .fontColor('#B0B0B0')
      }
      .width('100%')
      .padding({ top: 14, bottom: 10, left: 4, right: 4 })
      .onClick(() => {
        if ($$.section === 'unlearned') {
          this.unlearnedOpen = !this.unlearnedOpen;
        } else if ($$.section === 'reviewing') {
          this.reviewingOpen = !this.reviewingOpen;
        } else if ($$.section === 'mastered') {
          this.masteredOpen = !this.masteredOpen;
        }
      })

      // 卡片列表
      if ($$.isOpen) {
        ForEach(this.getFilteredCards().filter(c => c.status === $$.status), (card: Card) => {
          CardItem({
            cardId: card.id,
            cardFront: card.front,
            cardStatus: card.status,
            isMultiSelect: this.isMultiSelectMode,
            isSelected: this.isCardSelected(card.id),
            onTap: () => {
              this.deletingDeckId = -1;
              if (this.isMultiSelectMode) {
                this.toggleCardSelection(card.id);
              } else {
                router.pushUrl({ url: 'pages/LearningDetailPage', params: { cardId: card.id } });
              }
            },
            onLongPress: () => {
              if (!this.isMultiSelectMode) {
                this.enterMultiSelectMode(card.id);
              }
            }
          })
        }, (card: Card) => card.id.toString())
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 16 })
    .backgroundColor(CARD_WHITE)
    .borderRadius(14)
    .margin({ top: 10 })
    .shadow({ radius: 4, color: '#0A000000', offsetY: 1 })
  }

  // ==================== 底部操作栏（正常模式） ====================
  @Builder
  buildBottomBar() {
    Row() {
      if (this.cards.length > 0) {
        Button('开始学习')
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(PRIMARY)
          .borderRadius(23)
          .shadow({ radius: 8, color: '#404A90D9', offsetY: 3 })
          .onClick(() => {
            router.pushUrl({
              url: 'pages/LearningPage',
              params: { selectedDeckId: this.selectedDeckId }
            });
          })
        Blank().width(12)
      }

      Button('新建卡片')
        .layoutWeight(1)
        .height(46)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(PRIMARY)
        .backgroundColor(Color.White)
        .border({ width: 1.5, color: PRIMARY, style: BorderStyle.Solid })
        .borderRadius(23)
        .onClick(() => {
          router.pushUrl({ url: 'pages/EditorPage' });
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 66 })
    .backgroundColor(CARD_WHITE)
    .shadow({ radius: 6, color: '#10000000', offsetY: -2 })
  }

  // ==================== 批量操作栏 ====================
  @Builder
  buildBatchActionBar() {
    Row({ space: 8 }) {
      Button('重学')
        .layoutWeight(1)
        .height(42)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(PRIMARY)
        .backgroundColor(Color.White)
        .border({ width: 1.2, color: PRIMARY, style: BorderStyle.Solid })
        .borderRadius(21)
        .onClick(() => { this.batchRelearn(); })

      Button('晋级')
        .layoutWeight(1)
        .height(42)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(PRIMARY)
        .backgroundColor(Color.White)
        .border({ width: 1.2, color: PRIMARY, style: BorderStyle.Solid })
        .borderRadius(21)
        .onClick(() => { this.batchPromote(); })

      Button('移动')
        .layoutWeight(1)
        .height(42)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(PRIMARY)
        .backgroundColor(Color.White)
        .border({ width: 1.2, color: PRIMARY, style: BorderStyle.Solid })
        .borderRadius(21)
        .onClick(() => { this.moveToDeckDialogController.open(); })

      Button('删除')
        .layoutWeight(1)
        .height(42)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor('#EF4444')
        .borderRadius(21)
        .onClick(() => { this.batchDelete(); })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 66 })
    .backgroundColor(CARD_WHITE)
    .shadow({ radius: 6, color: '#10000000', offsetY: -2 })
  }

  // ==================== Tab 栏 ====================
  @Builder
  buildTab(label: string, index: number) {
    Column() {
      Text(label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTabIndex === index ? PRIMARY : TEXT_SECONDARY)
      if (this.currentTabIndex === index) {
        Circle({ width: 4, height: 4 })
          .fill(PRIMARY)
          .margin({ top: 2 })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  // ==================== 辅助方法 ====================
  isCardSelected(cardId: number): boolean {
    return this.selectedCardIds.indexOf(cardId) >= 0;
  }

  toggleCardSelection(cardId: number) {
    const idx = this.selectedCardIds.indexOf(cardId);
    if (idx >= 0) {
      this.selectedCardIds = this.selectedCardIds.filter(id => id !== cardId);
    } else {
      this.selectedCardIds = [...this.selectedCardIds, cardId];
    }
  }

  enterMultiSelectMode(cardId: number) {
    this.isMultiSelectMode = true;
    this.selectedCardIds = [cardId];
  }

  exitMultiSelectMode() {
    this.isMultiSelectMode = false;
    this.selectedCardIds = [];
  }

  async addDeck(name: string) {
    if (!name.trim()) return;
    const colors = ['#4A90D9', '#E85D75', '#50C878', '#FFB347', '#9B59B6', '#1ABC9C'];
    
    const idx = Math.floor(Math.random() * colors.length);
    const deck: Deck = {
      id: 0,
      name: name.trim(),
      
      color: colors[idx],
      createdAt: 0,
      updatedAt: 0
    };
    await this.cardVm.createDeck(deck);
    await this.loadHomeData();
  }

  async batchPromote() {
    for (const id of this.selectedCardIds) {
      const card = this.cards.find(c => c.id === id);
      if (card && card.status !== CardStatus.mastered) {
        const newStatus = card.status === CardStatus.unlearned
          ? CardStatus.reviewing : CardStatus.mastered;
        // 通过不可变更新确保 @State 变更检测生效
        card.status = newStatus;
        await this.cardVm.updateCard(card);
      }
    }
    this.exitMultiSelectMode();
    await this.loadHomeData();
  }

  async batchRelearn() {
    AlertDialog.show({
      title: '清除学习数据',
      message: `将删除选中的 ${this.selectedCardIds.length} 张卡片的所有记忆记录，并重置学习进度。确定继续吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确定',
        fontColor: '#4A90D9',
        action: async () => {
          const recordDao = new MemoryRecordDao();
          for (const id of this.selectedCardIds) {
            const card = this.cards.find(c => c.id === id);
            if (card) {
              card.status = CardStatus.unlearned;
              card.easeFactor = 2.5;
              card.interval = 0;
              card.repetitions = 0;
              card.nextReviewTime = Date.now();
              await this.cardVm.updateCard(card);
              await recordDao.deleteByCardId(id);
            }
          }
          this.exitMultiSelectMode();
          await this.loadHomeData();
        }
      }
    });
  }

  async batchDelete() {
    AlertDialog.show({
      title: '批量删除',
      message: `确定要删除选中的 ${this.selectedCardIds.length} 张卡片吗？删除后不可恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#EF4444',
        action: async () => {
          for (const id of this.selectedCardIds) {
            await this.cardVm.deleteCard(id);
          }
          this.exitMultiSelectMode();
          await this.loadHomeData();
        }
      }
    });
  }

  async batchMoveToDeck(targetDeckIds: number[]) {
    for (const id of this.selectedCardIds) {
      const card = this.cards.find(c => c.id === id);
      if (!card) continue;
      // 第一个目标牌组：移动卡片（修改 deckId）
      card.deckId = targetDeckIds[0];
      await this.cardVm.updateCard(card);
      // 其余目标牌组：复制卡片到新牌组
      for (let i = 1; i < targetDeckIds.length; i++) {
        const copy: Card = {
          id: 0,
          deckId: targetDeckIds[i],
          type: card.type,
          front: card.front,
          options: card.options,
          correctAnswer: card.correctAnswer,
          displayOrder: card.displayOrder,
          analysis: card.analysis,
          status: card.status,
          easeFactor: card.easeFactor,
          interval: card.interval,
          repetitions: card.repetitions,
          nextReviewTime: card.nextReviewTime,
          createdAt: card.createdAt,
          updatedAt: card.updatedAt
        };
        await this.cardVm.createCard(copy);
      }
    }
    this.exitMultiSelectMode();
    await this.loadHomeData();
  }

  showDeckActionMenu(deck: Deck) {
    AlertDialog.show({
      title: deck.name,
      message: `当前: 每日新卡 ${(deck.dailyNewCards && deck.dailyNewCards > 0) ? deck.dailyNewCards : '默认'} 张, 每日复习 ${(deck.dailyReviewCards && deck.dailyReviewCards > 0) ? deck.dailyReviewCards : '默认'} 张`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '牌组设置',
        action: () => {
          this.openDeckSettings(deck);
        }
      },
      secondaryButton: {
        value: '删除牌组',
        fontColor: deck.isDefault ? '#CCCCCC' : '#EF4444',
        action: () => {
          if (!deck.isDefault) {
            this.confirmDeleteDeck(deck);
          }
        }
      }
    });
  }

  openDeckSettings(deck: Deck) {
    AppStorage.setOrCreate('currentEditDeck', deck);
    this.deckSettingsDialogController.open();
  }

  async saveDeckSettings(newLimit: number, reviewLimit: number, deckId: number) {
    await this.cardVm.updateDeckSettings(deckId, newLimit, reviewLimit);
    await this.loadHomeData();
  }

  confirmDeleteDeck(deck: Deck) {
    // 系统默认牌组不可删除
    if (deck.isDefault) {
      return;
    }
    AlertDialog.show({
      title: '删除牌组',
      message: `确定要删除「${deck.name}」吗？该牌组下的所有卡片也会被删除。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => { this.deletingDeckId = -1; }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#EF4444',
        action: async () => {
          await this.cardVm.deleteDeck(deck.id);
          this.deletingDeckId = -1;
          this.selectedDeckId = 0;
          await this.loadHomeData();
        }
      }
    });
  }
}

// ==================== 添加牌组对话框 ====================
@CustomDialog
struct AddDeckDialog {
  controller: CustomDialogController;
  onConfirm?: (name: string) => void;
  @State deckName: string = '';

  build() {
    Column() {
      Text('新建牌组')
  
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_PRIMARY)
        .margin({ bottom: 14 })

      TextInput({ placeholder: '输入牌组名称' })
        .fontSize(14)
        .width('100%')
        .height(42)
        .backgroundColor('#F5F5F7')
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.deckName = value;
        })

      Row({ space: 10 }) {
        Button('取消')
          .fontSize(14)
          .backgroundColor('#EEEEEF')
          .fontColor('#666')
          .layoutWeight(1)
          .height(42)
          .borderRadius(21)
          .onClick(() => {
            this.controller.close();
          })
        Button('确定')
          .fontSize(14)
          .backgroundColor('#4A90D9')
          .fontColor(Color.White)
          .layoutWeight(1)
          .height(42)
          .borderRadius(21)
          .onClick(() => {
            if (this.deckName.trim()) {
              this.onConfirm?.(this.deckName.trim());
              this.controller.close();
            }
          })
      }
      .width('100%')
      .margin({ top: 18 })
    }
    .padding(22)
  }
}

// ==================== 牌组设置对话框 ====================
@CustomDialog
struct DeckSettingsDialog {
  controller: CustomDialogController;
  deck: Deck = { id: 0, name: '', color: '', createdAt: 0, updatedAt: 0 };
  onSave?: (newLimit: number, reviewLimit: number, deckId: number) => void;
  @State newCardSelected: number = 0;
  @State reviewSelected: number = 0;
  private newCardRange: string[] = [];
  private reviewRange: string[] = [];

  aboutToAppear() {
    // 从 AppStorage 读取当前要编辑的牌组
    const stored: Deck | undefined = AppStorage.get<Deck>('currentEditDeck');
    if (stored) {
      this.deck = stored;
    }
    // 构建新卡范围：默认 + 5~200(步长5)
    this.newCardRange.push('默认');
    for (let i = 5; i <= 200; i += 5) {
      this.newCardRange.push(i.toString());
    }
    // 构建复习范围：默认 + 50~1000(步长50)
    this.reviewRange.push('默认');
    for (let i = 50; i <= 1000; i += 50) {
      this.reviewRange.push(i.toString());
    }
    // 设置当前选中
    const currentNew: number = (this.deck.dailyNewCards && this.deck.dailyNewCards > 0) ? this.deck.dailyNewCards : 0;
    this.newCardSelected = currentNew === 0 ? 0 : Math.round(currentNew / 5);
    const currentReview: number = (this.deck.dailyReviewCards && this.deck.dailyReviewCards > 0) ? this.deck.dailyReviewCards : 0;
    this.reviewSelected = currentReview === 0 ? 0 : Math.round(currentReview / 50);
  }

  build() {
    Column() {
      Text('牌组设置')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .margin({ bottom: 14 })

      Row({ space: 12 }) {
        // 左侧：每日新卡
        Column() {
          Text('每日新卡')
            .fontSize(13)
            .fontColor('#8E8E93')
            .margin({ bottom: 6 })
          TextPicker({ range: this.newCardRange, selected: this.newCardSelected })
            .onChange((value: string | string[], index: number | number[]) => {
              this.newCardSelected = index as number;
            })
        }
        .layoutWeight(1)

        // 分隔线
        Divider()
          .vertical(true)
          .height(120)
          .color('#E5E5E5')

        // 右侧：每日复习
        Column() {
          Text('每日复习')
            .fontSize(13)
            .fontColor('#8E8E93')
            .margin({ bottom: 6 })
          TextPicker({ range: this.reviewRange, selected: this.reviewSelected })
            .onChange((value: string | string[], index: number | number[]) => {
              this.reviewSelected = index as number;
            })
        }
        .layoutWeight(1)
      }
      .margin({ bottom: 16 })

      Row({ space: 10 }) {
        Button('取消')
          .fontSize(14)
          .backgroundColor('#EEEEEF')
          .fontColor('#666')
          .layoutWeight(1)
          .height(42)
          .borderRadius(21)
          .onClick(() => {
            this.controller.close();
          })
        Button('确定')
          .fontSize(14)
          .backgroundColor('#4A90D9')
          .fontColor(Color.White)
          .layoutWeight(1)
          .height(42)
          .borderRadius(21)
          .onClick(() => {
            if (this.deck && this.onSave) {
              const newVal: string = this.newCardRange[this.newCardSelected];
              const reviewVal: string = this.reviewRange[this.reviewSelected];
              const newLimit: number = (newVal === '默认') ? 0 : parseInt(newVal);
              const reviewLimit: number = (reviewVal === '默认') ? 0 : parseInt(reviewVal);
              this.onSave(newLimit, reviewLimit, this.deck.id);
            }
            this.controller.close();
          })
      }
      .width('100%')
    }
    .padding(22)
  }
}

// ==================== 移动到牌组对话框 ====================
@CustomDialog
struct MoveToDeckDialog {
  controller: CustomDialogController;
  @Link decks: Deck[];
  @State selectedDeckIds: number[] = [];
  onMoveToDeck?: (deckIds: number[]) => void;

  build() {
    Column() {
      Text('移动到牌组')
        
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_PRIMARY)
        .margin({ bottom: 14 })

      Scroll() {
        Column() {
          ForEach(this.decks, (deck: Deck) => {
            Row() {
        
        
      
              Checkbox()
                .select(this.selectedDeckIds.indexOf(deck.id) >= 0)
                .hitTestBehavior(HitTestMode.None)
                .margin({ right: 10 })

              Text(deck.name)
                .fontSize(15)
                .fontColor(TEXT_PRIMARY)
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 13, bottom: 13 })
            .borderRadius(10)
            .backgroundColor(this.selectedDeckIds.indexOf(deck.id) >= 0 ? '#E8F0FE' : '#F5F5F7')
            .border({
              width: this.selectedDeckIds.indexOf(deck.id) >= 0 ? 1.2 : 0,
              color: PRIMARY,
              style: BorderStyle.Solid
            })
            .margin({ bottom: 8 })
            .onClick(() => {
              const idx = this.selectedDeckIds.indexOf(deck.id);
              if (idx >= 0) {
                this.selectedDeckIds = this.selectedDeckIds.filter(id => id !== deck.id);
              } else {
                this.selectedDeckIds = [...this.selectedDeckIds, deck.id];
              }
            })
          }, (deck: Deck) => deck.id.toString())
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: 320 })
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)

      Row({ space: 10 }) {
        Button('取消')
          .fontSize(14)
          .backgroundColor('#EEEEEF')
          .fontColor('#666')
          .layoutWeight(1)
          .height(42)
          .borderRadius(21)
          .onClick(() => {
            this.controller.close();
          })
        Button('确定')
          .fontSize(14)
          .backgroundColor(PRIMARY)
          .fontColor(Color.White)
          .layoutWeight(1)
          .height(42)
          .borderRadius(21)
          .onClick(() => {
            if (this.selectedDeckIds.length > 0) {
              this.onMoveToDeck?.(this.selectedDeckIds);
              this.controller.close();
            }
          })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .padding(22)
  }
}