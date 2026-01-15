import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class LatencyTestAllModelsPage extends StatefulWidget {
  const LatencyTestAllModelsPage({super.key});

  @override
  State<LatencyTestAllModelsPage> createState() =>
      _LatencyTestAllModelsPageState();
}

class _LatencyTestAllModelsPageState extends State<LatencyTestAllModelsPage> {
  // Model paths (match your existing services)
  static const String poseModelPath =
      'assets/models/efficientnet_b0_fp16.tflite';
  static const String exprModelPath = 'assets/models/mobilenetv3_fp16.tflite';
  static const String cryModelPath = 'assets/models/resnet18_fp16.tflite';

  // Shared settings
  static const int threads = 2;
  static const int inputSize = 224;
  static const int warmupRuns = 20;
  static const int measureRuns = 100;

  // Classes
  static const int poseClasses = 2; // ['Abnormal','Normal']
  static const int exprClasses = 2; // ['Distressed','Normal']
  static const int cryClasses = 4;  // ['Asphyxia','Hungry','Normal','Pain']

  Interpreter? _pose;
  Interpreter? _expr;
  Interpreter? _cry;

  bool _loading = true;
  bool _running = false;
  String _status = "Loading models…";

  Map<String, double>? _poseRes;
  Map<String, double>? _exprRes;
  Map<String, double>? _cryRes;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final opt = InterpreterOptions()..threads = threads ..useNnApiForAndroid = false;

      _pose = await Interpreter.fromAsset(poseModelPath, options: opt);
      _expr = await Interpreter.fromAsset(exprModelPath, options: opt);
      _cry = await Interpreter.fromAsset(cryModelPath, options: opt);

      setState(() {
        _loading = false;
        _status = "Models loaded";
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = "Error loading models: $e";
      });
    }
  }

  @override
  void dispose() {
    _pose?.close();
    _expr?.close();
    _cry?.close();
    super.dispose();
  }

  // Dummy NHWC input [1,224,224,3]
  List _dummyInput() {
    return List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (_) => List.generate(
          inputSize,
          (_) => List.filled(3, 0.5),
        ),
      ),
    );
  }

  List _outputBuffer(int numClasses) {
    return List.generate(1, (_) => List.filled(numClasses, 0.0));
  }

  Map<String, double> _computeStats(List<double> timesMs) {
    timesMs.sort();
    final mean = timesMs.reduce((a, b) => a + b) / timesMs.length;
    final p95 = timesMs[(0.95 * (timesMs.length - 1)).round()];
    return {"mean_ms": mean, "p95_ms": p95};
  }

  Future<Map<String, double>> _benchmarkInterpreter({
    required Interpreter interpreter,
    required int numClasses,
  }) async {
    final input = _dummyInput();
    final output = _outputBuffer(numClasses);

    // Warm-up
    for (int i = 0; i < warmupRuns; i++) {
      interpreter.run(input, output);
    }

    // Measure
    final times = <double>[];
    for (int i = 0; i < measureRuns; i++) {
      final sw = Stopwatch()..start();
      interpreter.run(input, output);
      sw.stop();
      times.add(sw.elapsedMicroseconds / 1000.0);
    }

    return _computeStats(times);
  }

  Future<void> _runAll() async {
    if (_loading || _running) return;
    if (_pose == null || _expr == null || _cry == null) return;

    setState(() {
      _running = true;
      _status = "Running latency tests…";
      _poseRes = null;
      _exprRes = null;
      _cryRes = null;
    });

    try {
      final pose = await _benchmarkInterpreter(
        interpreter: _pose!,
        numClasses: poseClasses,
      );

      final expr = await _benchmarkInterpreter(
        interpreter: _expr!,
        numClasses: exprClasses,
      );

      final cry = await _benchmarkInterpreter(
        interpreter: _cry!,
        numClasses: cryClasses,
      );

      setState(() {
        _poseRes = pose;
        _exprRes = expr;
        _cryRes = cry;
        _running = false;
        _status = "Completed";
      });

      debugPrint(
        "Latency results (ms) — Pose mean=${pose["mean_ms"]!.toStringAsFixed(2)} "
        "p95=${pose["p95_ms"]!.toStringAsFixed(2)} | "
        "Expr mean=${expr["mean_ms"]!.toStringAsFixed(2)} "
        "p95=${expr["p95_ms"]!.toStringAsFixed(2)} | "
        "Cry(CNN) mean=${cry["mean_ms"]!.toStringAsFixed(2)} "
        "p95=${cry["p95_ms"]!.toStringAsFixed(2)}",
      );
    } catch (e) {
      setState(() {
        _running = false;
        _status = "Error during test: $e";
      });
    }
  }

  Widget _resultCard(String title, Map<String, double>? res) {
    if (res == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text("$title: (not run yet)"),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("Mean: ${res["mean_ms"]!.toStringAsFixed(2)} ms"),
            Text("P95 : ${res["p95_ms"]!.toStringAsFixed(2)} ms"),
            const SizedBox(height: 6),
            Text("Warm-up: $warmupRuns, Runs: $measureRuns, Threads: $threads"),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRun = !_loading && !_running;

    return Scaffold(
      appBar: AppBar(title: const Text("Latency Test (All Models)")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              "Inference-only latency (TFLite FP16)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("Input: 1 × 224 × 224 × 3 (dummy tensor)"),
            const SizedBox(height: 8),
            Text("Status: $_status"),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: canRun ? _runAll : null,
              child: Text(_running ? "Running…" : "Run All Tests"),
            ),

            const SizedBox(height: 16),
            _resultCard("Pose (EfficientNet-B0)", _poseRes),
            _resultCard("Expression (MobileNetV3-Small)", _exprRes),
            _resultCard("Cry CNN (ResNet-18 only)", _cryRes),

            const SizedBox(height: 12),
            const Text(
              "Note: Cry result measures only the ResNet-18 CNN inference (excluding audio parsing, resampling, and 5s voting) for fair architectural comparison.",
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
