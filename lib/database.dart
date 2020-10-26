import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

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
        version: _databaseVersion,
        onCreate: _onCreate);
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table_foods (
            $columnFoodId INTEGER PRIMARY KEY,
            $columnFoodName TEXT NOT NULL,
            $columnFoodEnergy REAL NOT NULL,
            $columnFoodProtein REAL NOT NULL,
            $columnFoodCarbohydrates REAL NOT NULL,
            $columnFoodFat REAL NOT NULL
          )''');
  }

  Future<int> insert(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(table_foods, row);
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database db = await instance.database;
    return await db.query(table_foods);
  }

  Future<int> queryRowCount() async {
    Database db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table_foods'));
  }

  Future<int> update(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnFoodId];
    return await db.update(table_foods, row, where: '$columnFoodId = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db.delete(table_foods, where: '$columnFoodId = ?', whereArgs: [id]);
  }
}