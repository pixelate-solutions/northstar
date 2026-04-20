import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/trip_day.dart';
import '../../models/trip_plan.dart';
import '../../models/trip_stop.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/tag_colors.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/tiny_pill.dart';

const _mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
const _mapboxStyle = String.fromEnvironment(
  'MAPBOX_STYLE',
  defaultValue: 'mapbox/streets-v12',
);

class MapPanel extends StatefulWidget {
  const MapPanel({super.key, required this.plan, required this.days});
  final TripPlan plan;
  final List<TripDay> days;

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  late final AnimationController _animController;
  int? _selectedIndex;
  bool _routeMode = false;
  int? _routeStartIndex;
  int? _routeEndIndex;
  _RouteResult? _routeResult;
  bool _routeLoading = false;
  String? _routeError;
  int _routeRequestId = 0;

  List<TripStop> get _stops => [
    for (final day in widget.days)
      for (final stop in day.stops)
        if (stop.latitude != 0 && stop.longitude != 0) stop,
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (_mapboxAccessToken.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _precacheStopImages());
    }
  }

  Future<void> _precacheStopImages() async {
    await Future.delayed(const Duration(seconds: 4));
    for (final stop in _stops) {
      if (!mounted) return;
      await precacheImage(NetworkImage(_staticMapUrl(stop)), context);
    }
  }

  void _panTo(int index) {
    final stop = _stops[index];
    setState(() => _selectedIndex = index);
    _moveToStop(stop);
  }

  void _handleStopTap(int index) {
    if (!_routeMode) {
      _panTo(index);
      return;
    }

    var shouldLoadRoute = false;
    setState(() {
      if (_routeStartIndex == null ||
          (_routeStartIndex != null && _routeEndIndex != null)) {
        _routeStartIndex = index;
        _routeEndIndex = null;
        _routeResult = null;
        _routeError = null;
      } else if (_routeStartIndex == index) {
        _routeStartIndex = null;
        _routeResult = null;
        _routeError = null;
      } else {
        _routeEndIndex = index;
        _routeResult = null;
        _routeError = null;
        shouldLoadRoute = true;
      }
      _selectedIndex = index;
    });
    _moveToStop(_stops[index]);
    if (shouldLoadRoute) _loadRoute();
  }

  void _toggleRouteMode() {
    setState(() {
      _routeMode = !_routeMode;
      if (!_routeMode) {
        _routeRequestId++;
        _routeStartIndex = null;
        _routeEndIndex = null;
        _routeResult = null;
        _routeError = null;
        _routeLoading = false;
      }
    });
  }

  void _clearRoute() {
    setState(() {
      _routeRequestId++;
      _routeStartIndex = null;
      _routeEndIndex = null;
      _routeResult = null;
      _routeError = null;
      _routeLoading = false;
    });
  }

  void _showStopDetails(TripStop stop) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StopDetailSheet(stop: stop),
    );
  }

  Future<void> _loadRoute() async {
    final startIndex = _routeStartIndex;
    final endIndex = _routeEndIndex;
    if (startIndex == null || endIndex == null) return;

    final requestId = ++_routeRequestId;
    setState(() {
      _routeLoading = true;
      _routeError = null;
    });

    try {
      final result = await _RouteResult.fetch(
        _stops[startIndex],
        _stops[endIndex],
      );
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routeResult = result;
        _routeLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routeError = 'Could not load route. Open maps for live routing.';
        _routeLoading = false;
      });
    }
  }

  void _moveToStop(TripStop stop) {
    final from = _mapController.camera.center;
    final to = LatLng(stop.latitude, stop.longitude);
    final fromZoom = _mapController.camera.zoom;
    const toZoom = 14.0;

    _animController.reset();
    final anim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );
    anim.addListener(() {
      final t = anim.value;
      _mapController.move(
        LatLng(
          from.latitude + (to.latitude - from.latitude) * t,
          from.longitude + (to.longitude - from.longitude) * t,
        ),
        fromZoom + (toZoom - fromZoom) * t,
      );
    });
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stops = _stops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          padding: EdgeInsets.zero,
          child: stops.isEmpty
              ? const SizedBox(height: 340, child: _EmptyMapPlaceholder())
              : Column(
                  children: [
                    SizedBox(
                      height: 310,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: _TripMap(
                          stops: stops,
                          mapController: _mapController,
                          selectedIndex: _selectedIndex,
                          routeStartIndex: _routeStartIndex,
                          routeEndIndex: _routeEndIndex,
                          routePoints: _routeResult?.points ?? const [],
                          onMarkerTap: _handleStopTap,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                      child: Column(
                        children: [
                          _RouteToolbar(
                            stops: stops,
                            routeMode: _routeMode,
                            routeStartIndex: _routeStartIndex,
                            routeEndIndex: _routeEndIndex,
                            routeResult: _routeResult,
                            routeLoading: _routeLoading,
                            routeError: _routeError,
                            onToggleRouteMode: _toggleRouteMode,
                            onClearRoute: _clearRoute,
                          ),
                          const SizedBox(height: 10),
                          _MapStopScroller(
                            stops: stops,
                            selectedIndex: _selectedIndex,
                            routeMode: _routeMode,
                            routeStartIndex: _routeStartIndex,
                            routeEndIndex: _routeEndIndex,
                            onSelected: _handleStopTap,
                            onLongPress: (stop) => _showStopDetails(stop),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RouteToolbar extends StatelessWidget {
  const _RouteToolbar({
    required this.stops,
    required this.routeMode,
    required this.routeStartIndex,
    required this.routeEndIndex,
    required this.routeResult,
    required this.routeLoading,
    required this.routeError,
    required this.onToggleRouteMode,
    required this.onClearRoute,
  });

  final List<TripStop> stops;
  final bool routeMode;
  final int? routeStartIndex;
  final int? routeEndIndex;
  final _RouteResult? routeResult;
  final bool routeLoading;
  final String? routeError;
  final VoidCallback onToggleRouteMode;
  final VoidCallback onClearRoute;

  @override
  Widget build(BuildContext context) {
    final startIndex = routeStartIndex;
    final endIndex = routeEndIndex;
    final hasRoute = startIndex != null && endIndex != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: routeMode
            ? kForest.withValues(alpha: .08)
            : kInk.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: routeMode
              ? kForest.withValues(alpha: .2)
              : kLine.withValues(alpha: .9),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasRoute
                      ? '${stops[startIndex].place} to ${stops[endIndex].place}'
                      : routeMode
                      ? startIndex == null
                            ? 'Select a starting location'
                            : 'Select a destination'
                      : 'Route between two locations',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: kInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: stops.length < 2 ? null : onToggleRouteMode,
                  icon: Icon(
                    routeMode ? Icons.close_rounded : Icons.route_rounded,
                    size: 16,
                  ),
                  label: Text(routeMode ? 'Done' : 'Route'),
                  style: FilledButton.styleFrom(
                    backgroundColor: routeMode ? kInk : kForest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
          if (hasRoute) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _RouteStatusText(
                    result: routeResult,
                    loading: routeLoading,
                    error: routeError,
                  ),
                ),
                TextButton(onPressed: onClearRoute, child: const Text('Clear')),
                const SizedBox(width: 6),
                SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openRouteInMaps(stops[startIndex], stops[endIndex]),
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Open in maps'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kInk,
                      side: BorderSide(color: kLine.withValues(alpha: .9)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MapStopScroller extends StatelessWidget {
  const _MapStopScroller({
    required this.stops,
    required this.selectedIndex,
    required this.routeMode,
    required this.routeStartIndex,
    required this.routeEndIndex,
    required this.onSelected,
    required this.onLongPress,
  });

  final List<TripStop> stops;
  final int? selectedIndex;
  final bool routeMode;
  final int? routeStartIndex;
  final int? routeEndIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<TripStop> onLongPress;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < stops.length; i++) ...[
            SizedBox(
              width: 148,
              child: _MapStopBubble(
                stop: stops[i],
                index: i + 1,
                selected: selectedIndex == i,
                routeRole: routeStartIndex == i
                    ? 'A'
                    : routeEndIndex == i
                    ? 'B'
                    : null,
                routeMode: routeMode,
                onTap: () => onSelected(i),
                onLongPress: () => onLongPress(stops[i]),
              ),
            ),
            if (i != stops.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _TripMap extends StatefulWidget {
  const _TripMap({
    required this.stops,
    required this.mapController,
    required this.selectedIndex,
    required this.routeStartIndex,
    required this.routeEndIndex,
    required this.routePoints,
    required this.onMarkerTap,
  });
  final List<TripStop> stops;
  final MapController mapController;
  final int? selectedIndex;
  final int? routeStartIndex;
  final int? routeEndIndex;
  final List<LatLng> routePoints;
  final ValueChanged<int> onMarkerTap;

  @override
  State<_TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<_TripMap> {
  late LatLng _initialCenter;
  late double _initialZoom;
  late final NetworkTileProvider _tileProvider;

  @override
  void initState() {
    super.initState();
    _tileProvider = NetworkTileProvider(silenceExceptions: true);
    _computeInitialView();
  }

  void _computeInitialView() {
    final lats = widget.stops.map((s) => s.latitude);
    final lngs = widget.stops.map((s) => s.longitude);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    _initialCenter = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _initialZoom = widget.stops.length == 1
        ? 13
        : _estimateZoom(maxLat - minLat, maxLng - minLng);
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    final points = stops.map((s) => LatLng(s.latitude, s.longitude)).toList();

    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: _initialZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: _mapboxAccessToken.isEmpty
              ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
              : 'https://api.mapbox.com/styles/v1/$_mapboxStyle/tiles/256/{z}/{x}/{y}?access_token=$_mapboxAccessToken',
          userAgentPackageName: 'com.northstar.app',
          retinaMode: false,
          keepBuffer: 2,
          panBuffer: 0,
          tileProvider: _tileProvider,
        ),
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 2.5,
                color: kInk.withValues(alpha: .5),
              ),
              if (widget.routePoints.isNotEmpty)
                Polyline(
                  points: widget.routePoints,
                  strokeWidth: 5,
                  color: kForest.withValues(alpha: .82),
                ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < stops.length; i++)
              Marker(
                point: points[i],
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: () => widget.onMarkerTap(i),
                  child: _StopMarker(
                    stop: stops[i],
                    index: i + 1,
                    selected: widget.selectedIndex == i,
                    routeRole: widget.routeStartIndex == i
                        ? 'A'
                        : widget.routeEndIndex == i
                        ? 'B'
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('Mapbox'),
            TextSourceAttribution('OpenStreetMap'),
          ],
        ),
      ],
    );
  }

  double _estimateZoom(double latRange, double lngRange) {
    final range = latRange > lngRange ? latRange : lngRange;
    if (range < 0.01) return 14;
    if (range < 0.05) return 13;
    if (range < 0.2) return 12;
    if (range < 0.5) return 11;
    if (range < 1.5) return 10;
    if (range < 5) return 8;
    return 6;
  }
}

class _StopMarker extends StatelessWidget {
  const _StopMarker({
    required this.stop,
    required this.index,
    required this.selected,
    required this.routeRole,
  });
  final TripStop stop;
  final int index;
  final bool selected;
  final String? routeRole;

  @override
  Widget build(BuildContext context) {
    final color = tagColor(stop.tag);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          routeRole ?? '$index',
          style: TextStyle(
            color: selected ? Colors.white : tagTextColor(stop.tag),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _EmptyMapPlaceholder extends StatelessWidget {
  const _EmptyMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .3),
            ),
            const SizedBox(height: 10),
            Text(
              'No mapped locations yet',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: kMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapStopBubble extends StatelessWidget {
  const _MapStopBubble({
    required this.stop,
    required this.index,
    required this.selected,
    required this.routeRole,
    required this.routeMode,
    required this.onTap,
    required this.onLongPress,
  });
  final TripStop stop;
  final int index;
  final bool selected;
  final String? routeRole;
  final bool routeMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = tagColor(stop.tag);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: routeRole != null
                  ? kForest
                  : selected
                  ? color
                  : Colors.black.withValues(alpha: .08),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        routeRole ?? '$index',
                        style: TextStyle(
                          color: routeRole == null
                              ? tagTextColor(stop.tag)
                              : kForest,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      formatDisplayTime(stop.time),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: kMuted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                stop.place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: TinyPill(label: stop.tag, color: color),
                  ),
                  if (routeMode) ...[
                    const SizedBox(width: 5),
                    Icon(Icons.touch_app_rounded, size: 14, color: kMuted),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteStatusText extends StatelessWidget {
  const _RouteStatusText({
    required this.result,
    required this.loading,
    required this.error,
  });

  final _RouteResult? result;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = loading
        ? 'Loading route...'
        : error ?? result?.label ?? 'Select two locations for routing.';
    return Row(
      children: [
        if (loading) ...[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: error == null
                  ? kMuted
                  : Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StopDetailSheet extends StatelessWidget {
  const _StopDetailSheet({required this.stop});

  final TripStop stop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = tagColor(stop.tag);
    final cityState = _cityState(stop.place);

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: .72,
        minChildSize: .42,
        maxChildSize: .92,
        expand: false,
        builder: (context, scrollController) {
          return Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    _StopDetailImage(stop: stop),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(stop.icon, color: color, size: 23),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stop.place,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        height: 1.04,
                                      ),
                                ),
                                if (cityState.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    cityState,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: cs.onSurface.withValues(
                                            alpha: .58,
                                          ),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TinyPill(label: stop.tag, color: color),
                          TinyPill(
                            label: formatDisplayTime(stop.time),
                            color: kForest,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        stop.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stop.note.isEmpty
                            ? 'No extra notes are saved for this location yet.'
                            : stop.note,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(height: 1.34),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Online reviews',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      _ReviewLink(
                        icon: Icons.map_outlined,
                        label: 'Google reviews',
                        subtitle: 'Open this place in Google Maps',
                        onTap: () =>
                            _openReviewSearch(stop, _ReviewSource.google),
                      ),
                      _ReviewLink(
                        icon: Icons.travel_explore_rounded,
                        label: 'Tripadvisor',
                        subtitle: 'Search traveler reviews',
                        onTap: () =>
                            _openReviewSearch(stop, _ReviewSource.tripadvisor),
                      ),
                      _ReviewLink(
                        icon: Icons.rate_review_outlined,
                        label: 'Yelp',
                        subtitle: 'Search local reviews',
                        onTap: () =>
                            _openReviewSearch(stop, _ReviewSource.yelp),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reviews open from external sources so they stay current.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: .56),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StopDetailImage extends StatelessWidget {
  const _StopDetailImage({required this.stop});

  final TripStop stop;

  @override
  Widget build(BuildContext context) {
    final url = _mapboxAccessToken.isEmpty ? null : _staticMapUrl(stop);
    if (url == null) return const _StopDetailImageFallback();

    return SizedBox(
      height: 210,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _StopDetailImageFallback(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const _StopDetailImageFallback();
        },
      ),
    );
  }
}

class _StopDetailImageFallback extends StatelessWidget {
  const _StopDetailImageFallback();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 210,
      width: double.infinity,
      color: cs.onSurface.withValues(alpha: .06),
      child: Center(
        child: Icon(
          Icons.photo_outlined,
          size: 46,
          color: cs.onSurface.withValues(alpha: .35),
        ),
      ),
    );
  }
}

class _ReviewLink extends StatelessWidget {
  const _ReviewLink({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.onSurface.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: kForest, size: 21),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: .58),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  color: cs.onSurface.withValues(alpha: .42),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openRouteInMaps(TripStop start, TripStop end) async {
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'origin': '${start.latitude},${start.longitude}',
    'destination': '${end.latitude},${end.longitude}',
    'travelmode': 'driving',
  });
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}

enum _ReviewSource { google, tripadvisor, yelp }

Future<void> _openReviewSearch(TripStop stop, _ReviewSource source) async {
  final query = '${stop.place} ${_cityState(stop.place)} reviews'.trim();
  final uri = switch (source) {
    _ReviewSource.google => Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    }),
    _ReviewSource.tripadvisor => Uri.https('www.tripadvisor.com', '/Search', {
      'q': query,
    }),
    _ReviewSource.yelp => Uri.https('www.yelp.com', '/search', {
      'find_desc': stop.place,
      if (_cityState(stop.place).isNotEmpty) 'find_loc': _cityState(stop.place),
    }),
  };

  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}

String _cityState(String place) {
  final parts = place
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 3) return '${parts[parts.length - 2]}, ${parts.last}';
  if (parts.length == 2) return parts.last;
  return '';
}

String _staticMapUrl(TripStop stop) {
  final marker =
      'pin-s+0b1f1a(${stop.longitude.toStringAsFixed(5)},${stop.latitude.toStringAsFixed(5)})';
  final center =
      '${stop.longitude.toStringAsFixed(5)},${stop.latitude.toStringAsFixed(5)},13,0';
  return 'https://api.mapbox.com/styles/v1/$_mapboxStyle/static/$marker/$center/480x280?access_token=$_mapboxAccessToken';
}

class _RouteResult {
  const _RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });

  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> points;

  String get label => 'Drive time: ${_formatDuration(durationSeconds)}';

  static Future<_RouteResult> fetch(TripStop start, TripStop end) async {
    final uri = _mapboxAccessToken.isEmpty
        ? Uri.https(
            'router.project-osrm.org',
            '/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
            {'overview': 'full', 'geometries': 'geojson'},
          )
        : Uri.https(
            'api.mapbox.com',
            '/directions/v5/mapbox/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
            {
              'overview': 'full',
              'geometries': 'geojson',
              'access_token': _mapboxAccessToken,
            },
          );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Route service returned ${response.statusCode}.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = body['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) throw StateError('No route found.');

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>? ?? const {};
    final coordinates = geometry['coordinates'] as List<dynamic>? ?? const [];
    final points = [
      for (final coordinate in coordinates)
        if (coordinate is List && coordinate.length >= 2)
          LatLng(
            (coordinate[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          ),
    ];

    return _RouteResult(
      distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
      points: points,
    );
  }

  static String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '${hours}h';
    return '${hours}h ${rest}m';
  }
}
