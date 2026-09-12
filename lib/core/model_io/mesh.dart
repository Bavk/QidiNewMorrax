import 'dart:math' as math;
import '../geometry/bounding_box.dart';
import '../geometry/point.dart';

class Triangle {
  const Triangle(this.a,this.b,this.c);
  final Point3 a; final Point3 b; final Point3 c;
  Point3 get normal => (b-a).cross(c-a).normalized();
}

class Mesh {
  Mesh({required this.triangles,this.name='Model'});
  final List<Triangle> triangles; final String name;
  BoundingBox3 get bounds { final box=BoundingBox3.empty(); for(final t in triangles){ box.include(t.a); box.include(t.b); box.include(t.c);} return box; }
  Mesh transformed({Point3 translation=const Point3(0,0,0), Point3 scale=const Point3(1,1,1), Point3 rotationDegrees=const Point3(0,0,0)}) {
    final rx=rotationDegrees.x*math.pi/180, ry=rotationDegrees.y*math.pi/180, rz=rotationDegrees.z*math.pi/180;
    Point3 transformPoint(Point3 p){ var x=p.x*scale.x,y=p.y*scale.y,z=p.z*scale.z; final c1=math.cos(rx),s1=math.sin(rx); var ny=y*c1-z*s1,nz=y*s1+z*c1; y=ny;z=nz; final c2=math.cos(ry),s2=math.sin(ry); var nx=x*c2+z*s2; nz=-x*s2+z*c2; x=nx;z=nz; final c3=math.cos(rz),s3=math.sin(rz); nx=x*c3-y*s3; ny=x*s3+y*c3; x=nx;y=ny; return Point3(x+translation.x,y+translation.y,z+translation.z); }
    return Mesh(name:name,triangles:[for(final t in triangles) Triangle(transformPoint(t.a),transformPoint(t.b),transformPoint(t.c))]);
  }
}
