import 'point.dart';

class BoundingBox2 {
  BoundingBox2.empty() : min = const Point2(double.infinity, double.infinity), max = const Point2(double.negativeInfinity, double.negativeInfinity);
  BoundingBox2(this.min, this.max);
  Point2 min;
  Point2 max;
  bool get isEmpty => min.x > max.x || min.y > max.y;
  double get width => isEmpty ? 0 : max.x - min.x;
  double get height => isEmpty ? 0 : max.y - min.y;
  Point2 get center => isEmpty ? const Point2(0, 0) : Point2((min.x + max.x) / 2, (min.y + max.y) / 2);
  void include(Point2 p) { min = Point2(p.x < min.x ? p.x : min.x, p.y < min.y ? p.y : min.y); max = Point2(p.x > max.x ? p.x : max.x, p.y > max.y ? p.y : max.y); }
}

class BoundingBox3 {
  BoundingBox3.empty() : min = const Point3(double.infinity, double.infinity, double.infinity), max = const Point3(double.negativeInfinity, double.negativeInfinity, double.negativeInfinity);
  BoundingBox3(this.min, this.max);
  Point3 min;
  Point3 max;
  bool get isEmpty => min.x > max.x || min.y > max.y || min.z > max.z;
  double get width => isEmpty ? 0 : max.x - min.x;
  double get depth => isEmpty ? 0 : max.y - min.y;
  double get height => isEmpty ? 0 : max.z - min.z;
  Point3 get center => isEmpty ? const Point3(0,0,0) : Point3((min.x + max.x)/2, (min.y + max.y)/2, (min.z + max.z)/2);
  void include(Point3 p) { min = Point3(p.x < min.x ? p.x : min.x, p.y < min.y ? p.y : min.y, p.z < min.z ? p.z : min.z); max = Point3(p.x > max.x ? p.x : max.x, p.y > max.y ? p.y : max.y, p.z > max.z ? p.z : max.z); }
}
