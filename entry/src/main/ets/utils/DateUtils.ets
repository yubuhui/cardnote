/**
 * 统一的日期与文件大小格式化工具。
 * 项目内各页面不再各自定义 formatDate，统一从此处导入。
 */

/** 格式化日期：YYYY-MM-DD HH:mm */
export function formatDateTime(date: Date): string {
  const y: string = String(date.getFullYear());
  const m: string = pad2(date.getMonth() + 1);
  const d: string = pad2(date.getDate());
  const hh: string = pad2(date.getHours());
  const mm: string = pad2(date.getMinutes());
  return `${y}-${m}-${d} ${hh}:${mm}`;
}

/** 格式化为文件名安全的时间戳：YYYYMMDD_HHmmss */
export function formatTimestamp(date: Date): string {
  const y: string = String(date.getFullYear());
  const m: string = pad2(date.getMonth() + 1);
  const d: string = pad2(date.getDate());
  const hh: string = pad2(date.getHours());
  const mm: string = pad2(date.getMinutes());
  const ss: string = pad2(date.getSeconds());
  return `${y}${m}${d}_${hh}${mm}${ss}`;
}

/** 格式化文件大小为人类可读字符串 */
export function formatFileSize(bytes: number): string {
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`;
  }
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function pad2(n: number): string {
  return n < 10 ? '0' + n : String(n);
}
