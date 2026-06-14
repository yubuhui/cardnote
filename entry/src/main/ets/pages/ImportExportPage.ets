import { router } from '@kit.ArkUI';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { CardViewModel } from '../viewmodel/CardViewModel';
import { Card, CardStatus } from '../model/Card';
import { CardType } from '../model/CardTypeEnum';
import { Deck } from '../model/Deck';
import { shuffleFisherYates } from '../utils/ArrayUtils';
import ExcelJS from '@archermind/exceljs';

/** 解析后的预览条目 */
interface PreviewItem {
  front: string;
  answer: string;
  analysis: string;  // 解析
  valid: boolean;    // 格式是否有效
  cardType: CardType; // 题型
  options: string[];  // 选项数组（仅选择题）
}

@Entry
@Component
export struct ImportExportPage {
  @State exportCount: number = 0;
  /** 导出时指定牌组（0 = 全部） */
  @State exportDeckId: number = 0;
  /** 预览面板是否展开 */
  @State showPreview: boolean = false;
  /** 解析后待导入的卡片列表 */
  @State previewItems: PreviewItem[] = [];
  /** 是否正在导入中 */
  @State importing: boolean = false;
  /** 模板下载菜单是否展开 */
  private cardVm: CardViewModel = new CardViewModel();
  @State deckList: Deck[] = [];
  @State selectedDeckId: number = 1;

  aboutToAppear() {
    this.loadCounts();
    this.loadDecks();
  }

  async loadCounts() {
    try {
      if (this.exportDeckId === 0) {
        this.exportCount = await this.cardVm.getTotalCount();
      } else {
        const cards: Card[] = await this.cardVm.getCardsByDeckId(this.exportDeckId);
        this.exportCount = cards.length;
      }
    } catch (err) {
      console.error('Load card count failed:', JSON.stringify(err));
    }
  }

  async loadDecks() {
    try {
      this.deckList = await this.cardVm.getAllDecks();
      if (this.deckList.length > 0) {
        this.selectedDeckId = this.deckList[0].id;
      }
    } catch (err) {
      console.error('Load decks failed:', JSON.stringify(err));
    }
  }

  // ==================== 导出 ====================
  async doExport() {
    try {
      const cards: Card[] = this.exportDeckId === 0
        ? await this.cardVm.getAllCards()
        : await this.cardVm.getCardsByDeckId(this.exportDeckId);
      if (cards.length === 0) {
        this.showToast('没有卡片数据可导出');
        return;
      }

      // TXT 空行分隔格式，兼容三种题型
      let txtContent: string = '';
      for (let i = 0; i < cards.length; i++) {
        const card: Card = cards[i];
        // 清理字段中的制表符和换行符
        const cleanFront: string = card.front.replace(/\t/g, ' ').replace(/\n/g, ' ');
        const cleanAnalysis: string = (card.analysis || '').replace(/\t/g, ' ').replace(/\n/g, ' ');

        if (card.type === CardType.choice) {
          // 选择题：题目 → 选项行（每行一条）→ 答案 → 解析
          // 清理题目中可能已嵌入的（A）~（F），统一用「答案：X」行
          const frontToExport: string = cleanFront.replace(/（[A-F]）/g, '（□）');
          txtContent += frontToExport + '\n';
          // 选项
          for (const opt of card.options) {
            txtContent += opt.replace(/\t/g, ' ').replace(/\n/g, ' ') + '\n';
          }
          // 答案行（索引 → 字母）
          const answerIndex: number = parseInt(card.correctAnswer);
          if (!isNaN(answerIndex) && answerIndex >= 0 && answerIndex < 26) {
            const letter: string = String.fromCharCode('A'.charCodeAt(0) + answerIndex);
            txtContent += `答案：${letter}\n`;
          }
          // 解析行
          if (cleanAnalysis.length > 0) {
            txtContent += `解析：${cleanAnalysis}\n`;
          }
        } else if (card.type === CardType.fillBlank) {
          // 填空题：题目（含 [[...]]）→ 解析
          txtContent += cleanFront + '\n';
          if (cleanAnalysis.length > 0) {
            txtContent += `解析：${cleanAnalysis}\n`;
          }
        } else {
          // 问答题：题目 → 答案 → 解析
          const cleanAnswer: string = card.correctAnswer.replace(/\t/g, ' ').replace(/\n/g, ' ');
          txtContent += cleanFront + '\n';
          txtContent += cleanAnswer + '\n';
          if (cleanAnalysis.length > 0) {
            txtContent += cleanAnalysis + '\n';
          }
        }

        // 卡片间空行分隔
        if (i < cards.length - 1) {
          txtContent += '\n';
        }
      }

      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const saveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      const exportFileName: string = `${this.getExportDeckLabel()}.txt`;
      saveOptions.newFileNames = [exportFileName];
      saveOptions.fileSuffixChoices = ['TXT 文件|.txt'];

      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const uris: string[] = await documentPicker.save(saveOptions);

      if (uris.length === 0) {
        return;
      }

      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE);
      fs.writeSync(file.fd, txtContent);
      fs.closeSync(file);

      this.showToast(`已导出 ${cards.length} 张卡片`);
    } catch (err) {
      const bizErr = err as BusinessError;
      if (bizErr.code !== undefined) {
        console.error('Export failed:', bizErr.code, bizErr.message);
      }
    }
  }

  // ==================== 导入：选择文件 → 解析预览 ====================
  async pickFile() {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const selectOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      selectOptions.maxSelectNumber = 1;
      selectOptions.fileSuffixFilters = ['.txt', '.tsv', '.xlsx', '.xls'];

      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const uris: string[] = await documentPicker.select(selectOptions);

      if (uris.length === 0) {
        return;
      }

      const uri: string = uris[0];
      const isExcel: boolean = uri.toLowerCase().endsWith('.xlsx') || uri.toLowerCase().endsWith('.xls');

      // 读取文件
      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);

      let items: PreviewItem[];

      if (isExcel) {
        // Excel 解析：第一列=问题，第二列=答案，第三列=解析
        try {
          const workbook = new ExcelJS.Workbook();
          await workbook.xlsx.read(buffer);

          // 检查是否成功解析到工作表
          const sheetCount: number = workbook.worksheets.length;
          if (sheetCount === 0) {
            this.showToast(
              isExcel && uri.toLowerCase().endsWith('.xls') ?
              '无法解析 .xls 文件，请用 Excel 另存为 .xlsx 格式' :
              '无法解析 Excel 文件，请检查格式'
            );
            return;
          }

          const worksheet = workbook.getWorksheet(1);
          items = [];

          if (worksheet) {
            worksheet.eachRow({ includeEmpty: false }, (row, rowNumber: number) => {
              if (rowNumber === 1) {
                return; // 跳过表头行
              }
              const front: string = (row.getCell(1).value || '').toString().trim();
              const answer: string = (row.getCell(2).value || '').toString().trim();
              const analysis: string = (row.getCell(3).value || '').toString().trim();
              const valid: boolean = front.length > 0;
              items.push({ front, answer, analysis, valid, cardType: CardType.essay, options: [] });
            });
          }
        } catch (xlsxErr) {
          console.error('Excel parse failed:', JSON.stringify(xlsxErr));
          this.showToast('无法解析 Excel 文件，请检查格式（支持 .xlsx，.xls 需新版格式）');
          return;
        }
      } else {
        // TSV/TXT 解析：自动识别格式
        const textDecoder: util.TextDecoder = new util.TextDecoder('utf-8');
        const text: string = textDecoder.decode(new Uint8Array(buffer));

        items = [];
        if (text.indexOf('\t') !== -1) {
          // 格式A：制表符分隔（TSV / 旧版 TXT）—— 复用统一解析逻辑，支持选择/填空/问答
          const lines: string[] = text.split('\n').filter((line: string) => line.trim().length > 0);
          for (const line of lines) {
            const parts: string[] = line.split('\t').map((p: string) => p.trim());
            items.push(this.parseCardBlock(parts));
          }
        } else {
          // 格式B：空行分隔卡片（新版 TXT）
          // 支持三种题型：问答题、选择题、填空题
          const allLines: string[] = text.split('\n');
          let blockLines: string[] = [];
          const flushBlock = () => {
            if (blockLines.length >= 2) {
              items.push(this.parseCardBlock(blockLines));
            } else if (blockLines.length === 1) {
              items.push({
                front: blockLines[0], answer: '', analysis: '',
                valid: false, cardType: CardType.essay, options: []
              });
            }
            blockLines = [];
          };
          for (const rawLine of allLines) {
            const line: string = rawLine.trim();
            if (line.length === 0) {
              flushBlock();
            } else {
              blockLines.push(line);
            }
          }
          // 文件末尾的最后一张卡片（没有尾随空行）
          flushBlock();
        }
      }

      if (items.length === 0) {
        this.showToast('文件中没有可解析的数据');
        return;
      }

      this.previewItems = items;
      this.showPreview = true;
    } catch (err) {
      const bizErr = err as BusinessError;
      if (bizErr.code !== undefined) {
        console.error('Pick file failed:', bizErr.code, bizErr.message);
        this.showToast('文件读取失败，请检查文件格式');
      }
    }
  }

  /**
   * 解析一个卡片块（空行分隔的一组行），自动识别题型：
   * - 填空题：第一行含 [[...]]
   * - 选择题：有 3+ 选项行，或有「答案：X」/标题中嵌入（A）~（E）
   * - 问答题：其他
   */
  private parseCardBlock(blockLines: string[]): PreviewItem {
    const front: string = blockLines[0];

    // ---- 填空题：第一行包含 [[...]] ----
    if (front.includes('[[') && front.includes(']]')) {
      const blankMatch: RegExpMatchArray | null = front.match(/\[\[(.+?)\]\]/);
      const answer: string = blankMatch ? blankMatch[1] : '';
      const analysis: string = this.extractAnalysis(blockLines.slice(1));
      return {
        front, answer, analysis,
        valid: answer.length > 0,
        cardType: CardType.fillBlank,
        options: []
      };
    }

    // ---- 分离选项行 / 答案行 / 解析行 ----
    const remaining: string[] = blockLines.slice(1);
    const optionLines: string[] = [];
    let analysisFromLine: string = '';
    let explicitAnswerLetter: string = '';

    for (const line of remaining) {
      if (line.startsWith('解析：') || line.startsWith('解析:')) {
        analysisFromLine = line.replace(/^解析[：:]/, '').trim();
      } else if (line.startsWith('答案：') || line.startsWith('答案:')) {
        const match: RegExpMatchArray | null = line.match(/^答案[：:]([A-F])/);
        if (match) {
          explicitAnswerLetter = match[1];
        }
      } else {
        optionLines.push(line);
      }
    }

    // ---- 选择题：选项行 ≥ 3，或有明确答案标记 + ≥ 2 选项 ----
    if (optionLines.length >= 3 ||
      (optionLines.length >= 2 && explicitAnswerLetter.length > 0) ||
      (optionLines.length >= 2 && /（[A-F]）/.test(front) && explicitAnswerLetter.length === 0)) {

      // 优先使用显式「答案：X」行，否则从题目中提取嵌入的（A）~（E）
      const answerLetter: string = explicitAnswerLetter.length > 0 ? explicitAnswerLetter :
        (front.match(/（([A-F])）/)?.[1] ?? '');
      // 清理题目中嵌入的答案标记：光合作用的场所（C）→ 光合作用的场所（□）
      const cleanedFront: string = answerLetter.length > 0 ? front.replace(/（[A-F]）/, '（□）') : front;
      const answerIndex: number = answerLetter.length > 0 ?
        answerLetter.charCodeAt(0) - 'A'.charCodeAt(0) : -1;
      const correctAnswer: string = (answerIndex >= 0 && answerIndex < optionLines.length) ?
        answerIndex.toString() : '';

      return {
        front: cleanedFront,
        answer: correctAnswer,
        analysis: analysisFromLine,
        valid: optionLines.length >= 2 && correctAnswer.length > 0,
        cardType: CardType.choice,
        options: optionLines
      };
    }

    // ---- 普通问答题（原有逻辑） ----
    const answer: string = blockLines.length >= 2 ? blockLines[1] : '';
    const analysis: string = this.extractAnalysis(blockLines.slice(2));
    return {
      front, answer, analysis,
      valid: front.length > 0 && answer.length > 0,
      cardType: CardType.essay,
      options: []
    };
  }

  /** 从行数组中提取解析文本（跳过以「解析：」开头的标记） */
  private extractAnalysis(lines: string[]): string {
    for (const line of lines) {
      if (line.startsWith('解析：') || line.startsWith('解析:')) {
        return line.replace(/^解析[：:]/, '').trim();
      }
    }
    // 没有「解析：」前缀时，取最后一行作为解析（兼容旧格式）
    return lines.length > 0 ? lines[lines.length - 1].trim() : '';
  }

  // ==================== 确认导入 ====================
  async confirmImport() {
    this.importing = true;
    try {
      const validItems: PreviewItem[] = this.previewItems.filter((item: PreviewItem) => item.valid);
      if (validItems.length === 0) {
        this.showToast('没有可导入的有效卡片');
        this.importing = false;
        return;
      }

      const now: number = Date.now();
      let successCount: number = 0;

      for (const item of validItems) {
        // 为选择题生成随机显示顺序
        let displayOrder: number[] = [];
        if (item.cardType === CardType.choice && item.options.length > 0) {
          displayOrder = item.options.map((_, i: number) => i);
          displayOrder = shuffleFisherYates(displayOrder);
        }

        const card: Card = {
          id: 0,
          deckId: this.selectedDeckId,
          type: item.cardType,
          front: item.front,
          options: item.options,
          correctAnswer: item.answer,
          displayOrder: displayOrder,
          analysis: item.analysis || '',
          status: CardStatus.unlearned,
          easeFactor: 2.5,
          interval: 0,
          repetitions: 0,
          nextReviewTime: now,
          createdAt: now,
          updatedAt: now
        };

        await this.cardVm.createCard(card);
        successCount++;
      }

      this.exportCount += successCount;
      this.showPreview = false;
      this.previewItems = [];
      this.showToast(`成功导入 ${successCount} 张卡片`);
    } catch (err) {
      console.error('Import failed:', JSON.stringify(err));
      this.showToast('导入失败，请重试');
    } finally {
      this.importing = false;
    }
  }

  // ==================== 取消预览 ====================
  cancelPreview() {
    this.showPreview = false;
    this.previewItems = [];
  }

  showToast(message: string) {
    promptAction.showToast({ message: message, duration: 2000 });
  }

  // ==================== 统计条数 ====================
  getValidCount(): number {
    return this.previewItems.filter((item: PreviewItem) => item.valid).length;
  }

  getInvalidCount(): number {
    return this.previewItems.filter((item: PreviewItem) => !item.valid).length;
  }

  /** 当前选中牌组的显示标签 */
  getSelectedDeckLabel(): string {
    const d: Deck | undefined = this.deckList.find((deck: Deck) => deck.id === this.selectedDeckId);
    return d ? d.name : '默认牌组';
  }

  /** 导出牌组标签（含"全部"） */
  getExportDeckLabel(): string {
    if (this.exportDeckId === 0) {
      return '全部卡片';
    }
    const d: Deck | undefined = this.deckList.find((deck: Deck) => deck.id === this.exportDeckId);
    return d ? d.name : '默认牌组';
  }

  /** 切换导出牌组时刷新计数 */
  async onExportDeckChange(index: number) {
    // 0 位是 "全部卡片"
    if (index === 0) {
      this.exportDeckId = 0;
    } else if (index > 0 && index - 1 < this.deckList.length) {
      this.exportDeckId = this.deckList[index - 1].id;
    }
    await this.loadCounts();
  }

  // ==================== UI ====================
  build() {
    Column() {
      // 顶部导航
      Row() {
        Row() {
          Text('‹')
            .fontSize(22)
            .fontColor('#1A1A1A')
            .textAlign(TextAlign.Center)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('#E0E0E0')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          if (this.showPreview) {
            this.cancelPreview();
          } else {
            router.back();
          }
        })
        Text(this.showPreview ? '预览导入' : '导入与导出')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        // 右上角隐藏菜单按钮（原生下拉菜单）
        Text('⋯')
          .fontSize(22)
          .fontColor('#666')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .bindMenu([
            {
              value: '下载 TXT 模板',
              action: () => { this.downloadTxtTemplate(); }
            } as MenuElement,
            {
              value: '下载 TSV 模板',
              action: () => { this.downloadTsvTemplate(); }
            } as MenuElement,
            {
              value: '下载 XLSX 模板',
              action: () => { this.downloadXlsxTemplate(); }
            } as MenuElement,
          ] as Array<MenuElement>, {
            title: '下载导入模板'
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 46, bottom: 12 })
      .backgroundColor(Color.White)


      if (this.showPreview) {
        this.buildPreviewPanel();
      } else {
        this.buildMainPanel();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  /** 主面板 */
  @Builder
  buildMainPanel() {
    Scroll() {
      Column() {
        // 导出卡片
        this.buildSection('导出卡片',
          `共有 ${this.exportCount} 张卡片，将导出为 TXT 文本文件（支持选择/填空/问答）。`,
          '"问题\\n答案"')
        // 导出牌组选择
        Row() {
          Text('牌组')
            .fontSize(13)
            .fontColor('#888')
            .margin({ right: 10 })
          Select([
            { value: '全部卡片' } as SelectOption,
            ...this.deckList.map((deck: Deck) => {
              const opt: SelectOption = { value: deck.name };
              return opt;
            })
          ])
            .value(this.getExportDeckLabel())
            .selected(this.exportDeckId === 0 ? 0 : this.deckList.findIndex((d: Deck) => d.id === this.exportDeckId) + 1)
            .onSelect((index: number) => {
              this.onExportDeckChange(index);
            })
            .selectedOptionBgColor('#F0F6FF')
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 12 })
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor('#F8F9FC')
        .borderRadius(10)

        Button(`导出 (${this.exportCount} 条)`)
          .width('100%')
          .height(48)
          .backgroundColor(this.exportCount > 0 ? '#4A90D9' : '#CCC')
          .fontColor(Color.White)
          .enabled(this.exportCount > 0)
          .borderRadius(10)
          .margin({ top: 12 })
          .onClick(() => { this.doExport() })

        Divider()
          .height(1)
          .color('#E8E8E8')
          .margin({ top: 20, bottom: 20 })

        // 导入卡片
        this.buildSection('导入卡片',
          `选择 TSV/TXT/XLSX 文件，解析后预览再确认导入。`,
          'A列=问题  B列=答案  C列=解析')
        Button('选择文件')
          .width('100%')
          .height(48)
          .backgroundColor('#4A90D9')
          .fontColor(Color.White)
          .borderRadius(10)
          .margin({ top: 12 })
          .onClick(() => { this.pickFile() })
      }
      .padding(16)
    }
    .align(Alignment.Top)
    .layoutWeight(1)
  }

  /** 题型角标 */
  @Builder
  buildTypeBadge(item: PreviewItem) {
    if (item.cardType === CardType.choice) {
      Text('🧩 选择')
        .fontSize(10)
        .fontColor(Color.White)
        .padding({ left: 5, right: 5, top: 2, bottom: 2 })
        .backgroundColor('#E6A23C')
        .borderRadius(4)
        .margin({ left: 4 })
    } else if (item.cardType === CardType.fillBlank) {
      Text('✏️ 填空')
        .fontSize(10)
        .fontColor(Color.White)
        .padding({ left: 5, right: 5, top: 2, bottom: 2 })
        .backgroundColor('#67C23A')
        .borderRadius(4)
        .margin({ left: 4 })
    }
  }

  /** 预览面板 */
  @Builder
  buildPreviewPanel() {
    Column() {
      // 统计条
      Row() {
        Text(`共 ${this.previewItems.length} 行`)
          .fontSize(14)
          .fontColor('#555')
        Text(`✅ ${this.getValidCount()} 有效`)
          .fontSize(14)
          .fontColor('#34A853')
          .margin({ left: 16 })
        if (this.getInvalidCount() > 0) {
          Text(`❌ ${this.getInvalidCount()} 无效`)
            .fontSize(14)
            .fontColor('#EA4335')
            .margin({ left: 16 })
        }
        Blank()
        Text('点击无效行可查看详情')
          .fontSize(11)
          .fontColor('#AAA')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 牌组选择
      Row() {
        Text('导入到')
          .fontSize(13)
          .fontColor('#888')
        Select(this.deckList.map((deck: Deck) => {
          const opt: SelectOption = { value: deck.name };
          return opt;
        }))
          .value(this.getSelectedDeckLabel())
          .selected(this.deckList.findIndex((d: Deck) => d.id === this.selectedDeckId))
          .onSelect((index: number) => {
            if (index >= 0 && index < this.deckList.length) {
              this.selectedDeckId = this.deckList[index].id;
            }
          })
          .selectedOptionBgColor('#F0F6FF')
          .layoutWeight(1)
          .margin({ left: 10 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 12 })
      .backgroundColor(Color.White)
      .border({ width: { bottom: 0.5 }, color: '#EEE' })

      // 预览列表
      List() {
        ForEach(this.previewItems, (item: PreviewItem, index: number) => {
          ListItem() {
            Row() {
              // 序号 + 状态
              Text(`${index + 1}`)
                .fontSize(12)
                .fontColor(item.valid ? '#34A853' : '#EA4335')
                .fontWeight(FontWeight.Bold)
                .width(28)
                .textAlign(TextAlign.Center)

                // 题型角标
                if (item.valid) {
                  this.buildTypeBadge(item)
                }

              Column() {
                Text(item.front || '(空)')
                  .fontSize(14)
                  .fontColor('#333')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')

                if (item.valid) {
                  Text(`→ ${item.answer || '(空答案)'}`)
                    .fontSize(12)
                    .fontColor('#888')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')

                  if (item.analysis.length > 0) {
                    Text(`📝 ${item.analysis}`)
                      .fontSize(11)
                      .fontColor('#AAA')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                  }
                } else {
                  Text('格式无效：缺少必要数据')
                    .fontSize(11)
                    .fontColor('#EA4335')
                    .width('100%')
                }
              }
              .layoutWeight(1)
              .margin({ left: 8 })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12, left: 12, right: 12 })
            .alignItems(VerticalAlign.Center)
          }
          .border({ width: { bottom: 0.5 }, color: '#EEE' })
        }, (item: PreviewItem, index: number) => `${index}_${item.front}`)
      }
      .layoutWeight(1)
      .backgroundColor(Color.White)
      .width('100%')

      // 底部操作栏
      Row() {
        Button('取消')
          .flexGrow(1)
          .height(48)
          .backgroundColor(Color.White)
          .fontColor('#666')
          .borderRadius(10)
          .border({ width: 1, color: '#DDD' })
          .onClick(() => { this.cancelPreview() })

        Button(`确认导入 ${this.getValidCount()} 条`)
          .flexGrow(2)
          .height(48)
          .backgroundColor(this.getValidCount() > 0 ? '#4A90D9' : '#CCC')
          .fontColor(Color.White)
          .borderRadius(10)
          .enabled(this.getValidCount() > 0 && !this.importing)
          .margin({ left: 12 })
          .onClick(() => { this.confirmImport() })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 30 })
      .backgroundColor('#FAFAFA')
    }
    .width('100%')
    .layoutWeight(1)
  }


  // ==================== 模板下载 ====================

  /** 模板内容——TXT/TSV 共用同一份示例数据（含问答题、选择题、填空题） */
  private getTemplateText(): string {
    return `问题（带解析）
答案
解析

问题（不带解析）
答案

光合作用的场所（不带解析）
叶绿体

光合作用的场所（带解析）
叶绿体
光合作用的场所是叶绿体

光合作用的场所（C）（选择题不带解析）
线粒体
细胞壁
叶绿体
细胞膜

光合作用的场所（选择题带解析）
线粒体
叶绿体
细胞壁
答案：B
解析：光合作用的场所是叶绿体

光合作用的场所是[[叶绿体]]。
解析：光合作用的场所是叶绿体。`;
  }

  async downloadTxtTemplate() {
    await this.saveTemplateFile('导入模板.txt', this.getTemplateText(), 'TXT');
  }

  async downloadTsvTemplate() {
    await this.saveTemplateFile('导入模板.tsv', this.getTemplateText(), 'TSV');
  }

  async downloadXlsxTemplate() {
    try {
      const workbook = new ExcelJS.Workbook();
      const worksheet = workbook.addWorksheet('卡片模板');

      // 表头
      const headerRow = worksheet.addRow(['问题', '答案', '解析']);
      headerRow.eachCell((cell) => {
        cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        cell.fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: 'FF4A90D9' }
        } as ExcelJS.FillPattern;
        cell.alignment = { horizontal: 'center', vertical: 'middle' } as ExcelJS.Alignment;
        cell.border = {
          top: { style: 'thin' },
          left: { style: 'thin' },
          bottom: { style: 'thin' },
          right: { style: 'thin' }
        } as ExcelJS.Borders;
      });

      // 示例数据（与 TXT 模板对应的 4 张卡片）
      const sampleData: [string, string, string][] = [
        ['问题（带解析）', '答案', '解析'],
        ['问题（不带解析）', '答案', ''],
        ['光合作用的场所（不带解析）', '叶绿体', ''],
        ['光合作用的场所（带解析）', '叶绿体', '光合作用的场所是叶绿体'],
      ];

      for (let si = 0; si < sampleData.length; si++) {
        const sRow: [string, string, string] = sampleData[si];
        worksheet.addRow([sRow[0], sRow[1], sRow[2]]);
      }

      // 列宽
      worksheet.getColumn(1).width = 32;
      worksheet.getColumn(2).width = 28;
      worksheet.getColumn(3).width = 36;

      // 生成 buffer
      // 生成 XLSX 二进制数据
      const wbBuffer: Object = await workbook.xlsx.writeBuffer();

      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const saveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = ['导入模板.xlsx'];
      saveOptions.fileSuffixChoices = ['XLSX 文件|.xlsx'];

      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const uris: string[] = await documentPicker.save(saveOptions);
      if (uris.length === 0) {
        return;
      }

      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE);
      fs.writeSync(file.fd, wbBuffer as ArrayBuffer);
      fs.closeSync(file);
      this.showToast('XLSX 模板已保存');
    } catch (err) {
      console.error('XLSX template save failed:', JSON.stringify(err));
      this.showToast('XLSX 模板保存失败');
    }
  }

  async saveTemplateFile(defaultName: string, content: string, label: string) {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const saveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = [defaultName];
      saveOptions.fileSuffixChoices = [`${label} 文件|${defaultName.substring(defaultName.lastIndexOf('.'))}`];

      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const uris: string[] = await documentPicker.save(saveOptions);
      if (uris.length === 0) {
        return;
      }

      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE);
      fs.writeSync(file.fd, content);
      fs.closeSync(file);
      this.showToast(`${label} 模板已保存`);
    } catch (err) {
      console.error(`${label} template save failed:`, JSON.stringify(err));
      this.showToast(`${label} 模板保存失败`);
    }
  }

  @Builder
  buildSection(title: string, desc: string, example: string) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333')
        .margin({ bottom: 4 })

      Text(desc)
        .fontSize(13)
        .fontColor('#888')
        .margin({ bottom: 12 })

      Text(example)
        .fontSize(12)
        .fontColor('#555')
        .fontFamily('Courier New')
        .lineHeight(20)
        .backgroundColor('#F8F9FA')
        .borderRadius(10)
        .padding(12)
        .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }
}
