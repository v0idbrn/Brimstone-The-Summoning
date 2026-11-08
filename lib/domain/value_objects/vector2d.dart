import 'dart:math';

class Vector2D {
  final double x, y;
  Vector2D(this.x, this.y);
  double distanceTo(Vector2D other) =>
      sqrt((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y));
}
