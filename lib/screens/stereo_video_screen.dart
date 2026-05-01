import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class StereoVideoScreen extends StatefulWidget {
  final String videoUrl;
  const StereoVideoScreen({super.key, required this.videoUrl});

  @override
  State<StereoVideoScreen> createState() => _StereoVideoScreenState();
}

class _StereoVideoScreenState extends State<StereoVideoScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller; // shared controller for perfect sync
  bool _ready = false;
  double? _originalBrightness;
  static const MethodChannel _brightnessChannel = MethodChannel(
    'screen_brightness',
  );
  StreamSubscription<dynamic>? _gyroSub;
  // Camera-like orientation (radians)
  double _yaw = 0.0; // left-right head turn
  double _pitch = 0.0; // up-down head tilt
  double _targetYaw = 0.0;
  double _targetPitch = 0.0;
  static const EventChannel _gyroChannel = EventChannel('gyro_stream');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersiveLandscape();
    _boostBrightness();
    _init();
    _initGyro();
    // Re-apply brightness after first frame to avoid being overridden by transitions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boostBrightness();
    });
  }

  Future<void> _init() async {
    try {
      final isNetwork = widget.videoUrl.startsWith('http');
      final options = VideoPlayerOptions(mixWithOthers: true);
      _controller =
          isNetwork
              ? VideoPlayerController.networkUrl(
                Uri.parse(widget.videoUrl),
                videoPlayerOptions: options,
              )
              : VideoPlayerController.file(
                File(widget.videoUrl),
                videoPlayerOptions: options,
              );

      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.seekTo(Duration.zero);
      await _controller!.play();
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi mở video 3D: $e')));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _restoreBrightness();
    _exitImmersiveLandscape();
    _gyroSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-apply immersive and brightness when returning to foreground
      _enterImmersiveLandscape();
      _boostBrightness();
    }
  }

  void _toggle() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _ready
              ? Padding(
                padding: const EdgeInsets.all(2.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: const Color(0xFF001122),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(
                            color: Color(0xFF00FF00), // left eye stroke
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildPane(_controller!, isLeft: true),
                      ),
                    ),
                    const SizedBox(width: 1),
                    Expanded(
                      child: Card(
                        color: const Color(0xFF001122),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(
                            color: Color(0xFFFF6600), // right eye stroke
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildPane(_controller!, isLeft: false),
                      ),
                    ),
                  ],
                ),
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildPane(VideoPlayerController c, {required bool isLeft}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: _buildCameraTransformedVideo(c, isLeft: isLeft),
        ),
      ),
    );
  }

  Widget _buildCameraTransformedVideo(
    VideoPlayerController c, {
    required bool isLeft,
  }) {
    // Perspective + camera-like rotation; slight opposite yaw per eye for stereo
    const double perspective = 0.001; // subtle perspective
    const double eyeYawFactor =
        0.35; // split yaw between camera and eye separation (softer for budget VR)
    final double effectiveYaw = _yaw * eyeYawFactor * (isLeft ? 1.0 : -1.0);
    final double effectivePitch = _pitch; // same pitch for both eyes

    final matrix =
        Matrix4.identity()
          ..setEntry(3, 2, perspective)
          ..rotateX(effectivePitch)
          ..rotateY(effectiveYaw);

    // Scale up slightly to hide edges during rotation
    const double coverScale = 1.08;

    return Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: FittedBox(
        fit: BoxFit.cover,
        child: Transform.scale(
          scale: coverScale,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
      ),
    );
  }

  Future<void> _enterImmersiveLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitImmersiveLandscape() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _boostBrightness() async {
    try {
      final current = await _brightnessChannel.invokeMethod<double>(
        'getBrightness',
      );
      _originalBrightness = current;
      await _brightnessChannel.invokeMethod('setBrightness', 1.0);
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    try {
      if (_originalBrightness != null) {
        await _brightnessChannel.invokeMethod(
          'setBrightness',
          _originalBrightness,
        );
      }
    } catch (_) {}
  }

  void _initGyro() {
    // Map gyroscope rad/s to small rotation angles (radians)
    const double angleScale = 0.018; // softer sensitivity for budget VR
    const double maxAngle = 0.15; // tighter clamp to reduce distortion
    _gyroSub = _gyroChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final double ex = (event['x'] as num?)?.toDouble() ?? 0.0; // pitch
        final double ey = (event['y'] as num?)?.toDouble() ?? 0.0; // yaw

        final double tYaw = (ey * angleScale).clamp(-maxAngle, maxAngle);
        final double tPitch = (ex * angleScale).clamp(-maxAngle, maxAngle);

        const double alpha = 0.08; // stronger smoothing for stability
        _targetYaw = tYaw;
        _targetPitch = tPitch;
        _yaw = _yaw + (_targetYaw - _yaw) * alpha;
        _pitch = _pitch + (_targetPitch - _pitch) * alpha;

        if (mounted) setState(() {});
      }
    });
  }
}
