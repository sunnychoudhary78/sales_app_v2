import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models/location_point.dart';

class TrackingDbService {
  TrackingDbService._();

  static final TrackingDbService instance = TrackingDbService._();
  static Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'sales_tracking_v2_points.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE location_points(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL,
            speed REAL,
            heading REAL,
            battery_percent INTEGER,
            recordedAt TEXT NOT NULL,
            isSynced INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE location_points ADD COLUMN battery_percent INTEGER',
          );
        }
      },
    );
  }

  Future<int> insertPoint(LocationPoint point) async {
    final db = await database;
    return db.insert('location_points', point.toMap());
  }

  Future<List<LocationPoint>> getUnsyncedPoints() async {
    final db = await database;
    final maps = await db.query(
      'location_points',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'id ASC',
    );
    return maps.map(LocationPoint.fromMap).toList();
  }

  Future<void> markPointsAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update(
      'location_points',
      {'isSynced': 1},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> clearSyncedPoints() async {
    final db = await database;
    await db.delete('location_points', where: 'isSynced = ?', whereArgs: [1]);
  }

  Future<LocationPoint?> getLastPoint() async {
    final db = await database;
    final maps = await db.query(
      'location_points',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LocationPoint.fromMap(maps.first);
  }
}
