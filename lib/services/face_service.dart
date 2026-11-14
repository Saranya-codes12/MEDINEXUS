import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// A problem the user can fix (no face, bad light, ...). [message] is shown as is.
class FaceException implements Exception {
  final String message;
  FaceException(this.message);

  @override
  String toString() => message;
}

/// One processed photo: where the face points and its numeric template.
class FaceSample {
  final List<double> embedding;

  /// Head turn in degrees (left/right). 0 means looking straight at the camera.
  final double yaw;
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  const FaceSample({
    required this.embedding,
    required this.yaw,
    this.leftEyeOpen,
    this.rightEyeOpen,
  });

  bool get eyesOpen => (leftEyeOpen ?? 1.0) > 0.3 && (rightEyeOpen ?? 1.0) > 0.3;
}

/// All templates stored for one employee.
class EnrolledFace {
  final String employeeId;
  final String name;
  final String? designation;
  final List<List<double>> templates;

  const EnrolledFace({
    required this.employeeId,
    required this.name,
    this.designation,
    required this.templates,
  });
}

class MatchResult {
  final EnrolledFace? face;
  final double score;
  final String? reason;

  const MatchResult({this.face, required this.score, this.reason});

  bool get isMatch => face != null;
}

/// Face detection, embedding and matching, fully on the device.
///
/// Pipeline: ML Kit finds the face -> the face is cropped and resized ->
/// a MobileFaceNet-style TFLite model turns it into a vector (embedding) ->
/// two faces are compared with cosine similarity.
class FaceService {
  FaceService._();
  static final FaceService instance = FaceService._();

  // ----- Settings you can tune ------------------------------------------------

  /// Put the .tflite file here and list it under `flutter: assets:` in pubspec.yaml.
  static const String modelAsset = 'assets/models/mobile_face_net.tflite';

  /// Pixel normalisation used by MobileFaceNet: (pixel - mean) / std.
  /// If you use a different model, change these two values to match it.
  static const double inputMean = 127.5;
  static const double inputStd = 128.0;

  /// Minimum cosine similarity to accept a match. Higher = stricter.
  /// Tune it on your own staff photos: raise it if the wrong person is accepted,
  /// lower it if the right person is rejected.
  static const double matchThreshold = 0.70;

  /// The best employee must beat the next best by at least this much,
  /// otherwise the result is treated as ambiguous.
  static const double minMargin = 0.05;

  /// Liveness (head-turn challenge).
  static const double frontalYawDeg = 12.0; // photo 1 must be this straight
  static const double turnDeltaDeg = 15.0; // photo 2 must differ by at least this
  static const double sameFaceMin = 0.35; // both photos must show the same person

  /// The face must fill at least this share of the photo width.
  static const double minFaceWidthRatio = 0.22;

  // ----- Internals --------------------------------------------------------------

  Interpreter? _interpreter;
  FaceDetector? _detector;
  int _inW = 112;
  int _inH = 112;
  int _outLen = 192;

  Future<void> init() async {
    if (_interpreter != null) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        modelAsset,
        options: InterpreterOptions()..threads = 2,
      );
    } catch (e) {
      throw FaceException(
        'The face model could not be loaded. Check that $modelAsset exists and is listed in pubspec.yaml. ($e)',
      );
    }

    // Read the real sizes from the model so other compatible models also work.
    final inShape = _interpreter!.getInputTensor(0).shape; // [1, H, W, 3]
    final outShape = _interpreter!.getOutputTensor(0).shape; // [1, N]
    _inH = inShape[1];
    _inW = inShape[2];
    _outLen = outShape.last;

    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true, // eye-open probabilities
        enableLandmarks: false,
        enableContours: false,
        enableTracking: false,
        minFaceSize: 0.2,
      ),
    );
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
    _interpreter?.close();
    _interpreter = null;
  }

  /// Reads one photo, finds exactly one face and returns its template.
  /// The photo file is deleted afterwards because only the template is kept.
  Future<FaceSample> processFile(String path, {bool deleteSource = true}) async {
    await init();

    File? upright;
    try {
      final bytes = await File(path).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) throw FaceException('The photo could not be read. Please try again.');

      // Phones store a rotation flag in the file. Apply it so the pixels we crop
      // are the same ones ML Kit reports coordinates for.
      image = img.bakeOrientation(image);
      upright = File('${Directory.systemTemp.path}/face_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await upright.writeAsBytes(img.encodeJpg(image, quality: 92));

      final faces = await _detector!.processImage(InputImage.fromFilePath(upright.path));
      if (faces.isEmpty) {
        throw FaceException('No face found. Hold the phone at eye level, in good light.');
      }
      if (faces.length > 1) {
        throw FaceException('More than one face is in the photo. Only one person should be in front of the camera.');
      }

      final face = faces.first;
      final box = face.boundingBox;
      if (box.width / image.width < minFaceWidthRatio) {
        throw FaceException('Move closer to the camera.');
      }

      // Square crop around the face with a small margin.
      final maxSide = math.min(image.width, image.height).toDouble();
      final side = math.min(math.max(box.width, box.height) * 1.25, maxSide);
      final x = _clamp(box.center.dx - side / 2, 0, image.width - side).round();
      final y = _clamp(box.center.dy - side / 2, 0, image.height - side).round();
      final s = side.round();

      final cropped = img.copyCrop(image, x: x, y: y, width: s, height: s);
      final resized = img.copyResize(
        cropped,
        width: _inW,
        height: _inH,
        interpolation: img.Interpolation.linear,
      );

      return FaceSample(
        embedding: _embed(resized),
        yaw: face.headEulerAngleY ?? 0.0,
        leftEyeOpen: face.leftEyeOpenProbability,
        rightEyeOpen: face.rightEyeOpenProbability,
      );
    } finally {
      if (upright != null) {
        try {
          await upright.delete();
        } catch (_) {}
      }
      if (deleteSource) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
  }

  List<double> _embed(img.Image face) {
    final input = Float32List(_inH * _inW * 3);
    var i = 0;
    for (var y = 0; y < _inH; y++) {
      for (var x = 0; x < _inW; x++) {
        final p = face.getPixel(x, y);
        input[i++] = (p.r.toDouble() - inputMean) / inputStd;
        input[i++] = (p.g.toDouble() - inputMean) / inputStd;
        input[i++] = (p.b.toDouble() - inputMean) / inputStd;
      }
    }

    final output = List.generate(1, (_) => List<double>.filled(_outLen, 0.0));
    _interpreter!.run(input.reshape([1, _inH, _inW, 3]), output);
    return _l2Normalize(output[0]);
  }

  // ----- Comparing faces --------------------------------------------------------

  /// Cosine similarity of two normalised embeddings (-1 .. 1).
  double similarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return -1.0;
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  /// Finds the enrolled employee that best matches [probe].
  MatchResult match(List<double> probe, List<EnrolledFace> enrolled) {
    if (enrolled.isEmpty) {
      return const MatchResult(score: -1, reason: 'No faces are enrolled for this facility yet.');
    }

    EnrolledFace? best;
    var bestScore = -1.0;
    var secondScore = -1.0;

    for (final e in enrolled) {
      var s = -1.0;
      for (final t in e.templates) {
        s = math.max(s, similarity(probe, t));
      }
      if (s > bestScore) {
        secondScore = bestScore;
        bestScore = s;
        best = e;
      } else if (s > secondScore) {
        secondScore = s;
      }
    }

    if (best == null || bestScore < matchThreshold) {
      return MatchResult(
        score: bestScore,
        reason: 'Face not recognised. Try again in better light, or use the manual override.',
      );
    }
    if (secondScore > -1 && bestScore - secondScore < minMargin) {
      return MatchResult(
        score: bestScore,
        reason: 'The face is close to more than one employee. Try again, or use the manual override.',
      );
    }
    return MatchResult(face: best, score: bestScore);
  }

  // ----- Liveness (challenge-response) ---------------------------------------------

  /// [straight] is the first photo, [turned] the second one taken after the user
  /// was asked to turn the head. Returns null when the challenge is passed,
  /// otherwise a message for the user.
  ///
  /// This is a basic check against a still photograph held to the camera. It is
  /// not a certified presentation-attack-detection system, so a replayed video
  /// can still pass.
  String? checkChallenge(FaceSample straight, FaceSample turned) {
    if (straight.yaw.abs() > frontalYawDeg) {
      return 'Look straight at the camera for the first photo.';
    }
    if ((turned.yaw - straight.yaw).abs() < turnDeltaDeg) {
      return 'Head turn not detected. Turn your head slightly to one side when asked.';
    }
    if (similarity(straight.embedding, turned.embedding) < sameFaceMin) {
      return 'The two photos do not look like the same person.';
    }
    return null;
  }

  // ----- Helpers -------------------------------------------------------------------

  List<double> _l2Normalize(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final norm = math.sqrt(sum);
    if (norm == 0) return v;
    return [for (final x in v) x / norm];
  }

  double _clamp(double v, double lo, double hi) {
    if (hi < lo) return lo;
    return v < lo ? lo : (v > hi ? hi : v);
  }
}