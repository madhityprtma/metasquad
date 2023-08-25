// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference _databaseRefere =
      FirebaseDatabase.instance.reference().child('alat');

  late GoogleMapController mapController;
  LatLng? _initialPosition;
  LatLng? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  double _zoomLevel = 13.0;
  bool _isLocationSet = false;
  final Set<Marker> _markers = {};

  // Initialize Firebase Database reference
  final DatabaseReference _databaseReference =
      FirebaseDatabase.instance.reference();

  String tong1Image = 'assets/images/trash1.png';
  String tong2Image = 'assets/images/trash1.png';
  String idAlat = '626771718';

  bool kondisiTong1 = false;
  bool kondisiTong2 = false;

  double latTarget = 0.0;
  double lngTarget = 0.0;

  Future<void> _checkLocationPermission() async {
    PermissionStatus status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
    _getDeviceLocation();
  }

  Future<void> _getDeviceLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _currentPosition = _initialPosition;
        _isLocationSet = true;
        _updateMarkers();
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _searchLocation() async {
    String searchQuery = _searchController.text;
    if (searchQuery.isNotEmpty) {
      List<Location> locations = await locationFromAddress(searchQuery);
      if (locations.isNotEmpty) {
        Location location = locations.first;
        setState(() {
          _initialPosition = LatLng(
            location.latitude,
            location.longitude,
          );
          mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _initialPosition!,
                zoom: _zoomLevel,
              ),
            ),
          );
        });
      }
    }
  }

  void _moveToCurrentPosition() async {
    PermissionStatus status = await Permission.location.status;
    if (status.isGranted) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _zoomLevel = 13.0;
        _updateZoom();
      });
    }
  }

  void _lacakPosistion() {
    LatLng mainPosition = _currentPosition!;
    setState(() {
      _currentPosition = LatLng(latTarget, lngTarget);
      _zoomLevel = 15.0;
      _updateZoom();
      _currentPosition = mainPosition;
    });
  }

  void _updateZoom() {
    if (_currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition!,
            zoom: _zoomLevel,
          ),
        ),
      );
    }
  }

  Future<void> _addCustomMarker(
      String markerId, LatLng position, String imagePath) async {
    BitmapDescriptor customIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      imagePath,
    );

    _markers.add(Marker(
      markerId: MarkerId(markerId),
      position: position,
      icon: customIcon,
    ));
  }

  Future<void> _addCustomMetaMarker(
      String markerId,
      LatLng position,
      bool kondisiTong1,
      bool kondisiTong2,
      String title,
      String subTitle) async {
    BitmapDescriptor customIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/marker.png',
    );

    BitmapDescriptor customIconFull = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/marker2.png',
    );

    _markers.add(Marker(
      markerId: MarkerId(markerId),
      position: position,
      infoWindow: InfoWindow(title: title, snippet: subTitle),
      icon: (kondisiTong1 || kondisiTong2) ? customIconFull : customIcon,
      onTap: () {
        mapController.showMarkerInfoWindow(MarkerId(markerId));
        setState(() {
          idAlat = markerId;
          tong1Image = kondisiTong1
              ? 'assets/images/trash2.png'
              : 'assets/images/trash1.png';
          tong2Image = kondisiTong2
              ? 'assets/images/trash2.png'
              : 'assets/images/trash1.png';
        });
      },
    ));
  }

  void _updateMarkers() {
    _markers.clear();

    if (_currentPosition != null) {
      _addCustomMarker(
          'current', _currentPosition!, 'assets/images/marker_1.png');
    }

    // Listen to changes in the 'lokasi' node in Firebase
    _databaseReference.child('alat').onValue.listen((event) {
      // Get the snapshot of the data
      DataSnapshot snapshot = event.snapshot;

      // Check if the snapshot has data
      if (snapshot.value != null) {
        // Clear existing markers before adding new ones
        _markers.clear();

        // Convert Object? to Map<dynamic, dynamic> using 'as'
        Map<dynamic, dynamic>? locationsData =
            snapshot.value as Map<dynamic, dynamic>?;

        // Check if locationsData is not null
        if (locationsData != null) {
          // Loop through the data to add markers
          locationsData.forEach((key, value) {
            double lat = value['lat'];
            double lng = value['lng'];
            String markerId = key;
            String title = value['title'];
            String subTitle = value['sub_title'];
            bool tong1 = value['kondisi_tong_1'];
            bool tong2 = value['kondisi_tong_2'];
            _addCustomMetaMarker(
                markerId, LatLng(lat, lng), tong1, tong2, title, subTitle);

            if (markerId == idAlat) {
              setState(() {
                latTarget = lat;
                lngTarget = lng;
              });
            }
          });

          // Add marker for user's location
          if (_currentPosition != null) {
            _addCustomMarker(
                'user', _currentPosition!, 'assets/images/marker_1.png');
          }

          // Update the map to reflect the changes
          setState(() {});
        }
      }
    });
  }

  Future<void> _checkTongConditions() async {
    DatabaseReference databaseReference = FirebaseDatabase.instance.reference();
    DatabaseReference alatRef = databaseReference.child("alat").child(idAlat);

    alatRef.onValue.listen((event) {
      Map<dynamic, dynamic>? data =
          event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        setState(() {
          kondisiTong1 = data['kondisi_tong_1'];
          kondisiTong2 = data['kondisi_tong_2'];
          tong1Image = kondisiTong1
              ? 'assets/images/trash2.png'
              : 'assets/images/trash1.png';
          tong2Image = kondisiTong2
              ? 'assets/images/trash2.png'
              : 'assets/images/trash1.png';

          _updateMarkers();
        });
      }
    }, onError: (error) {
      print("Error while reading data from Firebase: $error");
    });
  }

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _checkTongConditions();
  }

  Widget _buildBackground({
    double margin = 20.0,
    double borderRadiusValue = 10.0,
    int count = 0,
  }) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: 350,
          height: 400,
          margin: EdgeInsets.only(top: margin),
          decoration: BoxDecoration(
            color: Color.fromRGBO(74, 173, 78, 1),
          ),
          child: Scaffold(
            body: Stack(
              children: [
                _initialPosition != null
                    ? GoogleMap(
                        onMapCreated: (controller) {
                          mapController = controller;
                        },
                        initialCameraPosition: CameraPosition(
                          target: _initialPosition!,
                          zoom: _zoomLevel,
                        ),
                        markers: _markers,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: true,
                      )
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
                Positioned(
                  bottom: 120,
                  right: 16,
                  child: FloatingActionButton(
                    child: const Icon(Icons.my_location, color: Colors.white),
                    backgroundColor: const Color.fromRGBO(74, 172, 79, 1),
                    onPressed: _isLocationSet ? _moveToCurrentPosition : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => Center(
                child: AlertDialog(
                  title: const Center(
                    child: Text('Do you want to exit?'),
                  ),
                  content: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: () {
                          SystemNavigator.pop();
                        },
                        style: ElevatedButton.styleFrom(
                          primary: Colors.green,
                        ),
                        child: const Text('Yes'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: ElevatedButton.styleFrom(
                          primary: const Color.fromARGB(255, 175, 76, 76),
                        ),
                        child: const Text('No'),
                      ),
                    ],
                  ),
                ),
              ),
            ) ??
            false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              Image.asset(
                'assets/images/petugas.png',
                width: 30,
                height: 30,
              ),
              SizedBox(width: 8),
              Text(
                'MetaSquad',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            _buildBackground(),
            Positioned(
              bottom: 130,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        child: Image.asset(
                          tong1Image,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Trash Bin Non-Metal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 40),
                  Column(
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        child: Image.asset(
                          tong2Image,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Trash Bin Metal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 20,
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 40,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    _lacakPosistion();
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Color.fromRGBO(74, 173, 78, 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Track',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
