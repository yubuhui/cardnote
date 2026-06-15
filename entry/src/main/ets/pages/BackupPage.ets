import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { BackupService, BackupSummary, BackupFileInfo } from '../service/BackupService';
import { WebDAVItem } from '../webdav/WebDAVClient';
import { formatFileSize } from '../utils/DateUtils';

@Entry
@Component
export struct BackupPage {
  private backupService: BackupService = BackupService.getInstance();

  // ========== 状态变量 ==========
  @State isLocalBackingUp: boolean = false;
  @State isExporting: boolean = false;
  @State isImporting: boolean = false;
  @State isCloudUploading: boolean = false;
  @State isCloudDownloading: boolean = false;
  @State isCloudListing: boolean = false;

  // 自动备份
  @State autoBackupEnabled: boolean = false;
  @State autoBackupFrequency: string = 'weekly';

  // 备份历史
  @State localBackups: BackupFileInfo[] = [];
  @State isLoadingBackups: boolean = false;

  // 云备份
  @State cloudConfigured: boolean = false;
  @State cloudBackups: WebDAVItem[] = [];

  // 自动备份定时器
  private autoBackupTimerId: number = -1;

  aboutToAppear(): void {
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

    this.autoBackupEnabled = this.backupService.isAutoBackupEnabled(ctx);
    this.autoBackupFrequency = this.backupService.getAutoBackupFrequency(ctx);
    this.loadLocalBackups(ctx);
    this.cloudConfigured = this.backupService.isCloudConfigured();

    if (this.autoBackupEnabled) {
      this.startAutoBackupTimer(ctx);
    }
  }

  aboutToDisappear(): void {
    this.stopAutoBackupTimer();
  }

  build() {
    Column() {
      this.buildTopBar()

      Scroll() {
        Column() {
          // 卡片1：创建备份
          this.buildCreateBackupCard()

          // 卡片2：自动备份
          this.buildAutoBackupCard()

          // 卡片3：云备份
          this.buildCloudBackupCard()

          // 卡片4：备份历史
          this.buildHistoryCard()
        }
        .padding(16)
        .padding({ bottom: 32 })
      }
      .align(Alignment.Top)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_color'))
  }

  // ==================== 顶部导航 ====================
  @Builder
  buildTopBar() {
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
      .backgroundColor($r('app.color.nav_back_bg'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => router.back())
      Text('备份')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Row().width(36).height(36)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 46, bottom: 12 })
    .backgroundColor($r('app.color.card_background'))
  }

  // ==================== 通用卡片容器 ====================
  @Builder
  buildCardHeader(title: string) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
    }
  }

  // ==================== 卡片1：创建备份 ====================
  @Builder
  buildCreateBackupCard() {
    Column() {
      this.buildCardHeader('创建备份')

      Text('将全部数据（牌组、卡片、学习记录、应用设置）导出为一个 JSON 文件')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(18)
        .margin({ top: 8 })

      Row() {
        Button(this.isLocalBackingUp ? '保存中...' : '备份到本地')
          .height(44)
          .layoutWeight(1)
          .fontSize(13)
          .backgroundColor(this.isLocalBackingUp ? $r('app.color.button_disabled_bg') : $r('app.color.primary_color'))
          .fontColor($r('app.color.button_text'))
          .enabled(!this.isLocalBackingUp && !this.isExporting)
          .borderRadius(10)
          .onClick(() => this.doLocalBackup())

        Blank().width(10)

        Button(this.isExporting ? '导出中...' : '导出到文件')
          .height(44)
          .layoutWeight(1)
          .fontSize(13)
          .backgroundColor(this.isExporting ? $r('app.color.button_disabled_bg') : $r('app.color.button_confirm_bg'))
          .fontColor($r('app.color.button_text'))
          .enabled(!this.isLocalBackingUp && !this.isExporting)
          .borderRadius(10)
          .onClick(() => this.doExportToFile())
      }
      .width('100%')
      .margin({ top: 14 })

      Button(this.isImporting ? '导入中...' : '导入备份文件')
        .width('100%')
        .height(44)
        .fontSize(14)
        .backgroundColor(this.isImporting ? $r('app.color.button_disabled_bg') : $r('app.color.button_warn_bg'))
        .fontColor($r('app.color.button_text'))
        .enabled(!this.isLocalBackingUp && !this.isExporting && !this.isImporting)
        .borderRadius(10)
        .margin({ top: 10 })
        .onClick(() => this.doImportFromFile())
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .shadow({ radius: 6, color: $r('app.color.card_shadow'), offsetY: 2 })
    .margin({ bottom: 12 })
  }

  // ==================== 卡片2：自动备份 ====================
  @Builder
  buildAutoBackupCard() {
    Column() {
      this.buildCardHeader('自动备份')

      Text('开启后将按频率自动备份到应用私有目录')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(18)
        .margin({ top: 8 })

      // 开关行
      Row() {
        Text('启用自动备份')
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.autoBackupEnabled })
          .onChange((isOn: boolean) => {
            this.autoBackupEnabled = isOn;
            const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
            this.backupService.setAutoBackupEnabled(ctx, isOn);
            if (isOn) {
              this.startAutoBackupTimer(ctx);
            } else {
              this.stopAutoBackupTimer();
            }
          })
      }
      .width('100%')
      .margin({ top: 14 })
      .padding(12)
      .backgroundColor($r('app.color.surface_option_bg'))
      .borderRadius(10)

      // 频率选择（仅在启用时显示）
      if (this.autoBackupEnabled) {
        Row() {
          Text('备份频率')
            .fontSize(13)
            .fontColor($r('app.color.text_tertiary'))
          Blank()
          this.buildFreqChip('每日', 'daily')
          this.buildFreqChip('每周', 'weekly')
          this.buildFreqChip('每月', 'monthly')
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .shadow({ radius: 6, color: $r('app.color.card_shadow'), offsetY: 2 })
    .margin({ bottom: 12 })
  }

  @Builder
  buildFreqChip(label: string, value: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.autoBackupFrequency === value ? $r('app.color.button_text') : $r('app.color.text_tertiary'))
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor(this.autoBackupFrequency === value ? $r('app.color.primary_color') : $r('app.color.freq_chip_unselected_bg'))
      .borderRadius(14)
      .margin({ left: 8 })
      .onClick(() => {
        this.autoBackupFrequency = value;
        const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
        this.backupService.setAutoBackupFrequency(ctx, value);
        this.stopAutoBackupTimer();
        this.startAutoBackupTimer(ctx);
      })
  }

  // ==================== 卡片3：云备份 ====================
  @Builder
  buildCloudBackupCard() {
    Column() {
      this.buildCardHeader('云备份')

      if (!this.cloudConfigured) {
        Text('通过 WebDAV 将备份上传/下载到云端')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(18)
          .margin({ top: 8 })

        Text('请先在「设置 → WebDAV 同步」中配置服务器')
          .fontSize(12)
          .fontColor($r('app.color.button_warn_bg'))
          .margin({ top: 10 })
          .padding(10)
          .width('100%')
          .backgroundColor($r('app.color.warn_hint_bg'))
          .borderRadius(8)
      } else {
        Text('上传本地最新数据到云端，或从云端下载备份恢复')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(18)
          .margin({ top: 8 })

        // 操作按钮行
        Row() {
          Button(this.isCloudUploading ? '上传中...' : '备份到云端')
            .fontSize(13)
            .height(42)
            .layoutWeight(1)
            .backgroundColor(this.isCloudUploading ? $r('app.color.button_disabled_bg') : $r('app.color.button_confirm_bg'))
            .fontColor($r('app.color.button_text'))
            .enabled(!this.isCloudUploading)
            .borderRadius(10)
            .onClick(() => this.doCloudUpload())

          Blank().width(12)

          Button(this.isCloudListing ? '加载中...' : '查看云端备份')
            .fontSize(13)
            .height(42)
            .layoutWeight(1)
            .backgroundColor(this.isCloudListing ? $r('app.color.button_disabled_bg') : $r('app.color.primary_color'))
            .fontColor($r('app.color.button_text'))
            .enabled(!this.isCloudListing)
            .borderRadius(10)
            .onClick(() => this.loadCloudBackups())
        }
        .width('100%')
        .margin({ top: 14 })

        // 云端备份列表
        if (this.cloudBackups.length > 0) {
          Text('云端备份列表')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 16, bottom: 6 })
            .width('100%')

          List() {
            ForEach(this.cloudBackups, (item: WebDAVItem, index: number) => {
              ListItem() {
                this.buildCloudItem(item)
              }
            })
          }
          .width('100%')
          .divider({ strokeWidth: 0.5, color: $r('app.color.divider_color') })
          .constraintSize({ maxHeight: 240 })
          .backgroundColor($r('app.color.surface_list_bg'))
          .borderRadius(8)
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .shadow({ radius: 6, color: $r('app.color.card_shadow'), offsetY: 2 })
    .margin({ bottom: 12 })
  }

  @Builder
  buildCloudItem(item: WebDAVItem) {
    Row() {
      Text(item.name.replace('cardnote_backup_', '').replace('.json', ''))
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(formatFileSize(item.size))
        .fontSize(10)
        .fontColor($r('app.color.placeholder_color'))
        .margin({ right: 8 })

      Button('下载恢复')
        .fontSize(10)
        .height(26)
        .padding({ left: 8, right: 8 })
        .backgroundColor($r('app.color.button_warn_bg'))
        .fontColor($r('app.color.button_text'))
        .borderRadius(4)
        .enabled(!this.isCloudDownloading)
        .onClick(() => this.doCloudDownload(item))
    }
    .width('100%')
    .padding({ top: 8, bottom: 8, left: 8, right: 8 })
  }

  // ==================== 卡片4：备份历史 ====================
  @Builder
  buildHistoryCard() {
    Column() {
      Row() {
        this.buildCardHeader('备份历史')
        Blank()
        if (this.localBackups.length > 0) {
          Text('↻')
            .fontSize(18)
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
              this.loadLocalBackups(ctx);
            })
        }
      }
      .width('100%')

      if (this.isLoadingBackups) {
        Text('加载中...')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 12 })
      } else if (this.localBackups.length === 0) {
        Text('暂无备份记录')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 14 })
          .width('100%')
          .textAlign(TextAlign.Center)
      } else {
        List() {
          ForEach(this.localBackups, (item: BackupFileInfo, index: number) => {
            ListItem() {
              this.buildHistoryItem(item)
            }
          })
        }
        .width('100%')
        .divider({ strokeWidth: 0.5, color: $r('app.color.divider_color') })
        .margin({ top: 8 })
        .backgroundColor($r('app.color.surface_list_bg'))
        .borderRadius(8)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .shadow({ radius: 6, color: $r('app.color.card_shadow'), offsetY: 2 })
    .margin({ bottom: 12 })
  }

  @Builder
  buildHistoryItem(item: BackupFileInfo) {
    Row() {
      Text(item.fileName.replace('cardnote_backup_', '').replace('.json', ''))
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Column() {
        Text(item.formattedTime)
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
        Text(item.formattedSize)
          .fontSize(9)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.End)
      .margin({ right: 8 })

      Button('恢复')
        .fontSize(10)
        .height(26)
        .width(56)
        .backgroundColor($r('app.color.button_warn_bg'))
        .fontColor($r('app.color.button_text'))
        .borderRadius(4)
        .onClick(() => this.confirmRestoreFromHistory(item))

      Button('删除')
        .fontSize(10)
        .height(26)
        .width(56)
        .backgroundColor($r('app.color.button_danger_bg'))
        .fontColor($r('app.color.button_text'))
        .borderRadius(4)
        .margin({ left: 4 })
        .onClick(() => this.confirmDeleteBackup(item))
    }
    .width('100%')
    .padding({ top: 8, bottom: 8, left: 8, right: 8 })
  }

  // ==================== 业务逻辑 ====================

  // --- 备份到本地（应用私有目录） ---
  async doLocalBackup(): Promise<void> {
    try {
      this.isLocalBackingUp = true;
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const jsonContent: string = await this.backupService.exportBackupJson(ctx);
      const fileName: string = this.backupService.saveBackupToLocal(ctx, jsonContent);
      const summary: BackupSummary = this.backupService.parseBackupSummary(jsonContent);
      this.showToast(`已备份到本地：${summary.deckCount} 牌组，${summary.cardCount} 卡片，${summary.recordCount} 记录`);
      console.info('Local backup saved:', fileName);
      this.loadLocalBackups(ctx);
    } catch (err) {
      const bizErr: BusinessError = err as BusinessError;
      console.error('Local backup failed:', bizErr.code, bizErr.message);
      this.showToast('本地备份失败，请重试');
    } finally {
      this.isLocalBackingUp = false;
    }
  }

  // --- 导出到文件管理器 ---
  async doExportToFile(): Promise<void> {
    try {
      this.isExporting = true;
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const jsonContent: string = await this.backupService.exportBackupJson(ctx);

      const now: Date = new Date();
      const pad2 = (n: number): string => n < 10 ? '0' + n : String(n);
      const fileName: string = `cardnote_backup_${now.getFullYear()}${pad2(now.getMonth() + 1)}${pad2(now.getDate())}_${pad2(now.getHours())}${pad2(now.getMinutes())}${pad2(now.getSeconds())}.json`;

      const saveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = [fileName];
      saveOptions.fileSuffixChoices = ['JSON 文件|.json'];

      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const uris: string[] = await documentPicker.save(saveOptions);

      if (uris.length > 0) {
        const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        fs.writeSync(file.fd, jsonContent);
        fs.closeSync(file);
      }

      const summary: BackupSummary = this.backupService.parseBackupSummary(jsonContent);
      this.showToast(`已导出：${summary.deckCount} 牌组，${summary.cardCount} 卡片，${summary.recordCount} 记录`);
      this.loadLocalBackups(ctx);
    } catch (err) {
      const bizErr: BusinessError = err as BusinessError;
      console.error('Export to file failed:', bizErr.code, bizErr.message);
      this.showToast('导出失败，请重试');
    } finally {
      this.isExporting = false;
    }
  }

  // --- 从文件导入备份 ---
  async doImportFromFile(): Promise<void> {
    try {
      this.isImporting = true;
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const uris: string[] = await documentPicker.select();

      if (uris.length === 0) {
        return;
      }

      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      const arrayBuffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, arrayBuffer);
      fs.closeSync(file);

      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const jsonString: string = decoder.decodeWithStream(new Uint8Array(arrayBuffer));

      let summary: BackupSummary;
      try {
        summary = this.backupService.parseBackupSummary(jsonString);
      } catch (_e) {
        this.showToast('无效的备份文件');
        return;
      }

      AlertDialog.show({
        title: '确认导入',
        message: `将覆盖当前全部数据：\n${summary.deckCount} 牌组 · ${summary.cardCount} 卡片 · ${summary.recordCount} 记录`,
        autoCancel: true,
        alignment: DialogAlignment.Center,
        primaryButton: {
          value: '确定导入',
          fontColor: $r('app.color.button_warn_bg'),
          action: async () => {
            try {
              const result: BackupSummary = await this.backupService.restoreFromBackup(ctx, jsonString);
              this.showToast(`导入完成：${result.deckCount} 牌组，${result.cardCount} 卡片`);
              this.loadLocalBackups(ctx);
            } catch (err) {
              console.error('Import from file failed:', JSON.stringify(err));
              this.showToast('导入失败');
            }
          }
        },
        secondaryButton: {
          value: '取消',
          fontColor: $r('app.color.text_tertiary'),
          action: () => {}
        }
      });
    } catch (err) {
      const bizErr: BusinessError = err as BusinessError;
      console.error('Import picker failed:', bizErr.code, bizErr.message);
      this.showToast('导入失败，请重试');
    } finally {
      this.isImporting = false;
    }
  }

  // --- 自动备份定时器 ---
  private startAutoBackupTimer(ctx: Context): void {
    this.stopAutoBackupTimer();
    const intervalMs: number = this.getFrequencyMs();
    if (intervalMs <= 0) {
      return;
    }
    this.autoBackupTimerId = setInterval(() => {
      this.backupService.performAutoBackup(ctx).then(() => {
        this.loadLocalBackups(ctx);
      });
    }, intervalMs);
  }

  private stopAutoBackupTimer(): void {
    if (this.autoBackupTimerId !== -1) {
      clearInterval(this.autoBackupTimerId);
      this.autoBackupTimerId = -1;
    }
  }

  private getFrequencyMs(): number {
    switch (this.autoBackupFrequency) {
      case 'daily':
        return 24 * 60 * 60 * 1000;
      case 'weekly':
        return 7 * 24 * 60 * 60 * 1000;
      case 'monthly':
        return 30 * 24 * 60 * 60 * 1000;
      default:
        return 0;
    }
  }

  // --- 备份历史 ---
  private loadLocalBackups(ctx: Context): void {
    this.isLoadingBackups = true;
    this.localBackups = this.backupService.listLocalBackups(ctx);
    this.isLoadingBackups = false;
  }

  confirmRestoreFromHistory(item: BackupFileInfo): void {
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    let jsonString: string;
    try {
      jsonString = this.backupService.readLocalBackup(ctx, item.fileName);
    } catch (_e) {
      this.showToast('读取备份文件失败');
      return;
    }

    let summary: BackupSummary;
    try {
      summary = this.backupService.parseBackupSummary(jsonString);
    } catch (_e) {
      this.showToast('无效的备份文件');
      return;
    }

    AlertDialog.show({
      title: '确认恢复',
      message: `将覆盖当前全部数据：\n${summary.deckCount} 牌组 · ${summary.cardCount} 卡片 · ${summary.recordCount} 记录`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '确定恢复',
        fontColor: $r('app.color.button_warn_bg'),
        action: async () => {
          try {
            const result: BackupSummary = await this.backupService.restoreFromBackup(ctx, jsonString);
            this.showToast(`恢复完成：${result.deckCount} 牌组，${result.cardCount} 卡片`);
          } catch (err) {
            console.error('Restore from history failed:', JSON.stringify(err));
            this.showToast('恢复失败');
          }
        }
      },
      secondaryButton: {
        value: '取消',
        fontColor: $r('app.color.text_tertiary'),
        action: () => {}
      }
    });
  }

  confirmDeleteBackup(item: BackupFileInfo): void {
    AlertDialog.show({
      title: '删除备份',
      message: `确定删除 ${item.fileName}？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '删除',
        fontColor: $r('app.color.button_danger_bg'),
        action: () => {
          const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
          if (this.backupService.deleteLocalBackup(ctx, item.fileName)) {
            this.showToast('已删除');
            this.loadLocalBackups(ctx);
          }
        }
      },
      secondaryButton: {
        value: '取消',
        fontColor: $r('app.color.text_tertiary'),
        action: () => {}
      }
    });
  }

  // --- 云备份 ---
  async doCloudUpload(): Promise<void> {
    try {
      this.isCloudUploading = true;
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const fileName: string = await this.backupService.uploadBackupToCloud(ctx);
      this.showToast(`已备份到云端：${fileName}`);
      this.loadCloudBackups();
    } catch (err) {
      console.error('Cloud upload failed:', JSON.stringify(err));
      this.showToast('云端备份失败，请检查 WebDAV 配置');
    } finally {
      this.isCloudUploading = false;
    }
  }

  async loadCloudBackups(): Promise<void> {
    try {
      this.isCloudListing = true;
      this.cloudBackups = await this.backupService.listCloudBackups();
    } catch (err) {
      console.error('List cloud backups failed:', JSON.stringify(err));
      this.showToast('获取云端备份列表失败');
    } finally {
      this.isCloudListing = false;
    }
  }

  doCloudDownload(item: WebDAVItem): void {
    AlertDialog.show({
      title: '从云端恢复',
      message: `将从云端下载 "${item.name}" 并覆盖当前全部数据，确定吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '确定恢复',
        fontColor: $r('app.color.button_warn_bg'),
        action: async () => {
          this.isCloudDownloading = true;
          try {
            const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
            const jsonString: string = await this.backupService.downloadCloudBackup(item.path);
            const summary: BackupSummary = await this.backupService.restoreFromBackup(ctx, jsonString);
            this.showToast(`恢复完成：${summary.deckCount} 牌组，${summary.cardCount} 卡片`);
          } catch (err) {
            console.error('Cloud download failed:', JSON.stringify(err));
            this.showToast('云端恢复失败');
          } finally {
            this.isCloudDownloading = false;
          }
        }
      },
      secondaryButton: {
        value: '取消',
        fontColor: $r('app.color.text_tertiary'),
        action: () => {}
      }
    });
  }

  // ==================== 工具方法 ====================
  private showToast(message: string): void {
    promptAction.showToast({ message: message, duration: 2000 });
  }
}
