import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'database.dart';

// ignore: non_constant_identifier_names
String API_KEY = "Unjc2Z4luZu0sKFBGflwS7cnxEiU83YygiIU37Ul";

Future<List<Food>> fetchAlbum() async {
  final response = await http.get(
      'https://api.nal.usda.gov/fdc/v1/foods/search?query=banana&api_key=Unjc2Z4luZu0sKFBGflwS7cnxEiU83YygiIU37Ul&dataType=Foundation,SR%20Legacy&sortBy=dataType.keyword');
  if (response.statusCode == 200) {
    return fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load album');
  }
}

List<Food> fromJson(Map<String, dynamic> json) {
  var albumList = List<Food>();
  List<dynamic> entitlements = json['foods'];
  String name;
  double energy, carbohydrates, protein, fat;
  for (int i = 0; i < 10; i++) {
    name = entitlements[i]['description'];
    List<dynamic> nutrients = entitlements[i]['foodNutrients'];
    nutrients.forEach((element) {
      var elementObject = (element as Map<String, dynamic>);
      switch (elementObject['nutrientName']) {
        case "Energy":
          if (elementObject['unitName'] == "KCAL")
            energy = elementObject['value'];
          break;
        case "Protein":
          protein = elementObject['value'];
          break;
        case "Carbohydrate, by difference":
          carbohydrates = elementObject['value'];
          break;
        case "Total lipid (fat)":
          fat = elementObject['value'];
          break;
        default:
          break;
      }
    });
    albumList.add(new Food(
        id: 0,
        name: name,
        carbohydrates: carbohydrates,
        fat: fat,
        energy: energy,
        protein: protein));
  }
  return albumList;
}

class Food {
  final int id;
  final String name;
  final double energy;
  final double protein;
  final double carbohydrates;
  final double fat;

  Food(
      {this.id,
      this.name,
      this.energy,
      this.carbohydrates,
      this.protein,
      this.fat});

  Widget buildTitle(BuildContext context) {
    return Text(this.name);
  }

  Widget buildSubtitle(BuildContext context) {}
}

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  MyApp({Key key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<List<Food>> futureAlbum;
  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    futureAlbum = fetchAlbum();
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Mixed List';
    // Future<List<Food>> items = futureAlbum;
    return MaterialApp(
      title: title,
      home: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: FutureBuilder<List<Food>>(
          future: futureAlbum,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    GestureDetector(
                        onTap: () {
                          _insert(snapshot.data[0]);
                        },
                        child: new Container(
                          width: 500.0,
                          padding:
                              new EdgeInsets.fromLTRB(20.0, 40.0, 20.0, 40.0),
                          color: Colors.green,
                          child: new Column(children: [
                            new Text((snapshot.data[0].name)),
                          ]),
                        )),
                    Text(snapshot.data[1].name),
                    Text(snapshot.data[2].name),
                    Text(snapshot.data[3].name),
                    Text(snapshot.data[4].name),
                    Text(snapshot.data[5].name),
                  ]);
            } else if (snapshot.hasError) {
              return Text("${snapshot.error}");
            }
            // By default, show a loading spinner.
            return CircularProgressIndicator();
          },
        ),
      ),
    );
  }

  void _insert(Food data) async {
    // row to insert
    Map<String, dynamic> row = {
      DatabaseHelper.columnFoodName: data.name,
      DatabaseHelper.columnFoodEnergy: data.energy,
      DatabaseHelper.columnFoodProtein: data.protein,
      DatabaseHelper.columnFoodCarbohydrates: data.carbohydrates,
      DatabaseHelper.columnFoodFat: data.fat
    };
    final id = await dbHelper.insert(row);
    print('inserted row id: $id');
  }

  void _query() async {
    final allRows = await dbHelper.queryAllRows();
    print('query all rows:');
    allRows.forEach((row) => print(row));
  }

  void _update() async {
    // row to update
    Map<String, dynamic> row = {
      DatabaseHelper.columnFoodId: 1,
      DatabaseHelper.columnFoodName: 'Mary',
      DatabaseHelper.columnFoodFat: 47,
      DatabaseHelper.columnFoodCarbohydrates: 5,
      DatabaseHelper.columnFoodProtein: 41,
      DatabaseHelper.columnFoodEnergy: 12
    };
    final rowsAffected = await dbHelper.update(row);
    print('updated $rowsAffected row(s)');
  }

  void _delete() async {
    // Assuming that the number of rows is the id for the last row.
    final id = await dbHelper.queryRowCount();
    final rowsDeleted = await dbHelper.delete(id);
    print('deleted $rowsDeleted row(s): row $id');
  }
}
