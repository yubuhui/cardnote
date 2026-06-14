import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { WebDAVSyncService } from '../service/WebDAVSyncService';
import { SyncResult, WebDAVConfig } from '../webdav/SyncModels';
import { DirPickerDialog } from './DirPickerDialog';

/** 单例同步服务 */
const syncService: WebDAVSyncService = new WebDAVSyncService();

@Entry
@Component
export struct WebDavSyncPage {
  // 服务器配置
  @State serverUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State syncPath: string = '';

  // UI 状态
  @State isTesting: boolean = false;
  @State isSyncing: boolean = false;
  @State statusText: string = '';
  @State lastSyncText: string = '';

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
    const ctx: Context = this.getUIContext().getHostContext()!;
    syncService.init(ctx);
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
      this.syncPath = config.syncPath || 'kanjisync';
    }

    const lastTime: number = syncService.getLastSyncTime();
    if (lastTime > 0) {
      const d: Date = new Date(lastTime);
      this.lastSyncText = `上次同步: ${this.formatDate(d)}`;
    } else {
      this.lastSyncText = '尚未同步';
    }
  }

  private formatDate(d: Date): string {
    const pad: (n: number) => string = (n: number): string => (n < 10 ? '0' + n : String(n));
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  // ==========================================
  // 按钮响应
  // ==========================================

  /** 保存配置 */
  private saveConfig(): void {
    if (!this.serverUrl || !this.username || !this.password) {
      promptAction.showToast({ message: '请填写完整的服务器信息', duration: 2000 });
      return;
    }
    syncService.saveConfig({
      baseUrl: this.serverUrl,
      username: this.username,
      password: this.password,
      syncPath: this.syncPath || 'kanjisync',
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
        this.statusText = '连接成功！';
        promptAction.showToast({ message: 'WebDAV 连接成功', duration: 2000 });
      } else {
        this.statusText = '连接失败（请检查地址和认证信息）';
      }
    } catch (err) {
      this.statusText = '连接失败: ' + (err as Error).message;
    } finally {
      this.isTesting = false;
    }
  }

  /** 执行完整同步 */
  private async doSync(): Promise<void> {
    if (!syncService.isConfigured()) {
      this.statusText = '请先完成配置并测试连接';
      return;
    }
    this.isSyncing = true;
    this.statusText = '同步中...';

    const result: SyncResult = await syncService.fullSync();

    if (result.error) {
      this.statusText = result.error;
      promptAction.showToast({ message: '同步失败', duration: 2000 });
    } else {
      const dur: number = result.endTime - result.startTime;
      const parts: string[] = [];
      if (result.pulledDecks > 0) {
        parts.push(`拉取 ${result.pulledDecks} 个牌组`);
      }
      if (result.pushedDecks > 0) {
        parts.push(`推送 ${result.pushedDecks} 个牌组`);
      }
      if (result.deletedDecks > 0) {
        parts.push(`清理 ${result.deletedDecks} 个牌组`);
      }
      if (parts.length === 0) {
        this.statusText = '已是最新，无需同步';
      } else {
        this.statusText = parts.join('，') + `（耗时 ${(dur / 1000).toFixed(1)}s）`;
      }
      this.lastSyncText = `上次同步: ${this.formatDate(new Date())}`;
      promptAction.showToast({ message: '同步完成', duration: 2000 });
    }

    this.isSyncing = false;
  }

  /** 打开目录选择器（原生 CustomDialog） */
  private showDirectoryPicker(): void {
    this.dirPickerController.open();
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
          this.buildSyncToggle();
          this.buildServerSection();
          this.buildActionSection();
          this.buildStatusSection();
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor('#F5F6FA')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  buildTopBar() {
    Row() {
      Row() {
        Text('‹')
          .fontSize(22)
          .fontColor('#1A1A1A')
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor('#E0E0E0')
      .justifyContent(FlexAlign.Center)
      .onClick(() => { router.back(); })

      Text('WebDAV 同步')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Row().width(36)
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)

    Divider().color('#E0E0E0').strokeWidth(0.5)
  }

  /** 同步开关 */
  @Builder
  buildSyncToggle() {
    Row() {
      Text('启用同步')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333')
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: this.syncEnabled })
        .selectedColor('#1677FF')
        .onChange((isOn: boolean) => { this.syncEnabled = isOn; })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(10)
    .margin({ bottom: 16 })
  }

  /** 服务器配置区域 */
  @Builder
  buildServerSection() {
    Column() {
      Text('服务器配置')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#999')
        .width('100%')
        .margin({ bottom: 8 })

      Column() {
        // 服务器地址
        Row() {
          Text('服务器地址')
            .fontSize(14)
            .fontColor('#333')
            .width(72)
          TextInput({ placeholder: 'https://dav.example.com/', text: this.serverUrl })
            .type(InputType.Normal)
            .fontSize(14)
            .layoutWeight(1)
            .backgroundColor(Color.Transparent)
            .enabled(this.syncEnabled)
            .onChange((v: string) => { this.serverUrl = v; })
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })

        Divider().color('#F0F0F0').strokeWidth(0.5).margin({ left: 12 })

        // 同步目录
        Row() {
          Text('同步目录')
            .fontSize(14)
            .fontColor('#333')
            .width(72)
          TextInput({ placeholder: 'kanjisync', text: this.syncPath })
            .type(InputType.Normal)
            .fontSize(14)
            .layoutWeight(1)
            .backgroundColor(Color.Transparent)
            .enabled(this.syncEnabled)
            .onChange((v: string) => { this.syncPath = v; })
          Text('选择')
            .fontSize(13)
            .fontColor(this.syncEnabled ? '#1677FF' : '#B0B0B0')
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

        Divider().color('#F0F0F0').strokeWidth(0.5).margin({ left: 12 })

        // 用户名
        Row() {
          Text('用户名')
            .fontSize(14)
            .fontColor('#333')
            .width(72)
          TextInput({ placeholder: '请输入用户名', text: this.username })
            .type(InputType.Normal)
            .fontSize(14)
            .layoutWeight(1)
            .backgroundColor(Color.Transparent)
            .enabled(this.syncEnabled)
            .onChange((v: string) => { this.username = v; })
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })

        Divider().color('#F0F0F0').strokeWidth(0.5).margin({ left: 12 })

        // 密码
        Row() {
          Text('密码')
            .fontSize(14)
            .fontColor('#333')
            .width(72)
          TextInput({ placeholder: '请输入密码', text: this.password })
            .type(this.showPassword ? InputType.Normal : InputType.Password)
            .fontSize(14)
            .layoutWeight(1)
            .backgroundColor(Color.Transparent)
            .enabled(this.syncEnabled)
            .onChange((v: string) => { this.password = v; })
          Text(this.showPassword ? '隐藏' : '显示')
            .fontSize(13)
            .fontColor(this.syncEnabled ? '#1677FF' : '#B0B0B0')
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
      .backgroundColor(Color.White)
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
        .backgroundColor(this.isTesting ? '#A0C4FF' : '#1677FF')
        .borderRadius(22)
        .fontColor(Color.White)
        .enabled(this.syncEnabled && !this.isTesting && !this.isSyncing)
        .onClick(() => { this.testConnection(); })

      // 立即同步
      Button(this.isSyncing ? '同步中...' : '立即同步')
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor(this.isSyncing ? '#A0C4FF' : '#1677FF')
        .borderRadius(22)
        .fontColor(Color.White)
        .margin({ top: 12 })
        .enabled(this.syncEnabled && !this.isTesting && !this.isSyncing)
        .onClick(() => { this.doSync(); })
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
            .fontColor('#666')
            .flexShrink(1)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.statusText.includes('失败') ? '#FFF0F0' : '#F0F8FF')
        .borderRadius(8)
        .margin({ bottom: 10 })
      }

      if (this.lastSyncText) {
        Text(this.lastSyncText)
          .fontSize(13)
          .fontColor('#999')
          .width('100%')
      }
    }
    .width('100%')
  }
}
