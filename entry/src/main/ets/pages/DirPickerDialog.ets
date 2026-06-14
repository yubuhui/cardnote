import { promptAction } from '@kit.ArkUI';
import { WebDAVSyncService } from '../service/WebDAVSyncService';

// ==========================================
// 新建目录弹窗（原生 CustomDialog）
// ==========================================
@CustomDialog
struct CreateDirDialog {
  controller: CustomDialogController;
  @State newDirName: string = '';
  syncService!: WebDAVSyncService;
  currentDirPath: string = '';
  onCreated?: () => void;
  onCloseDialog?: () => void;

  aboutToAppear(): void {
    this.newDirName = '';
  }

  private closeDialog(): void {
    if (this.onCloseDialog) {
      this.onCloseDialog();
    } else {
      this.controller?.close();
    }
  }

  private async confirmCreateDirectory(): Promise<void> {
    const name: string = this.newDirName.trim();
    if (!name) {
      promptAction.showToast({ message: '请输入目录名', duration: 1500 });
      return;
    }
    try {
      await this.syncService.createDirectory(name, this.currentDirPath);
      promptAction.showToast({ message: `目录 "${name}" 已创建`, duration: 1500 });
      this.closeDialog();
      if (this.onCreated) {
        this.onCreated();
      }
    } catch (err) {
      promptAction.showToast({ message: '创建失败: ' + (err as Error).message, duration: 2000 });
    }
  }

  build() {
    Column() {
      Text('新建目录')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333')
        .margin({ top: 18, bottom: 14 })

      TextInput({ placeholder: '输入目录名', text: this.newDirName })
        .type(InputType.Normal)
        .fontSize(14)
        .width('100%')
        .height(42)
        .borderRadius(8)
        .backgroundColor('#F5F5F5')
        .onChange((v: string) => { this.newDirName = v; })

      Row() {
        Text('取消')
          .fontSize(14)
          .fontColor('#999')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 14, bottom: 10 })
          .onClick(() => { this.closeDialog(); })
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
      .margin({ top: 14 })
    }
    .width('75%')
    .backgroundColor(Color.White)
    .borderRadius(12)
    .padding({ left: 20, right: 20 })
  }
}

// ==========================================
// 目录选择器（原生 CustomDialog）
// ==========================================
@CustomDialog
export struct DirPickerDialog {
  controller: CustomDialogController;
  @Link syncPath: string;
  syncService!: WebDAVSyncService;
  onCloseDialog?: () => void;

  @State dirList: string[] = [];
  @State isLoadingDirs: boolean = false;
  @State currentDirPath: string = '';

  // 新建目录弹窗的控制器
  private createDirController?: CustomDialogController;

  aboutToAppear(): void {
    this.loadDirectoryList('');
  }

  /** 加载指定路径下的目录列表 */
  private async loadDirectoryList(subPath: string): Promise<void> {
    this.isLoadingDirs = true;
    this.dirList = [];
    try {
      const dirs: string[] = await this.syncService.listDirectories(subPath);
      this.dirList = dirs;
    } catch (err) {
      promptAction.showToast({ message: '获取目录失败: ' + (err as Error).message, duration: 2000 });
      this.closeDialog();
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

  /** 关闭当前弹窗 */
  private closeDialog(): void {
    if (this.onCloseDialog) {
      this.onCloseDialog();
    } else {
      this.controller?.close();
    }
  }

  /** 选中当前目录 */
  private selectCurrentDirectory(): void {
    this.syncPath = this.currentDirPath;
    this.closeDialog();
  }

  /** 打开新建目录弹窗（原生 CustomDialog） */
  private showCreateDirDialog(): void {
    this.createDirController = new CustomDialogController({
      builder: CreateDirDialog({
        syncService: this.syncService,
        currentDirPath: this.currentDirPath,
        onCreated: () => { this.loadDirectoryList(this.currentDirPath); },
        onCloseDialog: () => { this.createDirController?.close(); },
      }),
      alignment: DialogAlignment.Center,
      customStyle: true,
      autoCancel: true,
    });
    this.createDirController.open();
  }

  build() {
    Column() {
      // 弹窗卡片（固定宽高，超出滚动）
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
            .onClick(() => { this.closeDialog(); })
        }
        .width('100%')
        .padding({ left: 16, right: 12, top: 14, bottom: 8 })

        // 当前路径面包屑
        Row() {
          Text('📂')
            .fontSize(14)
          // 根目录
          Text('根目录')
            .fontSize(12)
            .fontColor('#1677FF')
            .padding({ left: 6, right: 4 })
            .onClick(() => {
              this.currentDirPath = '';
              this.loadDirectoryList('');
            })

          // 各层级目录
          ForEach(this.currentDirPath ? this.currentDirPath.split('/') : [], (seg: string, idx: number) => {
            Row() {
              Text('›')
                .fontSize(11)
                .fontColor('#999')
                .margin({ left: 2, right: 4 })
              Text(seg)
                .fontSize(12)
                .fontColor('#1677FF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .constraintSize({ maxWidth: 120 })
                .padding({ right: 2 })
            }
            .onClick(() => {
              const parts: string[] = this.currentDirPath.split('/');
              const ancestor: string = parts.slice(0, idx + 1).join('/');
              this.currentDirPath = ancestor;
              this.loadDirectoryList(ancestor);
            })
          }, (seg: string, idx: number) => `${idx}_${seg}`)
        }
        .width('100%')
        .padding({ left: 16, right: 12, bottom: 6 })
        .onClick(() => { this.selectCurrentDirectory(); })

        Divider().color('#E0E0E0').strokeWidth(0.5).width('100%')

        // 可滚动内容区域
        Column() {
          Scroll() {
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
              Column() {
                // 返回上级（非根目录时显示）
                if (this.currentDirPath !== '') {
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

                if (this.dirList.length === 0) {
                  Text('此目录下无子目录')
                    .fontSize(13)
                    .fontColor('#999')
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding({ top: 20, bottom: 20 })
                }

                ForEach(this.dirList, (dir: string, index: number) => {
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
                }, (dir: string) => dir)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .align(Alignment.TopStart)
        }
        .layoutWeight(1)

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
            .onClick(() => { this.closeDialog(); })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('90%')
      .constraintSize({ maxHeight: '38%' })
      .backgroundColor(Color.White)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
