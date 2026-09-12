import 'dart:math' as math;
import '../geometry/point.dart';
import '../geometry/polygon.dart';
import '../model_io/mesh.dart';

class SliceSegment { const SliceSegment(this.a,this.b); final Point2 a; final Point2 b; double get length=>a.distanceTo(b); }
class SliceLayer { const SliceLayer({required this.z,required this.contours,required this.openPaths,required this.segmentCount}); final double z; final List<Polygon2> contours; final List<List<Point2>> openPaths; final int segmentCount; }
class MeshSliceResult { const MeshSliceResult({required this.layers}); final List<SliceLayer> layers; bool get isEmpty=>layers.isEmpty; int get contourCount=>layers.fold(0,(s,l)=>s+l.contours.length); int get openPathCount=>layers.fold(0,(s,l)=>s+l.openPaths.length); }

class MeshSlicer {
  const MeshSlicer({this.epsilon=1e-5}); final double epsilon;
  MeshSliceResult slice(Mesh mesh,{double layerHeight=0.2,double? firstLayerHeight}){
    if(layerHeight<=0) throw ArgumentError.value(layerHeight,'layerHeight','must be > 0');
    final bounds=mesh.bounds; if(bounds.isEmpty||mesh.triangles.isEmpty) return const MeshSliceResult(layers:[]);
    final first=firstLayerHeight??layerHeight; if(first<=0) throw ArgumentError.value(first,'firstLayerHeight','must be > 0');
    final layers=<SliceLayer>[]; var z=bounds.min.z+first; if(z>=bounds.max.z-epsilon) z=(bounds.min.z+bounds.max.z)/2; var guard=0;
    while(z<bounds.max.z-epsilon && guard++<1000000){ layers.add(_sliceAt(mesh,z)); z+=layerHeight; }
    return MeshSliceResult(layers:List.unmodifiable(layers));
  }
  SliceLayer _sliceAt(Mesh mesh,double z){ final segments=<SliceSegment>[]; final seen=<String>{}; for(final triangle in mesh.triangles){ final segment=_intersectTriangle(triangle,z); if(segment==null||segment.length<=epsilon) continue; if(seen.add(_undirectedSegmentKey(segment))) segments.add(segment);} final stitched=_stitch(segments); return SliceLayer(z:z,contours:List.unmodifiable(stitched.contours),openPaths:List.unmodifiable(stitched.openPaths.map(List<Point2>.unmodifiable)),segmentCount:segments.length); }
  SliceSegment? _intersectTriangle(Triangle triangle,double z){ final vertices=[triangle.a,triangle.b,triangle.c]; final points=<Point2>[]; void addUnique(Point2 p){ if(points.every((q)=>q.distanceTo(p)>epsilon)) points.add(p); }
    for(var i=0;i<3;i++){ final a=vertices[i], b=vertices[(i+1)%3]; final da=a.z-z, db=b.z-z; final aOn=da.abs()<=epsilon,bOn=db.abs()<=epsilon; if(aOn&&bOn) continue; if(aOn){addUnique(Point2(a.x,a.y));continue;} if(bOn){addUnique(Point2(b.x,b.y));continue;} if((da<0&&db>0)||(da>0&&db<0)){ final t=(z-a.z)/(b.z-a.z); addUnique(Point2(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t)); }}
    if(points.length<2) return null; if(points.length==2) return SliceSegment(points[0],points[1]); var bestA=points[0],bestB=points[1],bestDistance=bestA.distanceTo(bestB); for(var i=0;i<points.length;i++){ for(var j=i+1;j<points.length;j++){ final d=points[i].distanceTo(points[j]); if(d>bestDistance){bestDistance=d;bestA=points[i];bestB=points[j];}}} return bestDistance<=epsilon?null:SliceSegment(bestA,bestB); }
  _StitchedPaths _stitch(List<SliceSegment> segments){ if(segments.isEmpty) return const _StitchedPaths([],[]); final adjacency=<String,List<int>>{}; for(var i=0;i<segments.length;i++){ adjacency.putIfAbsent(_pointKey(segments[i].a),()=>[]).add(i); adjacency.putIfAbsent(_pointKey(segments[i].b),()=>[]).add(i);} final used=List<bool>.filled(segments.length,false); final contours=<Polygon2>[]; final openPaths=<List<Point2>>[]; for(final entry in adjacency.entries){ final unusedDegree=entry.value.where((i)=>!used[i]).length; if(unusedDegree!=1) continue; final startIndex=entry.value.firstWhere((i)=>!used[i]); final segment=segments[startIndex]; final start=_pointKey(segment.a)==entry.key?segment.a:segment.b; _classify(_walk(start,startIndex,segments,adjacency,used),contours,openPaths);} for(var i=0;i<segments.length;i++){ if(used[i]) continue; _classify(_walk(segments[i].a,i,segments,adjacency,used),contours,openPaths);} return _StitchedPaths(contours,openPaths); }
  List<Point2> _walk(Point2 start,int initialSegment,List<SliceSegment> segments,Map<String,List<int>> adjacency,List<bool> used){ final path=<Point2>[start]; var current=start; var nextSegmentIndex=initialSegment; for(var guard=0;guard<segments.length+2;guard++){ if(used[nextSegmentIndex]) break; used[nextSegmentIndex]=true; final segment=segments[nextSegmentIndex]; final next=current.distanceTo(segment.a)<=current.distanceTo(segment.b)?segment.b:segment.a; path.add(next); current=next; if(current.distanceTo(start)<=epsilon&&path.length>=4) break; final candidates=adjacency[_pointKey(current)]??const <int>[]; int? candidate; var bestDistance=double.infinity; for(final index in candidates){ if(used[index]) continue; final cs=segments[index]; final d=math.min(current.distanceTo(cs.a),current.distanceTo(cs.b)); if(d<bestDistance){bestDistance=d;candidate=index;}} if(candidate==null) break; nextSegmentIndex=candidate;} return path; }
  void _classify(List<Point2> path,List<Polygon2> contours,List<List<Point2>> openPaths){ if(path.length<2) return; final isClosed=path.length>=4&&path.first.distanceTo(path.last)<=epsilon; if(!isClosed){openPaths.add(path);return;} final points=path.sublist(0,path.length-1); if(points.length<3){openPaths.add(path);return;} final polygon=Polygon2(points); if(polygon.area<=epsilon*epsilon){openPaths.add(path);return;} contours.add(polygon); }
  String _pointKey(Point2 p){ final scale=1/epsilon; return '${(p.x*scale).round()}:${(p.y*scale).round()}'; }
  String _undirectedSegmentKey(SliceSegment segment){ final a=_pointKey(segment.a),b=_pointKey(segment.b); return a.compareTo(b)<=0?'$a|$b':'$b|$a'; }
}
class _StitchedPaths { const _StitchedPaths(this.contours,this.openPaths); final List<Polygon2> contours; final List<List<Point2>> openPaths; }
