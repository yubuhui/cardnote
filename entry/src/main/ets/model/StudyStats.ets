export interface StudyStats {
  totalCards: number;       // 总卡片数
  learnedCards: number;     // 已学习卡片数
  dueCards: number;         // 待复习卡片数
  todayReviews: number;     // 今日复习次数
  todayCorrect: number;     // 今日正确次数
  streakDays: number;       // 连续学习天数
}
