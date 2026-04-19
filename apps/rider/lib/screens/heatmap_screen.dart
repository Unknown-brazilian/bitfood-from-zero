import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme.dart';
import '../queries.dart';

class HeatMapScreen extends StatefulWidget {
  const HeatMapScreen({super.key});

  @override
  State<HeatMapScreen> createState() => _HeatMapScreenState();
}

class _HeatMapScreenState extends State<HeatMapScreen> {
  final _mapCtrl = MapController();
  LatLng? _myPos;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _myPos = LatLng(pos.latitude, pos.longitude);
        _locating = false;
      });
      _mapCtrl.move(_myPos!, 13);
    } catch (_) {
      setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(orderHeatmapQuery),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (result, {fetchMore, refetch}) {
        final rawPoints = (result.data?['orderHeatmap'] as List?) ?? [];
        final List<_HeatPoint> points = rawPoints.map((p) => _HeatPoint(
          lat: (p['lat'] as num).toDouble(),
          lng: (p['lng'] as num).toDouble(),
          weight: (p['weight'] as int? ?? 1),
        )).toList();

        final maxWeight = points.isEmpty ? 1 : points.map((p) => p.weight).reduce(max);

        final center = _myPos ?? const LatLng(-23.55, -46.63);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.bitfood.rider',
                  ),
                  // Heat circles
                  CircleLayer(
                    circles: points.map((p) {
                      final ratio = p.weight / maxWeight;
                      return CircleMarker(
                        point: LatLng(p.lat, p.lng),
                        radius: 300 + ratio * 700,
                        useRadiusInMeter: true,
                        color: Color.fromRGBO(255, 80, 0, (0.15 + ratio * 0.55).clamp(0.0, 0.7)),
                        borderColor: Colors.transparent,
                        borderStrokeWidth: 0,
                      );
                    }).toList(),
                  ),
                  // My location marker
                  if (_myPos != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _myPos!,
                          width: 48,
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                            ),
                            child: const Center(child: Text('🏍️', style: TextStyle(fontSize: 20))),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Legend
              Positioned(
                top: 12, left: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Zonas de Demanda', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark)),
                            Text(
                              points.isEmpty
                                  ? 'Sem dados de pedidos recentes'
                                  : '${points.length} zonas ativas (últimos 30 dias)',
                              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      if (result.isLoading)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),

              // Heat scale legend
              Positioned(
                bottom: 24, right: 12,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: Column(
                    children: [
                      const Text('Demanda', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      const SizedBox(height: 6),
                      ...[
                        ('Alta', const Color(0xFFFF5000)),
                        ('Média', const Color(0xFFFF8C40)),
                        ('Baixa', const Color(0xFFFFBB80)),
                      ].map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(width: 14, height: 14, decoration: BoxDecoration(color: item.$2, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(item.$1, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),

              // Re-center button
              if (_myPos != null)
                Positioned(
                  bottom: 24, left: 12,
                  child: FloatingActionButton.small(
                    onPressed: () => _mapCtrl.move(_myPos!, 13),
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: AppColors.primary),
                  ),
                ),

              if (_locating)
                const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ],
          ),
        );
      },
    );
  }
}

class _HeatPoint {
  final double lat, lng;
  final int weight;
  const _HeatPoint({required this.lat, required this.lng, required this.weight});
}
