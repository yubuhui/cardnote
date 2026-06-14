import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { WebDAVSyncService } from '../service/WebDAVSyncService';
import { SyncResult, WebDAVConfig } from '../webdav/SyncModels';

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

  // 目录选择器
  @State showDirPicker: boolean = false;
  @State dirList: string[] = [];
  @State isLoadingDirs: boolean = false;
  @State currentDirPath: string = ''; // 当前浏览路径，空即根目录
  @State showCreateDialog: boolean = false;
  @State newDirName: string = '';

  aboutToAppear(): void {
    const ctx: Context = this.getUIContext().getHostContext()!;
    syncService.init(ctx);
    this.loadSettings();
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

  /** 打开目录选择器 */
  private async showDirectoryPicker(): Promise<void> {
    this.saveConfig();
    this.showDirPicker = true;
    this.currentDirPath = '';
    await this.loadDirectoryList('');
  }

  /** 加载指定路径下的目录列表 */
  private async loadDirectoryList(subPath: string): Promise<void> {
    this.isLoadingDirs = true;
    this.dirList = [];
    try {
      const dirs: string[] = await syncService.listDirectories(subPath);
      this.dirList = dirs;
    } catch (err) {
      promptAction.showToast({ message: '获取目录失败: ' + (err as Error).message, duration: 2000 });
      this.showDirPicker = false;
    } finally {
      this.isLoadingDirs = false;
    }
  }

  /** 进入子目录 */
  private async navigateInto(dirName: string): Promise<void> {
    const subPath: string = this.currentDirPath ? `${this.currentDirPath}/${dirName}` : dirName;
    this.currentDirPath = subPath;
    await this.loadDirectoryList(subPath);
  }

  /** 返回上级目录 */
  private async goUp(): Promise<void> {
    const parts: string[] = this.currentDirPath.split('/');
    parts.pop();
    const parentPath: string = parts.join('/');
    this.currentDirPath = parentPath;
    await this.loadDirectoryList(parentPath);
  }

  /** 选中当前目录（点击路径面包屑） */
  private selectCurrentDirectory(): void {
    this.syncPath = this.currentDirPath;
    this.showDirPicker = false;
  }

  /** 选择子目录作为同步目录 */
  private selectDirectory(dirName: string): void {
    const fullPath: string = this.currentDirPath ? `${this.currentDirPath}/${dirName}` : dirName;
    this.syncPath = fullPath;
    this.showDirPicker = false;
  }

  /** 打开新建目录弹窗 */
  private showCreateDirDialog(): void {
    this.newDirName = '';
    this.showCreateDialog = true;
  }

  /** 确认创建目录 */
  private async confirmCreateDirectory(): Promise<void> {
    const name: string = this.newDirName.trim();
    if (!name) {
      promptAction.showToast({ message: '请输入目录名', duration: 1500 });
      return;
    }
    try {
      await syncService.createDirectory(name, this.currentDirPath);
      promptAction.showToast({ message: `目录 "${name}" 已创建`, duration: 1500 });
      this.showCreateDialog = false;
      this.newDirName = '';
      // 刷新当前目录列表
      await this.loadDirectoryList(this.currentDirPath);
    } catch (err) {
      promptAction.showToast({ message: '创建失败: ' + (err as Error).message, duration: 2000 });
    }
  }

  // ==========================================
  // UI
  // ==========================================

  build() {
    Stack() {
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
        .backgroundColor('#F5F6FA')
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)

      // 目录选择器弹窗
      if (this.showDirPicker) {
        this.buildDirPickerDialog()
      }
    }
    .width('100%')
    .height('100%')
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
            .onChange((v: string) => { this.syncPath = v; })
          Text('选择')
            .fontSize(13)
            .fontColor('#1677FF')
            .padding({ left: 8, right: 4 })
            .onClick(() => { this.showDirectoryPicker(); })
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
            .onChange((v: string) => { this.password = v; })
          Text(this.showPassword ? '隐藏' : '显示')
            .fontSize(13)
            .fontColor('#1677FF')
            .padding({ left: 8 })
            .onClick(() => { this.showPassword = !this.showPassword; })
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
        .enabled(!this.isTesting && !this.isSyncing)
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
        .enabled(!this.isTesting && !this.isSyncing)
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

  /** 取上次同步时间的友好文本 */
  // 已在 loadSettings 中处理

  // ==========================================
  // 目录选择器弹窗
  // ==========================================

  @Builder
  buildDirPickerDialog() {
    Column() {
      // 弹窗卡片
      Column() {
        // 标题栏
        Row() {
          Text('选择同步目录')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333')
          Blank()
          Text('✕')
            .fontSize(18)
            .fontColor('#999')
            .onClick(() => { this.showDirPicker = false; })
        }
        .width('100%')
        .padding({ left: 16, right: 12, top: 14, bottom: 8 })

        // 当前路径面包屑
        Row() {
          Text('📂')
            .fontSize(14)
          Text(this.currentDirPath ? `/${this.currentDirPath}` : '/ (根目录)')
            .fontSize(12)
            .fontColor('#1677FF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 4 })
        }
        .width('100%')
        .padding({ left: 16, right: 12, bottom: 6 })
        .onClick(() => { this.selectCurrentDirectory(); })

        Divider().color('#E0E0E0').strokeWidth(0.5).width('100%')

        // 列表区域
        if (this.isLoadingDirs) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color('#1677FF')
            Text('正在获取目录...')
              .fontSize(13)
              .fontColor('#999')
              .margin({ top: 10 })
          }
          .width('100%')
          .height(160)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            // 返回上级（非根目录时显示）
            if (this.currentDirPath !== '') {
              ListItem() {
                Row() {
                  Text('📂')
                    .fontSize(16)
                  Text('..')
                    .fontSize(14)
                    .fontColor('#1677FF')
                    .layoutWeight(1)
                    .margin({ left: 8 })
                }
                .width('100%')
                .height(40)
                .padding({ left: 16, right: 12 })
                .onClick(() => { this.goUp(); })
              }
            }

            if (this.dirList.length === 0) {
              ListItem() {
                Text('此目录下无子目录')
                  .fontSize(13)
                  .fontColor('#999')
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 20, bottom: 20 })
              }
            }

            ForEach(this.dirList, (dir: string) => {
              ListItem() {
                Row() {
                  Text('📁')
                    .fontSize(16)
                  Text(dir)
                    .fontSize(14)
                    .fontColor('#333')
                    .layoutWeight(1)
                    .margin({ left: 8 })
                  Text('›')
                    .fontSize(16)
                    .fontColor('#CCC')
                }
                .width('100%')
                .height(44)
                .padding({ left: 16, right: 12 })
                .onClick(() => { this.navigateInto(dir); })
              }
            })
          }
          .width('100%')
          .constraintSize({ maxHeight: 240 })
          .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
        }

        Divider().color('#E0E0E0').strokeWidth(0.5).width('100%')

        // 底部操作栏
        Row() {
          Text('新建目录')
            .fontSize(14)
            .fontColor('#1677FF')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => { this.showCreateDirDialog(); })
          Blank()
          Text('确定')
            .fontSize(14)
            .fontColor('#1677FF')
            .fontWeight(FontWeight.Medium)
            .padding({ top: 12, bottom: 12, left: 16, right: 16 })
            .onClick(() => { this.selectCurrentDirectory(); })
          Text('取消')
            .fontSize(14)
            .fontColor('#999')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => { this.showDirPicker = false; })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('85%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .onClick(() => {}) // 阻止点击穿透到遮罩层

      // 创建目录弹窗（二级弹窗）
      if (this.showCreateDialog) {
        Column()
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
          .backgroundColor('rgba(0,0,0,0.3)')
          .onClick(() => { this.showCreateDialog = false; })

        Column() {
          Text('新建目录')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333')
            .margin({ top: 16, bottom: 12 })

          TextInput({ placeholder: '输入目录名', text: this.newDirName })
            .type(InputType.Normal)
            .fontSize(14)
            .width('100%')
            .height(40)
            .borderRadius(6)
            .backgroundColor('#F5F5F5')
            .onChange((v: string) => { this.newDirName = v; })

          Row() {
            Text('取消')
              .fontSize(14)
              .fontColor('#999')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .padding({ top: 14, bottom: 10 })
              .onClick(() => { this.showCreateDialog = false; })
            Text('创建')
              .fontSize(14)
              .fontColor('#1677FF')
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .padding({ top: 14, bottom: 10 })
              .onClick(() => { this.confirmCreateDirectory(); })
          }
          .width('100%')
          .margin({ top: 12 })
        }
        .width('75%')
        .backgroundColor(Color.White)
        .borderRadius(12)
        .padding({ left: 20, right: 20 })
        .onClick(() => {}) // 阻止穿透
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.4)')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.showDirPicker = false; })
  }

  // ==========================================
  // UI 结束
  // ==========================================
}
