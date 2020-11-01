import 'dart:io';

import 'package:flutter_abc/main.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final _databaseName = "MyDatabase.db";
  static final _databaseVersion = 1;

  static final table_foods = 'foods';
  static final columnFoodId = '_id';
  static final columnFoodName = 'name';
  static final columnFoodEnergy = 'energy';
  static final columnFoodProtein = 'protein';
  static final columnFoodCarbohydrates = 'carbohydrates';
  static final columnFoodFat = 'fat';

  static final table_logs = 'logs';
  static final columnLogId = '_id';
  static final columnFoodIdForLog = 'food_id';
  static final columnLogDate = 'date';

  static final table_changed_activity = 'changedActivity';
  static final column_changed_activity_Id = '_id';
  static final column_startActivity = 'start_activity';
  static final column_endActivity = 'end_activity';
  static final column_timeInMilis = 'timeInMillis';

  // make this a singleton class
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // only have a single app-wide reference to the database
  static Database _database;

  Future<Database> get database async {
    if (_database != null) return _database;
    // lazily instantiate the db the first time it is accessed
    _database = await _initDatabase();
    return _database;
  }

  // this opens the database (and creates it if it doesn't exist)
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table_foods (
            $columnFoodId integer primary key autoincrement,
            $columnFoodName TEXT NOT NULL,
            $columnFoodEnergy REAL NOT NULL,
            $columnFoodProtein REAL NOT NULL,
            $columnFoodCarbohydrates REAL NOT NULL,
            $columnFoodFat REAL NOT NULL
          )
         
          ''');
    await db.execute('''
         CREATE TABLE $table_logs (
         $columnLogId integer primary key autoincrement,
         $columnFoodIdForLog TEXT NOT NULL,
         $columnLogDate TEXT NOT NULL
               )   ''');
    await db.execute('''
         CREATE TABLE $table_changed_activity (
         $column_changed_activity_Id integer primary key autoincrement,
         $column_startActivity TEXT NOT NULL,
         $column_endActivity TEXT NOT NULL,
         $column_timeInMilis INT NOT NULL
               )   ''');
  }

  Future<int> insertChangedActivity(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(table_changed_activity, row);
  }

  Future<List<ChangedActivity>> getActivitiesThatStartWith(String startActivity) async {
    Database db = await instance.database;
    var rows = await db.rawQuery('SELECT * FROM $table_changed_activity WHERE $column_startActivity=?', [startActivity]);

    var array = List<ChangedActivity>();
    for (int i = 0; i < rows.length; i++) {
      Map<String, dynamic> row = rows[i];
      ChangedActivity obj  = ChangedActivity(row[column_changed_activity_Id], row[column_startActivity], row[column_endActivity],
          row[column_timeInMilis]);
      array.add(obj);
    }
    return array;
  }

  Future<List<ChangedActivity>> getActivities() async {
    Database db = await instance.database;
    var rows = await db.rawQuery('SELECT * FROM $table_changed_activity');

    var array = List<ChangedActivity>();
    for (int i = 0; i < rows.length; i++) {
      Map<String, dynamic> row = rows[i];
      ChangedActivity obj  = ChangedActivity(row[column_changed_activity_Id], row[column_startActivity], row[column_endActivity],
          row[column_timeInMilis]);
      array.add(obj);
    }
    return array;
  }

  Future<int> insertFood(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(table_foods, row);
  }

  Future<int> insertLog(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(table_logs, row);
  }

  Future<List<Map<String, dynamic>>> getLogsByDate(String date) async {
    Database db = await instance.database;
    return await db
        .rawQuery('SELECT * FROM $table_logs WHERE $columnLogDate = $date');
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database db = await instance.database;
    return await db.query(table_foods);
  }

  Future<int> queryRowCount() async {
    Database db = await instance.database;
    return Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $table_foods'));
  }

  Future<int> update(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnFoodId];
    return await db
        .update(table_foods, row, where: '$columnFoodId = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db
        .delete(table_foods, where: '$columnFoodId = ?', whereArgs: [id]);
  }
}
