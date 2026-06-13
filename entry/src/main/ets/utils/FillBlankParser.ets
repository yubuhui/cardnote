/**
 * 填空题文本片段
 */
export interface TextSegment {
  text: string;     // 文本内容
  isBlank: boolean; // 是否为挖空部分
}

/**
 * 解析题干中的 [[ ]] 挖空标记，返回文本片段数组。
 * 示例："我[[爱]]你" → [{text:"我",isBlank:false}, {text:"爱",isBlank:true}, {text:"你",isBlank:false}]
 */
export function parseFillBlanks(front: string): TextSegment[] {
  const regex: RegExp = /\[\[(.*?)\]\]/g;
  const segments: TextSegment[] = [];
  let lastIndex: number = 0;
  let match: RegExpExecArray | null;

  while ((match = regex.exec(front)) !== null) {
    // 前导普通文本
    if (match.index > lastIndex) {
      segments.push({ text: front.substring(lastIndex, match.index), isBlank: false });
    }
    // 挖空内容
    segments.push({ text: match[1], isBlank: true });
    lastIndex = match.index + match[0].length;
  }
  // 尾部普通文本
  if (lastIndex < front.length) {
    segments.push({ text: front.substring(lastIndex), isBlank: false });
  }
  return segments;
}

/**
 * 从题干中提取所有挖空答案，用分隔符连接
 */
export function extractBlankAnswers(front: string): string {
  const segments: TextSegment[] = parseFillBlanks(front);
  return segments
    .filter(s => s.isBlank)
    .map(s => s.text)
    .join('|');
}
