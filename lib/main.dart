import 'dart:async';
import 'dart:ffi';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:environment_sensors/environment_sensors.dart';
import 'package:all_sensors/all_sensors.dart';

void main() => runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: new ThemeData(scaffoldBackgroundColor: Colors.black),
    home: Home()));

class Home extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _HomeState();
  }
}

class Second extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return SecondScreen();
  }
}

class SecondScreen extends State<Second> {
  bool _tempAvailable = false;
  bool _humidityAvailable = false;
  bool _lightAvailable = false;
  bool _pressureAvailable = false;
  final environmentSensors = EnvironmentSensors();
  List<double> _accelerometerValues = <double>[];
  List<double> _userAccelerometerValues = <double>[];
  List<double> _gyroscopeValues = <double>[];
  bool _proximityValues = false;
  List<StreamSubscription<dynamic>> _streamSubscriptions =
      <StreamSubscription<dynamic>>[];

  @override
  void InitState() {
    super.initState();
    _streamSubscriptions
        .add(accelerometerEvents!.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometerValues = <double>[event.x, event.y, event.z];
      });
    }));
    _streamSubscriptions.add(gyroscopeEvents!.listen((GyroscopeEvent event) {
      setState(() {
        _gyroscopeValues = <double>[event.x, event.y, event.z];
      });
    }));

    _streamSubscriptions
        .add(userAccelerometerEvents!.listen((UserAccelerometerEvent event) {
      setState(() {
        _userAccelerometerValues = <double>[event.x, event.y, event.z];
      });
    }));
    _streamSubscriptions.add(proximityEvents!.listen((ProximityEvent event) {
      setState(() {
        _proximityValues = event.getValue();
      });
    }));
    initPlatformState();
  }

  @override
  void dispose() {
    super.dispose();
    for (StreamSubscription<dynamic> subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  Future<void> initPlatformState() async {
    bool tempAvailable;
    bool humidityAvailable;
    bool lightAvailable;
    bool pressureAvailable;

    tempAvailable = await environmentSensors
        .getSensorAvailable(SensorType.AmbientTemperature);
    humidityAvailable =
        await environmentSensors.getSensorAvailable(SensorType.Humidity);
    lightAvailable =
        await environmentSensors.getSensorAvailable(SensorType.Light);
    pressureAvailable =
        await environmentSensors.getSensorAvailable(SensorType.Pressure);

    setState(() {
      _tempAvailable = tempAvailable;
      _humidityAvailable = humidityAvailable;
      _lightAvailable = lightAvailable;
      _pressureAvailable = pressureAvailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String>? accelerometer =
        _accelerometerValues.map((double v) => v.toStringAsFixed(1)).toList();
    final List<String>? gyroscope =
        _gyroscopeValues.map((double v) => v.toStringAsFixed(1)).toList();
    final List<String>? userAccelerometer = _userAccelerometerValues
        .map((double v) => v.toStringAsFixed(1))
        .toList();
    backgroundColor:
    Colors.white;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Environment Sensors'),
      ),
      body: Column(
        children: <Widget>[
          ElevatedButton(
            onPressed: initPlatformState,
            child: Icon(Icons.touch_app_outlined),
          ),
          Text(
            _tempAvailable != false
                ? "AmbientTemperature: found"
                : "AmbientTemperature: not found",
            style: TextStyle(
                color: Colors.white,
                fontSize: 10.0,
                fontWeight: FontWeight.w600),
          ),
          Text(
            _humidityAvailable != false
                ? "humidity: found"
                : "humidity: not found",
            style: TextStyle(
                color: Colors.white,
                fontSize: 10.0,
                fontWeight: FontWeight.w600),
          ),
          Text(
            _lightAvailable != false ? "light: found" : "light: not found",
            style: TextStyle(
                color: Colors.white,
                fontSize: 10.0,
                fontWeight: FontWeight.w600),
          ),
          Text(
            _pressureAvailable != false
                ? "pressure: found"
                : "pressure: not found",
            style: TextStyle(
                color: Colors.white,
                fontSize: 10.0,
                fontWeight: FontWeight.w600),
          ),
          Text(
            'Accelerometer: $accelerometer',
            style: TextStyle(
                color: Colors.white,
                fontSize: 10.0,
                fontWeight: FontWeight.w600),
          ),
          Text(
            'gyroscopeValues: $gyroscope',
            style: TextStyle(
                color: Colors.white,
                fontSize: 10.0,
                fontWeight: FontWeight.w600),
          ),
          Text(
            'userAccelerometer: $userAccelerometer',
            style: TextStyle(
                color: Colors.white,
                fontSize: 10.0,
                fontWeight: FontWeight.w600),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton(
                  child: Text('Home'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Home()),
                    );
                  },
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeState extends State<Home> {
  var temp;
  var description;
  var currently;
  var humidity;
  var windspeed;
  var city;
  var latitude;
  var longitude;
  var address;

  Position? _position;
  void _getCurrentLocation() async {
    Position position = await _determinePosition();
    getAddressfromlatlon(position);
    setState(() {
      _position = position;
      latitude = position.latitude;
      longitude = position.longitude;
    });
  }

  void _getAddress() {
    setState(() {
      getAddressfromlatlon(_position!);
      this.getWeather();
    });
  }

  Future<void> getAddressfromlatlon(Position position) async {
    List<Placemark> placemark =
        await placemarkFromCoordinates(latitude, longitude);
    Placemark place = placemark[0];
    address = place.locality;
  }

  Future<Position> _determinePosition() async {
    LocationPermission permission;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
// When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation);
  }

  Future getWeather() async {
    http.Response response = await http.get(Uri.parse(
        "https://api.openweathermap.org/data/2.5/weather?q=" +
            address +
            "&units=metric&appid=545dde93178335de5fe702186c126607"));
    var results = jsonDecode(response.body);
    setState(() {
      this.temp = results["main"]["temp"];
      this.description = results["weather"][0]["description"];
      this.currently = results["weather"][0]["main"];
      this.humidity = results["main"]["humidity"];
      this.windspeed = results["wind"]["speed"];
      this.city = results["name"];
    });
  }

  @override
  void initState() {
    super.initState();
    this.getWeather();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 94, 94, 94),
      appBar: AppBar(
        title: Text("SwenA3Iot"),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                  Colors.black,
                  Color.fromARGB(255, 69, 69, 69),
                  Color.fromARGB(255, 94, 94, 94)
                ])),
            height: MediaQuery.of(context).size.height / 3,
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _getAddress,
                  child: Icon(Icons.location_pin),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50))),
                ),
                Text(
                  address != null ? address.toString() : "loading",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30.0,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  temp != null ? "${temp.toInt()}\u00B0" : "loading",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40.0,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  temp == null
                      ? "\nloading"
                      : temp <= 20
                          ? "\nBased on the tempurature take a jersey"
                          : "\nT-shirt and sunnies today ",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  description == null
                      ? "loading"
                      : description.toString().contains("rain")
                          ? "flag that... its gonna rain take a raincoat"
                          : "no rain!",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: ListView(
                children: <Widget>[
                  ListTile(
                    tileColor: Colors.transparent,
                    textColor: Colors.white,
                    iconColor: Colors.white,
                    leading: Icon(Icons.location_pin),
                    title: Text("City"),
                    trailing: Text(temp != null ? city.toString() : "loading"),
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    textColor: Colors.white,
                    iconColor: Colors.white,
                    leading: Icon(Icons.thermostat),
                    title: Text("Tempurature"),
                    trailing: Text(
                        temp != null ? "${temp.toInt()}\u00B0" : "loading"),
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    textColor: Colors.white,
                    iconColor: Colors.white,
                    leading: Icon(Icons.cloud),
                    title: Text("Weather"),
                    trailing: Text(description != null
                        ? description.toString()
                        : "loading"),
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    textColor: Colors.white,
                    iconColor: Colors.white,
                    leading: Icon(Icons.sunny),
                    title: Text("Humidity"),
                    trailing: Text(
                        humidity != null ? humidity.toString() : "loading"),
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    textColor: Colors.white,
                    iconColor: Colors.white,
                    leading: Icon(Icons.wind_power),
                    title: Text("wind"),
                    trailing: Text(windspeed != null
                        ? windspeed.toString() + "m/s"
                        : "loading"),
                  ),
                ],
              ),
            ),
          ),
          ElevatedButton(
            child: Text('System Sensors'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Second()),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50))),
          ),
        ],
      ),
    );
  }
}
