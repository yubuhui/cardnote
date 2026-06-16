import { WebDAVSyncService } from '../service/WebDAVSyncService';
import { WebDAVConfig } from '../webdav/SyncModels';
import { DirPickerDialog } from './DirPickerDialog';
import { formatDateTime } from '../utils/DateUtils';

/** 单例同步服务 */
const syncService: WebDAVSyncService = WebDAVSyncService.getInstance();

@Entry
@Component
struct WebDavSyncPage {
  // 服务器配置
  @State serverUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State syncPath: string = '';

  // UI 状态
  @State isTesting: boolean = false;
  @State statusText: string = '';
  @State lastSyncText: string = '';

  // 上传/下载状态
  @State isUploading: boolean = false;
  @State isDownloading: boolean = false;

  // 密码可见性
  @State showPassword: boolean = false;

  // 同步开关
  @State syncEnabled: boolean = false;

  // 目录选择器（原生 CustomDialog）
  dirPickerController: CustomDialogController = new CustomDialogController({
    builder: DirPickerDialog({
      syncPath: $syncPath,
      syncService: syncService,
      onCloseDialog: () => { this.dirPickerController.close(); },
    }),
    customStyle: true,
    autoCancel: false,
    alignment: DialogAlignment.Center,
  });

  aboutToAppear(): void {
    this.syncEnabled = syncService.isSyncEnabled();
    this.loadSettings();
  }

  aboutToDisappear(): void {
    this.dirPickerController = null!;
  }

  /** 从持久化加载已有配置 */
  private loadSettings(): void {
    const config: WebDAVConfig | null = syncService.loadConfig();
    if (config) {
      this.serverUrl = config.baseUrl;
      this.username = config.username;
      this.password = config.password;
      this.syncPath = config.syncPath || 'cardnote';
    }

    const lastTime: number = syncService.getLastSyncTime();
    if (lastTime > 0) {
      const d: Date = new Date(lastTime);
      this.lastSyncText = `上次同步: ${formatDateTime(d)}`;
    } else {
      this.lastSyncText = '尚未同步';
    }
  }

  // ==========================================
  // 按钮响应
  // ==========================================

  /** 保存配置 */
  private saveConfig(): void {
    if (!this.serverUrl || !this.username || !this.password) {
      this.getUIContext().getPromptAction().showToast({ message: '请填写完整的服务器信息', duration: 2000 });
      return;
    }
    syncService.saveConfig({
      baseUrl: this.serverUrl,
      username: this.username,
      password: this.password,
      syncPath: this.syncPath || 'cardnote',
    });
    this.statusText = '配置已保存';
  }

  /** 测试连接 */
  private async testConnection(): Promise<void> {
    this.saveConfig();
    this.isTesting = true;
    this.statusText = '正在测试连接...';
    try {
      const ok: boolean = await syncService.testConnection();
      if (ok) {
        // 连接成功后，默认创建 cardnote 文件夹作为同步目录
        const currentPath: string = this.syncPath.trim();
        if (!currentPath) {
          try {
            await syncService.createDirectory('cardnote', '');
            this.syncPath = 'cardnote';
          } catch (_e) {
            // 目录可能已存在，直接使用
            this.syncPath = 'cardnote';
          }
          syncService.saveConfig({
            baseUrl: this.serverUrl,
            username: this.username,
            password: this.password,
            syncPath: 'cardnote',
          });
        }
        this.statusText = '连接成功！';
        this.getUIContext().getPromptAction().showToast({ message: 'WebDAV 连接成功', duration: 2000 });
      } else {
        this.statusText = '连接失败（请检查地址和认证信息）';
      }
    } catch (err) {
      this.statusText = '连接失败: ' + (err as Error).message;
    } finally {
      this.isTesting = false;
    }
  }

  /** 打开目录选择器（原生 CustomDialog） */
  private showDirectoryPicker(): void {
    this.dirPickerController.open();
  }

  /** 上传到云端 */
  private async uploadToCloud(): Promise<void> {
    if (this.isUploading || !this.syncEnabled) {
      return;
    }
    this.isUploading = true;
    this.statusText = '正在上传到云端...';
    const result = await syncService.pushToCloud();
    if (result.error) {
      this.statusText = result.error;
    } else {
      this.statusText = `上传完成 (${result.pushedDecks}个牌组)`;
      this.updateLastSyncTime();
    }
    this.isUploading = false;
  }

  /** 从云端下载 */
  private downloadFromCloud(): void {
    if (this.isDownloading || !this.syncEnabled) {
      return;
    }

    this.getUIContext().showAlertDialog({
      title: '确认下载',
      message: '从云端下载将覆盖本地数据，确定吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '确定',
        fontColor: $r('app.color.warning'),
        action: async () => {
          this.isDownloading = true;
          this.statusText = '正在从云端下载...';
          const result = await syncService.pullFromCloud();
          if (result.error) {
            this.statusText = result.error;
          } else {
            this.statusText = `下载完成 (${result.pulledDecks}个牌组)`;
            this.updateLastSyncTime();
          }
          this.isDownloading = false;
        }
      },
      secondaryButton: {
        value: '取消',
        fontColor: $r('app.color.text_secondary'),
        action: () => {}
      }
    });
  }

  private updateLastSyncTime(): void {
    const lastTime: number = syncService.getLastSyncTime();
    if (lastTime > 0) {
      const d: Date = new Date(lastTime);
      this.lastSyncText = `上次同步: ${formatDateTime(d)}`;
    }
  }

  // ==========================================
  // UI
  // ==========================================

  build() {
    Column() {
      // 顶部导航
      this.buildTopBar();

      // 内容区
      Scroll() {
        Column() {
          this.buildServerSection();
          this.buildActionSection();
          this.buildStatusSection();
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor($r('app.color.background'))
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

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
      .backgroundColor($r('app.color.surface'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => { this.getUIContext().getRouter().back(); })

      Text('WebDAV 同步')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Row().width(36)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 46, bottom: 12 })
    .backgroundColor($r('app.color.surface'))

    Divider().color($r('app.color.outline')).strokeWidth(0.5)
  }

  /** 服务器配置区域 */
  @Builder
  buildServerSection() {
    Column() {
      Text('服务器配置')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      Column() {
        // 服务器地址
        Row() {
          Text('服务器地址')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width(72)
          TextInput({ placeholder: 'https://dav.example.com/', text: this.serverUrl })
            .type(InputType.Normal)
            .fontSize(14)
            .layoutWeight(1)
            .backgroundColor($r('app.color.transparent'))
            .enabled(this.syncEnabled)
            .onChange((v: string) => { this.serverUrl = v; })
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })

        Divider().color($r('app.color.outline')).strokeWidth(0.5).margin({ left: 12 })

        // 同步目录
        Row() {
          Text('同步目录')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width(72)
          Text(this.syncPath || 'cardnote')
            .fontSize(14)
            .fontColor(this.syncEnabled ? $r('app.color.text_primary') : $r('app.color.disabled'))
            .margin({ left: 4 })
            .layoutWeight(1)
          Text('选择')
            .fontSize(13)
            .fontColor(this.syncEnabled ? $r('app.color.primary') : $r('app.color.disabled'))
            .padding({ left: 8, right: 4 })
            .onClick(() => {
              if (this.syncEnabled) {
                this.showDirectoryPicker();
              }
            })
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })

        Divider().color($r('app.color.outline')).strokeWidth(0.5).margin({ left: 12 })

        // 用户名
        Row() {
          Text('用户名')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width(72)
          TextInput({ placeholder: '请输入用户名', text: this.username })
            .type(InputType.Normal)
            .fontSize(14)
            .layoutWeight(1)
            .backgroundColor($r('app.color.transparent'))
            .enabled(this.syncEnabled)
            .onChange((v: string) => { this.username = v; })
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })

        Divider().color($r('app.color.outline')).strokeWidth(0.5).margin({ left: 12 })

        // 密码
        Row() {
          Text('密码')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width(72)
          TextInput({ placeholder: '请输入密码', text: this.password })
            .type(this.showPassword ? InputType.Normal : InputType.Password)
            .fontSize(14)
            .layoutWeight(1)
            .backgroundColor($r('app.color.transparent'))
            .enabled(this.syncEnabled)
            .onChange((v: string) => { this.password = v; })
          Text(this.showPassword ? '隐藏' : '显示')
            .fontSize(13)
            .fontColor(this.syncEnabled ? $r('app.color.primary') : $r('app.color.disabled'))
            .padding({ left: 8 })
            .onClick(() => {
              if (this.syncEnabled) {
                this.showPassword = !this.showPassword;
              }
            })
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })
      }
      .width('100%')
      .backgroundColor($r('app.color.surface'))
      .borderRadius(10)
    }
    .width('100%')
    .margin({ bottom: 16 })
  }

  /** 操作按钮区域 */
  @Builder
  buildActionSection() {
    Column() {
      // 测试连接
      Button(this.isTesting ? '测试中...' : '测试连接')
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(22)
        .fontColor($r('app.color.on_primary'))
        .enabled(this.syncEnabled && !this.isTesting)
        .onClick(() => { this.testConnection(); })

      // 上传到云端
      Button(this.isUploading ? '上传中...' : '上传到云端')
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor($r('app.color.success'))
        .borderRadius(22)
        .fontColor($r('app.color.on_primary'))
        .margin({ top: 10 })
        .enabled(this.syncEnabled && !this.isUploading)
        .onClick(() => { this.uploadToCloud(); })

      // 从云端下载
      Button(this.isDownloading ? '下载中...' : '从云端下载')
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor($r('app.color.warning'))
        .borderRadius(22)
        .fontColor($r('app.color.on_primary'))
        .margin({ top: 10 })
        .enabled(this.syncEnabled && !this.isDownloading)
        .onClick(() => { this.downloadFromCloud(); })
    }
    .width('100%')
    .margin({ bottom: 16 })
  }

  /** 状态区域 */
  @Builder
  buildStatusSection() {
    Column() {
      if (this.statusText) {
        Row() {
          Text(this.statusText)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .flexShrink(1)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.statusText.includes('失败') ? $r('app.color.danger_bg') : $r('app.color.surface'))
        .borderRadius(8)
        .margin({ bottom: 10 })
      }

      if (this.lastSyncText) {
        Text(this.lastSyncText)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
    }
    .width('100%')
  }
}
