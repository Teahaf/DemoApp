import 'dart:async';
import 'dart:convert';

import 'package:activity_recognition_flutter/activity_recognition_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_abc/ticker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'database.dart';

// ignore: non_constant_identifier_names
String API_KEY = "Unjc2Z4luZu0sKFBGflwS7cnxEiU83YygiIU37Ul";
String oldActivity;
int activityStarted = 0;
final dbHelper = DatabaseHelper.instance;

Future<List<Food>> futureAlbum;
ActivityType _activityState = ActivityType.STILL;
int caloriesBurned = 0;
String timePassed;
Map activities = Map();
final TimerBloc _timerBloc = TimerBloc(ticker: Ticker());

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
            energy = double.parse(elementObject['value']);
          break;
        case "Protein":
          protein = double.parse(elementObject['value']);
          break;
        case "Carbohydrate, by difference":
          carbohydrates = double.parse(elementObject['value']);
          break;
        // case "Total lipid (fat)":
        //   fat = double.parse(elementObject['value']);
        //   break;
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

class ChangedActivity {
  final int id;
  final String startActivity;
  final String endActivity;
  final int elapsedTimeInMillis;

  ChangedActivity(
      this.id, this.startActivity, this.endActivity, this.elapsedTimeInMillis);
}



class MyApp extends StatefulWidget {
  MyApp({Key key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    futureAlbum = fetchAlbum();
    _initStreamActivity();
  }

  @override
  void dispose() {
    _timerBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Mixed List';
    return MaterialApp(
      title: title,
      // home: Scaffold(
      //     appBar: AppBar(
      //       title: Text(title),
      //     ),
      //     body: Column(
      //         mainAxisAlignment: MainAxisAlignment.center,
      //         children: <Widget>[
      //           Text(_activityState.toString()),
      //           Text(timePassed.toString()),
      //           Center(
      //             child: BlocBuilder(
      //               bloc: _timerBloc,
      //               builder: (context, state) {
      //                 final String minutesStr = ((state.duration / 60) % 60)
      //                     .floor()
      //                     .toString()
      //                     .padLeft(2, '0');
      //                 final String secondsStr =
      //                 (state.duration % 60).floor().toString().padLeft(2, '0');
      //                 return Text(
      //                   '$minutesStr:$secondsStr',
      //                   style: Timer.timerTextStyle,
      //                 );
      //               },
      //
      //             )
      //           ),
      //         ])
      // ),
      home: BlocProvider(
        bloc: _timerBloc,
        child: Timer(),
      ),
    );
  }

  Stream<Activity> activityStream;

  void _initStreamActivity() async {
    if (await Permission.activityRecognition.request().isGranted) {
      activityStream = ActivityRecognition.activityUpdates();
      activityStream.listen(onData);
    } else if (Permission.activityRecognition.isGranted != null) {
      activityStream = ActivityRecognition.activityUpdates();
      activityStream.listen(onData);
    }
  }

  void _insertChangedActivity(ChangedActivity data) async {
    Map<String, dynamic> row = {
      DatabaseHelper.column_startActivity: data.startActivity,
      DatabaseHelper.column_endActivity: data.endActivity,
      DatabaseHelper.column_timeInMilis: data.elapsedTimeInMillis
    };
    final id = await dbHelper.insertChangedActivity(row);
    print('inserted row id: $id');
  }

  Future<void> onData(Activity activity) async {
    ActivityType type = activity.type;
    int confidence = activity.confidence;
    _saveChangedActivityInDatabase(type);
    // await _calculateCaloriesBurned();
  }

  void _saveChangedActivityInDatabase(ActivityType type) {
    switch (type) {
      case ActivityType.STILL:
        if (!activities.containsKey(ActivityType.STILL)) {
          activities[ActivityType.STILL] =
              DateTime.now().millisecondsSinceEpoch;
        }
        break;
      case ActivityType.IN_VEHICLE:
        if (!activities.containsKey(ActivityType.IN_VEHICLE)) {
          activities[ActivityType.IN_VEHICLE] =
              DateTime.now().millisecondsSinceEpoch;
        }
        break;
      case ActivityType.ON_BICYCLE:
        activities[ActivityType.ON_BICYCLE] =
            DateTime.now().millisecondsSinceEpoch;
        break;
      case ActivityType.ON_FOOT:
        if (!activities.containsKey(ActivityType.ON_FOOT)) {
          activities[ActivityType.ON_FOOT] =
              DateTime.now().millisecondsSinceEpoch;
        }
        break;
      case ActivityType.RUNNING:
        if (!activities.containsKey(ActivityType.RUNNING)) {
          activities[ActivityType.RUNNING] =
              DateTime.now().millisecondsSinceEpoch;
        }
        break;
      case ActivityType.TILTING:
        if (!activities.containsKey(ActivityType.TILTING)) {
          activities[ActivityType.TILTING] =
              DateTime.now().millisecondsSinceEpoch;
        }
        break;
      case ActivityType.UNKNOWN:
        if (!activities.containsKey(ActivityType.UNKNOWN)) {
          activities[ActivityType.UNKNOWN] =
              DateTime.now().millisecondsSinceEpoch;
        }
        break;
      case ActivityType.WALKING:
        if (!activities.containsKey(ActivityType.WALKING)) {
          activities[ActivityType.WALKING] =
              DateTime.now().millisecondsSinceEpoch;
        }
        break;
      case ActivityType.INVALID:
        if (!activities.containsKey(ActivityType.INVALID)) {
          activities[ActivityType.INVALID] =
              DateTime.now().millisecondsSinceEpoch;
        }
        break;
      // }
    }
    _insertChangedActivity(new ChangedActivity(
        0,
        type.toString(),
        _activityState.toString(),
        DateTime.now().millisecond - activityStarted));
    activityStarted = DateTime.now().millisecond;

    dbHelper
        .getActivitiesThatStartWith(ActivityType.ON_FOOT.toString())
        .then((value) => {
              if ((value == null) || (value != null && _activityState != type))
                {
                  _insertChangedActivity(new ChangedActivity(
                      0,
                      type.toString(),
                      _activityState.toString(),
                      DateTime.now().millisecond - activityStarted)),
                  activityStarted = DateTime.now().millisecond,
                }
            });

    _activityState = type;
  }
}

class Timer extends StatelessWidget {
  static const TextStyle timerTextStyle = TextStyle(
    fontSize: 60,
    fontWeight: FontWeight.bold,
  );

  @override
  Widget build(BuildContext context) {
    final TimerBloc _timerBloc = BlocProvider.of<TimerBloc>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Flutter Timer')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 100.0),
            child: Center(
              child: BlocBuilder(
                bloc: _timerBloc,
                builder: (context, state) {
                  final String minutesStr = ((state.duration / 60) % 60)
                      .floor()
                      .toString()
                      .padLeft(2, '0');
                  final String secondsStr =
                      (state.duration % 60).floor().toString().padLeft(2, '0');
                  return Text(
                    '$minutesStr:$secondsStr',
                    style: Timer.timerTextStyle,
                  );
                },
              ),
            ),
          ),
          BlocBuilder(
            condition: (previousState, currentState) =>
                currentState.runtimeType != previousState.runtimeType,
            bloc: _timerBloc,
            builder: (context, state) => Actions(),
          ),
        ],
      ),
    );
  }
}

class Actions extends StatefulWidget {
  @override
  _ActionState createState() => _ActionState();

}

class _ActionState extends State<Actions>{
  String s = "";

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _mapStateToActionButtons(
        timerBloc: BlocProvider.of<TimerBloc>(context),
      ),
    );
  }
  List<Widget> _mapStateToActionButtons({
    TimerBloc timerBloc,
  }) {
    final TimerState state = timerBloc.currentState;
    if (state is Ready) {
      calculateCalories();
      return [
        FloatingActionButton(
          child: Icon(Icons.play_arrow),
          onPressed: () => timerBloc.dispatch(Start(duration: state.duration)),
        ),
      ];
    }
    if (state is Running) {
      return [
        FloatingActionButton(
          child: Icon(Icons.pause),
          onPressed: () => timerBloc.dispatch(Pause()),
        ),
        FloatingActionButton(
          child: Icon(Icons.replay),
          onPressed: () => timerBloc.dispatch(Reset()),
        ),
      ];
    }
    if (state is Paused) {

      return [
        FloatingActionButton(
          child: Icon(Icons.play_arrow),
          onPressed: () => timerBloc.dispatch(Resume()),
        ),
        FloatingActionButton(
          child: Icon(Icons.replay),
          onPressed: () => timerBloc.dispatch(Reset()),
        ),
      ];
    }
    if (state is Finished) {
      return [
        Column(
          children: [
            FloatingActionButton(
              child: Icon(Icons.replay),
              onPressed: () => timerBloc.dispatch(Reset()),
            ),
            Text(s)
          ],
        ),
      ];
    }
    return [];
  }

  void calculateCalories() {
    int timeElapsed = 0;
    double timeElapsedInHours, BMR;
    int weight, height, age;

    dbHelper
        .getActivitiesThatStartWith(ActivityType.STILL.toString())
        .then((value) => {
      value.forEach((element) {
        timeElapsed += element.elapsedTimeInMillis;
      }),

      timeElapsedInHours = (timeElapsed/ 1000) ,
      weight = 64,
      height = 174,
      age = 23,
      BMR = 66.47 + (13.75 * weight) + (5.003 * height) - (6.755 * age),
      s = (BMR * 4.3 / 24 * timeElapsedInHours).toString(),
      setState(() {})
    });
  }
}
