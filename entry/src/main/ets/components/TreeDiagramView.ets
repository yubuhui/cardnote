import { TreeNode, parseTreeNodes } from '../utils/TreeDiagramParser';

@Component
export struct TreeDiagramView {
  @Prop content: string = '';
  @Prop fontSize: number = 15;
  @Prop fontColor: ResourceColor = $r('app.color.text_primary');
  @Prop fontWeight: number | FontWeight = FontWeight.Medium;
  @Prop lineHeight: number | string = 24;
  @Prop dotSize: number = 8;
  @Prop indentPerLevel: number = 16;

  build() {
    Column({ space: 2 }) {
      ForEach(
        parseTreeNodes(this.content),
        (node: TreeNode, index: number) => {
          Row() {
            Blank().width(node.displayLevel * this.indentPerLevel)
            Row().width(this.dotSize).height(this.dotSize).borderRadius(this.dotSize / 2).backgroundColor(this.fontColor).margin({ right: 6 })
            Text(node.text)
              .fontSize(this.fontSize)
              .fontWeight(this.fontWeight)
              .fontColor(this.fontColor)
              .lineHeight(this.lineHeight)
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        },
        (node: TreeNode, index: number): string => {
          return index.toString() + '_' + node.displayLevel.toString() + '_' + node.text;
        }
      )
    }
    .width('100%')
  }
}
