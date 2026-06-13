import relationalStore from '@ohos.data.relationalStore';
import { cloudData } from '@kit.ArkData';
import { BusinessError } from '@ohos.base';
import { util } from '@kit.ArkTS';

const DB_NAME = 'cardnote.db';

export class DatabaseManager {
  private static instance: DatabaseManager | null = null;
  private rdbStore: relationalStore.RdbStore | null = null;
  private initPromise: Promise<void> | null = null;

  private constructor() {}

  static getInstance(): DatabaseManager {
    if (!DatabaseManager.instance) {
      DatabaseManager.instance = new DatabaseManager();
    }
    return DatabaseManager.instance;
  }

  /**
   * 初始化数据库（首次调用时需要 context）
   */
  async init(context: Context, version: number = 1): Promise<void> {
    if (this.rdbStore) {
      return;
    }
    // 如果已有进行中的初始化，等待其完成
    if (this.initPromise) {
      return this.initPromise;
    }

    this.initPromise = this.doInit(context, version);
    return this.initPromise;
  }

  /** 执行实际的数据库初始化 */
  private async doInit(context: Context, version: number): Promise<void> {
    const rdbParam: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
    };

    try {
      this.rdbStore = await relationalStore.getRdbStore(context, rdbParam);
      // 检查表是否存在，不存在则建表
      const tables = await this.getTables();
      if (!tables.includes('card')) {
        await this.createTables();
      }
      // 迁移检查（每次 init 都执行，保证旧数据库升级）
      await this.runMigrations();
      // 确保至少有一个默认牌组（首次安装 / 旧数据升级均会生效）
      await this.ensureDefaultDeck();
    } catch (err) {
      this.initPromise = null;
      const error = err as BusinessError;
      console.error(`Database init failed: ${error.code} - ${error.message}`);
      throw new Error(`Database init failed: ${error.message}`);
    }
  }

  /** 获取 RdbStore 实例 */
  getStore(): relationalStore.RdbStore {
    if (!this.rdbStore) {
      throw new Error('Database not initialized. Call init() first.');
    }
    return this.rdbStore;
  }

  /** 释放数据库连接 */
  async close(): Promise<void> {
    if (this.rdbStore) {
      await this.rdbStore.close();
      this.rdbStore = null;
    }
  }

  /** 获取所有表名 */
  private async getTables(): Promise<string[]> {
    if (!this.rdbStore) {
      return [];
    }
    const sql: string = "SELECT name FROM sqlite_master WHERE type='table'";
    const resultSet: relationalStore.ResultSet = await this.rdbStore.querySql(sql);
    const tables: string[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        const nameIdx: number = resultSet.getColumnIndex('name');
        tables.push(resultSet.getString(nameIdx));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return tables;
  }

  /** 建表 */
  private async createTables(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }

    // deck 表
    await this.rdbStore.executeSql(
      'CREATE TABLE IF NOT EXISTS deck (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'uuid TEXT, ' +
      'name TEXT NOT NULL, ' +
      'icon TEXT DEFAULT \'📚\', ' +
      'color TEXT DEFAULT \'#4A90D9\', ' +
      'created_at INTEGER, ' +
      'updated_at INTEGER)'
    );

    // card 表
    await this.rdbStore.executeSql(
      'CREATE TABLE IF NOT EXISTS card (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'uuid TEXT, ' +
      'deck_id INTEGER NOT NULL DEFAULT 1, ' +
      'type INTEGER DEFAULT 0, ' +
      'status INTEGER DEFAULT 0, ' +
      'front TEXT NOT NULL, ' +
      'options TEXT DEFAULT \'[]\', ' +
      'correct_answer TEXT NOT NULL, ' +
      'display_order TEXT DEFAULT \'[]\', ' +
      'analysis TEXT DEFAULT \'\', ' +
      'ease_factor REAL DEFAULT 2.5, ' +
      'interval INTEGER DEFAULT 0, ' +
      'repetitions INTEGER DEFAULT 0, ' +
      'next_review_time INTEGER, ' +
      'created_at INTEGER, ' +
      'updated_at INTEGER)'
    );

    // memory_record 表
    await this.rdbStore.executeSql(
      'CREATE TABLE IF NOT EXISTS memory_record (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'uuid TEXT, ' +
      'card_id INTEGER NOT NULL, ' +
      'result INTEGER NOT NULL, ' +
      'date INTEGER NOT NULL, ' +
      'duration INTEGER DEFAULT 0)'
    );

    // 迁移：旧表可能没有 uuid / duration 列
    await this.migrateTable('deck', 'uuid', 'TEXT');
    await this.migrateTable('card', 'uuid', 'TEXT');
    await this.migrateTable('memory_record', 'uuid', 'TEXT');
    await this.migrateTable('memory_record', 'duration', 'INTEGER DEFAULT 0');
  }

  /** 执行所有表结构迁移（每次 init 都调用，幂等） */
  private async runMigrations(): Promise<void> {
    // memory_record: 添加 duration 列（v2）
    await this.migrateTable('memory_record', 'duration', 'INTEGER DEFAULT 0');
    // 所有表: 添加 uuid 列（v3 - 云同步）
    await this.migrateTable('deck', 'uuid', 'TEXT');
    await this.migrateTable('card', 'uuid', 'TEXT');
    await this.migrateTable('memory_record', 'uuid', 'TEXT');
  }

  /**
   * 为指定表添加缺失的列（幂等迁移）
   */
  private async migrateTable(tableName: string, columnName: string, columnDef: string): Promise<void> {
    if (!this.rdbStore) {
      return;
    }
    try {
      const infoSql: string = `PRAGMA table_info('${tableName}')`;
      const rs: relationalStore.ResultSet = await this.rdbStore.querySql(infoSql);
      let exists: boolean = false;
      if (rs.rowCount > 0) {
        rs.goToFirstRow();
        do {
          const nameIdx: number = rs.getColumnIndex('name');
          if (rs.getString(nameIdx) === columnName) {
            exists = true;
            break;
          }
        } while (rs.goToNextRow());
      }
      rs.close();

      if (!exists) {
        await this.rdbStore.executeSql(
          `ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${columnDef}`
        );
        console.info(`Migration: added ${columnName} to ${tableName}`);
      }
    } catch (err) {
      console.error(`Migration failed for ${tableName}.${columnName}: ${JSON.stringify(err)}`);
    }
  }

  /** 确保至少有一个默认牌组 */
  private async ensureDefaultDeck(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }
    const resultSet = await this.rdbStore.query(
      new relationalStore.RdbPredicates('deck')
    );
    const isEmpty = resultSet.rowCount === 0;
    resultSet.close();
    if (isEmpty) {
      const now: number = Date.now();
      const values: relationalStore.ValuesBucket = {
        name: '默认牌组',
        icon: '📘',
        color: '#4A90D9',
        uuid: util.generateRandomUUID(true),
        created_at: now,
        updated_at: now,
      };
      await this.rdbStore.insert('deck', values);
    }
  }

  /** 为现有数据填充缺失的 UUID（首次云同步启用时） */
  async fillMissingUuids(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }
    const tables: string[] = ['deck', 'card', 'memory_record'];
    for (const table of tables) {
      try {
        const resultSet = await this.rdbStore.querySql(
          `SELECT id, uuid FROM ${table} WHERE uuid IS NULL OR uuid = ''`
        );
        if (resultSet.rowCount > 0) {
          resultSet.goToFirstRow();
          do {
            const idIdx = resultSet.getColumnIndex('id');
            const id = resultSet.getLong(idIdx);
            const newUuid = util.generateRandomUUID(true);
            await this.rdbStore.executeSql(
              `UPDATE ${table} SET uuid = ? WHERE id = ?`,
              [newUuid, id]
            );
          } while (resultSet.goToNextRow());
        }
        resultSet.close();
      } catch (err) {
        console.error(`fillMissingUuids failed for ${table}: ${JSON.stringify(err)}`);
      }
    }
  }

  /**
   * 设置端云同步分布式表
   * 需在数据库初始化完成后调用一次
   */
  async setupCloudSync(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }
    try {
      const tables: string[] = ['deck', 'card', 'memory_record'];
      const config: relationalStore.DistributedConfig = {
        autoSync: true
      };
      await this.rdbStore.setDistributedTables(
        tables,
        relationalStore.DistributedType.DISTRIBUTED_CLOUD,
        config
      );
      console.info('Cloud sync tables configured successfully');
    } catch (err) {
      console.error(`setupCloudSync failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 手动触发端云同步
   */
  async manualCloudSync(
    progressCallback?: (progress: relationalStore.ProgressDetails) => void
  ): Promise<number> {
    return new Promise<number>((resolve) => {
      if (!this.rdbStore) {
        resolve(-1);
        return;
      }
      const tables: string[] = ['deck', 'card', 'memory_record'];
      try {
        this.rdbStore.cloudSync(
          relationalStore.SyncMode.SYNC_MODE_TIME_FIRST,
          tables,
          (progress: relationalStore.ProgressDetails) => {
            console.info(`Cloud sync progress: ${JSON.stringify(progress)}`);
            if (progressCallback) {
              progressCallback(progress);
            }
          },
          (err: BusinessError) => {
            if (err) {
              console.error(`Cloud sync failed, code: ${err.code}, message: ${err.message}`);
              resolve(err.code);
            } else {
              console.info('Cloud sync completed successfully');
              resolve(0);
            }
          }
        );
      } catch (err) {
        console.error(`Cloud sync error: ${JSON.stringify(err)}`);
        resolve(-1);
      }
    });
  }

  /**
   * 设置云同步网络策略
   */
  async setCloudStrategy(strategy: cloudData.StrategyType, param?: Array<boolean | number | string>): Promise<void> {
    try {
      await cloudData.setCloudStrategy(strategy, param);
      console.info(`Cloud strategy set: ${strategy}`);
    } catch (err) {
      console.error(`setCloudStrategy failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 注册云端数据变化监听
   */
  onCloudDataChange(callback: (tables: string[]) => void): void {
    if (!this.rdbStore) {
      return;
    }
    try {
      this.rdbStore.on('dataChange', relationalStore.SubscribeType.SUBSCRIBE_TYPE_CLOUD, callback);
    } catch (err) {
      console.error(`Register cloud dataChange failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 取消云端数据变化监听
   */
  offCloudDataChange(callback: (tables: string[]) => void): void {
    if (!this.rdbStore) {
      return;
    }
    try {
      this.rdbStore.off('dataChange', relationalStore.SubscribeType.SUBSCRIBE_TYPE_CLOUD, callback);
    } catch (err) {
      console.error(`Unregister cloud dataChange failed: ${JSON.stringify(err)}`);
    }
  }
}
