export class TreeNode {
  text: string = '';
  level: number = 0;
  displayLevel: number = 0;

  constructor(text: string, level: number, displayLevel: number) {
    this.text = text;
    this.level = level;
    this.displayLevel = displayLevel;
  }
}

export function parseTreeNodes(content: string): TreeNode[] {
  if (!content || content.trim().length === 0) {
    return [];
  }

  const lines: string[] = content.split('\n');
  const rawNodes: TreeNode[] = [];

  for (let i = 0; i < lines.length; i++) {
    const trimmed: string = lines[i].trim();
    if (trimmed.length === 0) {
      continue;
    }

    let slashCount: number = 0;
    for (let j = 0; j < trimmed.length; j++) {
      if (trimmed[j] === '/') {
        slashCount++;
      } else {
        break;
      }
    }

    const displayText: string = trimmed.substring(slashCount).trim();
    if (displayText.length === 0) {
      continue;
    }

    rawNodes.push(new TreeNode(displayText, slashCount, slashCount));
  }

  for (let i = 0; i < rawNodes.length; i++) {
    const node: TreeNode = rawNodes[i];
    if (node.level > 1) {
      let hasParent: boolean = false;
      for (let j = i - 1; j >= 0; j--) {
        if (rawNodes[j].displayLevel === node.level - 1) {
          hasParent = true;
          break;
        }
        if (rawNodes[j].displayLevel === 0) {
          break;
        }
      }
      if (!hasParent) {
        node.displayLevel = 1;
      }
    }
  }

  return rawNodes;
}
