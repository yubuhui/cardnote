export class DataRefreshHelper {
  static readonly KEY: string = 'dataVersion';

  static notify(): void {
    const current: number = AppStorage.get<number>(DataRefreshHelper.KEY) ?? 0;
    AppStorage.setOrCreate(DataRefreshHelper.KEY, current + 1);
  }

  static getVersion(): number {
    return AppStorage.get<number>(DataRefreshHelper.KEY) ?? 0;
  }
}
