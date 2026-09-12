import 'dart:math' as math;

class Point2 {
  const Point2(this.x, this.y);
  final double x;
  final double y;
  Point2 operator +(Point2 other) => Point2(x + other.x, y + other.y);
  Point2 operator -(Point2 other) => Point2(x - other.x, y - other.y);
  Point2 operator *(double scalar) => Point2(x * scalar, y * scalar);
  double dot(Point2 other) => x * other.x + y * other.y;
  double cross(Point2 other) => x * other.y - y * other.x;
  double get length => math.sqrt(x * x + y * y);
  double distanceTo(Point2 other) => (this - other).length;
  Point2 normalized() { final len = length; return len == 0 ? const Point2(0, 0) : Point2(x / len, y / len); }
  @override String toString() => 'Point2($x, $y)';
}

class Point3 {
  const Point3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
  Point3 operator +(Point3 other) => Point3(x + other.x, y + other.y, z + other.z);
  Point3 operator -(Point3 other) => Point3(x - other.x, y - other.y, z - other.z);
  Point3 operator *(double scalar) => Point3(x * scalar, y * scalar, z * scalar);
  double dot(Point3 other) => x * other.x + y * other.y + z * other.z;
  Point3 cross(Point3 other) => Point3(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  Point3 normalized() { final len = length; return len == 0 ? const Point3(0, 0, 0) : Point3(x / len, y / len, z / len); }
  @override String toString() => 'Point3($x, $y, $z)';
}
