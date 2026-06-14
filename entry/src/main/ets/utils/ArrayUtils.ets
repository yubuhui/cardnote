/**
 * Fisher-Yates 洗牌算法
 * 对数组元素进行原地随机排列，返回乱序后的新数组
 */
export function shuffleFisherYates(arr: number[]): number[] {
  const result: number[] = [...arr];
  for (let i: number = result.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const tmp: number = result[i];
    result[i] = result[j];
    result[j] = tmp;
  }
  return result;
}
