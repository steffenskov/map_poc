import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Search',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapSearchPage(),
    );
  }
}

class MapSearchPage extends StatefulWidget {
  const MapSearchPage({super.key});

  @override
  State<MapSearchPage> createState() => _MapSearchPageState();
}

class _MapSearchPageState extends State<MapSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  // Add state variables for map position
  LatLng _currentCenter = const LatLng(51.5, -0.09); // London as default
  double _currentZoom = 9.2;

  // Replace with your MapTiler API key
  static const String mapTilerApiKey = '09C6pPzLTvswlTdHKaIn';

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=$query',
        ),
        headers: {'User-Agent': 'Flutter Map App'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data.cast<Map<String, dynamic>>();
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _selectLocation(Map<String, dynamic> location) {
    final lat = double.parse(location['lat']);
    final lon = double.parse(location['lon']);
    
    print('Moving map to: $lat, $lon'); // Debug print
    
    // Update the current center and zoom
    setState(() {
      _currentCenter = LatLng(lat, lon);
      _currentZoom = 15.0;
      _searchResults = [];
      _searchController.clear();
    });
    
    // Ensure we're on the main thread and the map is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_currentCenter, _currentZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Search'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for an address...',
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _searchAddress(_searchController.text),
                      ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: _searchAddress,
            ),
          ),
          if (_searchResults.isNotEmpty)
            Expanded(
              flex: 1,
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    title: Text(result['display_name'] ?? ''),
                    onTap: () => _selectLocation(result),
                  );
                },
              ),
            ),
          Expanded(
            flex: 2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: _currentZoom,
                onMapReady: () {
                  // Ensure map stays at the current position
                  _mapController.move(_currentCenter, _currentZoom);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$mapTilerApiKey',
                  userAgentPackageName: 'com.example.map',
                  tileProvider: CancellableNetworkTileProvider(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }
}
