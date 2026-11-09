import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Parses SVG path data strings into [ui.Path] objects.
///
/// Supports all standard SVG path commands:
/// - M/m (moveto), L/l (lineto), H/h (horizontal lineto), V/v (vertical lineto)
/// - C/c (cubic Bézier), S/s (smooth cubic Bézier)
/// - Q/q (quadratic Bézier), T/t (smooth quadratic Bézier)
/// - A/a (elliptical arc)
/// - Z/z (closepath)
///
/// Handles implicit repeated coordinates and concatenated numbers (e.g., "12.5-3.4").
class SvgPathParser {
  final String _data;
  int _index = 0;
  double _lastX = 0;
  double _lastY = 0;
  double _lastControlX = 0;
  double _lastControlY = 0;
  bool _started = false;
  double _subpathStartX = 0;
  double _subpathStartY = 0;

  SvgPathParser(this._data);

  /// Parse the SVG path data and return a [ui.Path].
  ui.Path parse() {
    final path = ui.Path();
    _index = 0;
    _lastX = 0;
    _lastY = 0;
    _lastControlX = 0;
    _lastControlY = 0;
    _started = false;

    while (_index < _data.length) {
      _skipWhitespace();
      if (_index >= _data.length) break;

      final char = _data[_index];
      if (_isCommandChar(char)) {
        _index++;
        _parseCommand(path, char);
      } else {
        throw FormatException(
            'Unexpected character at position $_index: $char');
      }
    }

    return path;
  }

  bool _isCommandChar(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122); // A-Z or a-z
  }

  void _skipWhitespace() {
    while (_index < _data.length) {
      final c = _data[_index];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == ',') {
        _index++;
      } else {
        break;
      }
    }
  }

  void _parseCommand(ui.Path path, String cmd) {
    final isRelative = cmd == cmd.toLowerCase();
    final cmdUpper = cmd.toUpperCase();

    switch (cmdUpper) {
      case 'M':
        _parseMoveto(path, isRelative);
        while (_index < _data.length) {
          _skipWhitespace();
          if (_index >= _data.length) break;
          final nextChar = _data[_index];
          if (_isCommandChar(nextChar)) break;
          _parseLineto(path, isRelative);
        }
        break;
      case 'L':
        _parseLineto(path, isRelative);
        while (_index < _data.length) {
          _skipWhitespace();
          if (_index >= _data.length) break;
          final nextChar = _data[_index];
          if (_isCommandChar(nextChar)) break;
          _parseLineto(path, isRelative);
        }
        break;
      case 'H':
        _parseHorizontalLineto(path, isRelative);
        while (_index < _data.length) {
          _skipWhitespace();
          if (_index >= _data.length) break;
          final nextChar = _data[_index];
          if (_isCommandChar(nextChar)) break;
          _parseHorizontalLineto(path, isRelative);
        }
        break;
      case 'V':
        _parseVerticalLineto(path, isRelative);
        while (_index < _data.length) {
          _skipWhitespace();
          if (_index >= _data.length) break;
          final nextChar = _data[_index];
          if (_isCommandChar(nextChar)) break;
          _parseVerticalLineto(path, isRelative);
        }
        break;
      case 'C':
        _parseCubicBezier(path, isRelative);
        while (_index < _data.length) {
          _skipWhitespace();
          if (_index >= _data.length) break;
          final nextChar = _data[_index];
          if (_isCommandChar(nextChar)) break;
          _parseCubicBezier(path, isRelative);
        }
        break;
      case 'S':
        _parseSmoothCubicBezier(path, isRelative);
        while (_index < _data.length) {
          _skipWhitespace();
          if (_index >= _data.length) break;
          final nextChar = _data[_index];
          if (_isCommandChar(nextChar)) break;
          _parseSmoothCubicBezier(path, isRelative);
        }
        break;
      case 'Q':
        _parseQuadraticBezier(path, isRelative);
        while (_index < _data.length) {
          _skipWhitespace();
          if (_index >= _data.length) break;
          final nextChar = _data[_index];
          if (_isCommandChar(nextChar)) break;
          _parseQuadraticBezier(path, isRelative);
        }
        break;
      case 'T':
        _parseSmoothQuadraticBezier(path, isRelative);
        while (_index < _data.length) {
          _skipWhitespace();
          if (_index >= _data.length) break;
          final nextChar = _data[_index];
          if (_isCommandChar(nextChar)) break;
          _parseSmoothQuadraticBezier(path, isRelative);
        }
        break;
      case 'A':
        _parseArc(path, isRelative);
        while (_index < _data.length) {
          _skipWhitespace();
          if (_index >= _data.length) break;
          final nextChar = _data[_index];
          if (_isCommandChar(nextChar)) break;
          _parseArc(path, isRelative);
        }
        break;
      case 'Z':
        _closePath(path);
        break;
    }
  }

  double _parseNumber() {
    _skipWhitespace();
    if (_index >= _data.length) {
      throw FormatException('Unexpected end of data while parsing number');
    }

    final start = _index;
    bool hasSign = false;
    bool hasDot = false;
    bool hasExponent = false;

    while (_index < _data.length) {
      final c = _data[_index];
      if ((c == '+' || c == '-') && !hasSign && _index == start) {
        hasSign = true;
        _index++;
      } else if (c == '.' && !hasDot && !hasExponent) {
        hasDot = true;
        _index++;
      } else if ((c == 'e' || c == 'E') && !hasExponent) {
        hasExponent = true;
        _index++;
        if (_index < _data.length &&
            (_data[_index] == '+' || _data[_index] == '-')) {
          _index++;
        }
      } else if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
        // 0-9
        _index++;
      } else {
        break;
      }
    }

    if (_index == start) {
      throw FormatException('Expected number at position $start');
    }

    return double.parse(_data.substring(start, _index));
  }

  void _parseMoveto(ui.Path path, bool relative) {
    final x = _parseNumber();
    final y = _parseNumber();
    _lastX = relative ? _lastX + x : x;
    _lastY = relative ? _lastY + y : y;
    if (!_started) {
      path.moveTo(_lastX, _lastY);
      _subpathStartX = _lastX;
      _subpathStartY = _lastY;
      _started = true;
    } else {
      path.lineTo(_lastX, _lastY);
    }
    _lastControlX = _lastX;
    _lastControlY = _lastY;
  }

  void _parseLineto(ui.Path path, bool relative) {
    final x = _parseNumber();
    final y = _parseNumber();
    _lastX = relative ? _lastX + x : x;
    _lastY = relative ? _lastY + y : y;
    path.lineTo(_lastX, _lastY);
    _lastControlX = _lastX;
    _lastControlY = _lastY;
  }

  void _parseHorizontalLineto(ui.Path path, bool relative) {
    final x = _parseNumber();
    _lastX = relative ? _lastX + x : x;
    path.lineTo(_lastX, _lastY);
    _lastControlX = _lastX;
    _lastControlY = _lastY;
  }

  void _parseVerticalLineto(ui.Path path, bool relative) {
    final y = _parseNumber();
    _lastY = relative ? _lastY + y : y;
    path.lineTo(_lastX, _lastY);
    _lastControlX = _lastX;
    _lastControlY = _lastY;
  }

  void _parseCubicBezier(ui.Path path, bool relative) {
    final x1 = _parseNumber();
    final y1 = _parseNumber();
    final x2 = _parseNumber();
    final y2 = _parseNumber();
    final x = _parseNumber();
    final y = _parseNumber();

    final c1x = relative ? _lastX + x1 : x1;
    final c1y = relative ? _lastY + y1 : y1;
    final c2x = relative ? _lastX + x2 : x2;
    final c2y = relative ? _lastY + y2 : y2;
    final ex = relative ? _lastX + x : x;
    final ey = relative ? _lastY + y : y;

    path.cubicTo(c1x, c1y, c2x, c2y, ex, ey);
    _lastControlX = c2x;
    _lastControlY = c2y;
    _lastX = ex;
    _lastY = ey;
  }

  void _parseSmoothCubicBezier(ui.Path path, bool relative) {
    double c1x, c1y;
    if (_lastControlX != 0 || _lastControlY != 0) {
      c1x = _lastX + (_lastX - _lastControlX);
      c1y = _lastY + (_lastY - _lastControlY);
    } else {
      c1x = _lastX;
      c1y = _lastY;
    }

    final x2 = _parseNumber();
    final y2 = _parseNumber();
    final x = _parseNumber();
    final y = _parseNumber();

    final c2x = relative ? _lastX + x2 : x2;
    final c2y = relative ? _lastY + y2 : y2;
    final ex = relative ? _lastX + x : x;
    final ey = relative ? _lastY + y : y;

    path.cubicTo(c1x, c1y, c2x, c2y, ex, ey);
    _lastControlX = c2x;
    _lastControlY = c2y;
    _lastX = ex;
    _lastY = ey;
  }

  void _parseQuadraticBezier(ui.Path path, bool relative) {
    final x1 = _parseNumber();
    final y1 = _parseNumber();
    final x = _parseNumber();
    final y = _parseNumber();

    final c1x = relative ? _lastX + x1 : x1;
    final c1y = relative ? _lastY + y1 : y1;
    final ex = relative ? _lastX + x : x;
    final ey = relative ? _lastY + y : y;

    path.quadraticBezierTo(c1x, c1y, ex, ey);
    _lastControlX = c1x;
    _lastControlY = c1y;
    _lastX = ex;
    _lastY = ey;
  }

  void _parseSmoothQuadraticBezier(ui.Path path, bool relative) {
    double c1x, c1y;
    if (_lastControlX != 0 || _lastControlY != 0) {
      c1x = _lastX + (_lastX - _lastControlX);
      c1y = _lastY + (_lastY - _lastControlY);
    } else {
      c1x = _lastX;
      c1y = _lastY;
    }

    final x = _parseNumber();
    final y = _parseNumber();

    final ex = relative ? _lastX + x : x;
    final ey = relative ? _lastY + y : y;

    path.quadraticBezierTo(c1x, c1y, ex, ey);
    _lastControlX = c1x;
    _lastControlY = c1y;
    _lastX = ex;
    _lastY = ey;
  }

  void _parseArc(ui.Path path, bool relative) {
    final rx = _parseNumber().abs();
    final ry = _parseNumber().abs();
    final xAxisRotation = _parseNumber() * math.pi / 180.0;
    final largeArcFlag = _parseNumber().round();
    final sweepFlag = _parseNumber().round();
    final x = _parseNumber();
    final y = _parseNumber();

    final ex = relative ? _lastX + x : x;
    final ey = relative ? _lastY + y : y;

    if (rx == 0 || ry == 0) {
      path.lineTo(ex, ey);
      _lastX = ex;
      _lastY = ey;
      return;
    }

    final sinPhi = math.sin(xAxisRotation);
    final cosPhi = math.cos(xAxisRotation);

    final dx = (_lastX - ex) / 2;
    final dy = (_lastY - ey) / 2;

    final x1p = cosPhi * dx + sinPhi * dy;
    final y1p = -sinPhi * dx + cosPhi * dy;

    final rxSq = rx * rx;
    final rySq = ry * ry;
    final x1pSq = x1p * x1p;
    final y1pSq = y1p * y1p;

    var radiiCheck = x1pSq / rxSq + y1pSq / rySq;
    if (radiiCheck > 1) {
      // Scale factor (not used in simplified implementation)
      math.sqrt(radiiCheck);
    }

    final sign = (largeArcFlag == sweepFlag) ? -1.0 : 1.0;
    final sq = (rxSq * rySq - rxSq * y1pSq - rySq * x1pSq) /
        (rxSq * y1pSq + rySq * x1pSq);
    final coef = sign * math.sqrt(sq.clamp(0.0, double.infinity));

    final cxp = coef * rx * y1p / ry;
    final cyp = -coef * ry * x1p / rx;

    final cx = cosPhi * cxp - sinPhi * cyp + (_lastX + ex) / 2;
    final cy = sinPhi * cxp + cosPhi * cyp + (_lastY + ey) / 2;

    final v1x = (x1p - cxp) / rx;
    final v1y = (y1p - cyp) / ry;
    final v2x = (-x1p - cxp) / rx;
    final v2y = (-y1p - cyp) / ry;

    var startAngle = math.atan2(v1y, v1x);
    var deltaAngle = math.atan2(v2y, v2x) - startAngle;

    if (sweepFlag == 0 && deltaAngle > 0) {
      deltaAngle -= 2 * math.pi;
    } else if (sweepFlag == 1 && deltaAngle < 0) {
      deltaAngle += 2 * math.pi;
    }

    _drawArc(path, cx, cy, rx, ry, startAngle, deltaAngle, xAxisRotation);

    _lastX = ex;
    _lastY = ey;
    _lastControlX = _lastX;
    _lastControlY = _lastY;
  }

  void _drawArc(
    ui.Path path,
    double cx,
    double cy,
    double rx,
    double ry,
    double startAngle,
    double deltaAngle,
    double xAxisRotation,
  ) {
    const maxSegmentAngle = math.pi / 2;
    final numSegments = (deltaAngle.abs() / maxSegmentAngle).ceil();
    final segmentAngle = deltaAngle / numSegments;

    final sinPhi = math.sin(xAxisRotation);
    final cosPhi = math.cos(xAxisRotation);

    for (int i = 0; i < numSegments; i++) {
      final theta0 = startAngle + i * segmentAngle;
      final theta1 = startAngle + (i + 1) * segmentAngle;

      final p0x =
          cx + rx * math.cos(theta0) * cosPhi - ry * math.sin(theta0) * sinPhi;
      final p0y =
          cy + rx * math.cos(theta0) * sinPhi + ry * math.sin(theta0) * cosPhi;
      final p1x =
          cx + rx * math.cos(theta1) * cosPhi - ry * math.sin(theta1) * sinPhi;
      final p1y =
          cy + rx * math.cos(theta1) * sinPhi + ry * math.sin(theta1) * cosPhi;

      if (i == 0) {
        if (path.getBounds().isEmpty) {
          path.moveTo(p0x, p0y);
        } else {
          path.lineTo(p0x, p0y);
        }
      }

      final halfAngle = (theta1 - theta0) / 2;
      final k = 4.0 / 3.0 * math.tan(halfAngle / 2);

      final cp0xU = rx * (math.cos(theta0) - k * math.sin(theta0));
      final cp0yU = ry * (math.sin(theta0) + k * math.cos(theta0));
      final cp1xU = rx * (math.cos(theta1) + k * math.sin(theta1));
      final cp1yU = ry * (math.sin(theta1) - k * math.cos(theta1));

      final cp0x = cx + cp0xU * cosPhi - cp0yU * sinPhi;
      final cp0y = cy + cp0xU * sinPhi + cp0yU * cosPhi;
      final cp1x = cx + cp1xU * cosPhi - cp1yU * sinPhi;
      final cp1y = cy + cp1xU * sinPhi + cp1yU * cosPhi;

      path.cubicTo(cp0x, cp0y, cp1x, cp1y, p1x, p1y);
    }
  }

  void _closePath(ui.Path path) {
    if (_started) {
      path.close();
      _lastX = _subpathStartX;
      _lastY = _subpathStartY;
      _lastControlX = _lastX;
      _lastControlY = _lastY;
    }
  }

  /// Parse SVG path data and return a cached [ui.Path] scaled to the given size.
  ///
  /// The input paths are assumed to be in a 512x512 viewBox.
  /// The returned path is scaled to fit within [size] using [Matrix4.diagonal3Values].
  static ui.Path parseAndScale(String data, ui.Size size) {
    final parser = SvgPathParser(data);
    final path = parser.parse();

    final scaleX = size.width / 512.0;
    final scaleY = size.height / 512.0;

    final transform = Float64List(16)
      ..[0] = scaleX
      ..[5] = scaleY
      ..[10] = 1.0
      ..[15] = 1.0;

    return path.transform(transform);
  }
}

/// Extension to cache parsed paths for performance.
extension SvgPathParserCache on String {
  /// Parses this SVG path string and caches the result.
  ui.Path toPath(ui.Size size, {Map<String, ui.Path>? cache}) {
    final key = '$this:${size.width}x${size.height}';
    if (cache != null && cache.containsKey(key)) {
      return cache[key]!;
    }
    final path = SvgPathParser.parseAndScale(this, size);
    cache?[key] = path;
    return path;
  }
}
