"""Check the actual native surfaces against the unchanged rocker, in studs."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;BASE=OUT.parent/'37_Story'
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)));CI=C.inverted();S=.28
bpy.ops.wm.open_mainfile(filepath=str(HERE/'June_Seated.blend'))
def surface(obj):
    obj.data.calc_loop_triangles()
    points=[CI@(obj.matrix_world@v.co)/S for v in obj.data.vertices]
    tris=[tuple(t.vertices) for t in obj.data.loop_triangles]
    return points,tris,BVHTree.FromPolygons(points,tris,all_triangles=True)
body=bpy.data.objects['NPC_June_Sitting__Body'];head=bpy.data.objects['NPC_June_Sitting__Head'];chair=bpy.data.objects['PorchRockingChair__Body']
surfaces={o.name:surface(o) for o in [body,head,chair]}
hits=[];tolerance=.0001
for source,target in [(body,chair),(head,chair),(chair,body),(chair,head)]:
    pts,tris,tree=surfaces[source.name];other=surfaces[target.name][2]
    for edge in source.data.edges:
        a,b=[pts[i] for i in edge.vertices];delta=b-a;length=delta.length
        if length<2*tolerance:continue
        p,n,index,distance=other.ray_cast(a+delta.normalized()*tolerance,delta.normalized(),length-2*tolerance)
        if p is not None:hits.append(dict(source=source.name,target=target.name,edge=edge.index,point_studs=list(p),source_face=index))
points=surfaces[body.name][0]+surfaces[head.name][0];lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
# Native vertex and UV identity is a stronger appearance guard than a screenshot.
mesh_name=head.data.name
with bpy.data.libraries.load(str(BASE/'Source/Story.blend'),link=False) as (available,requested):requested.meshes=[mesh_name]
original=requested.meshes[0];assert len(original.vertices)==len(head.data.vertices)
assert all(a.co==b.co for a,b in zip(original.vertices,head.data.vertices))
assert [tuple(p.vertices) for p in original.polygons]==[tuple(p.vertices) for p in head.data.polygons]
assert all(a.uv==b.uv for a,b in zip(original.uv_layers.active.data,head.data.uv_layers.active.data))
original_body=None
with bpy.data.libraries.load(str(BASE/'Source/Story.blend'),link=False) as (available,requested):requested.meshes=[body.data.name]
original_body=requested.meshes[0]
assert [tuple(p.vertices) for p in original_body.polygons]==[tuple(p.vertices) for p in body.data.polygons]
assert all(a.uv==b.uv for a,b in zip(original_body.uv_layers.active.data,body.data.uv_layers.active.data))
assert -.0001<=lo[1]<=.0001
report=dict(status='passed' if not hits else 'needs_clearance_adjustment',bounds_min_studs=lo,bounds_max_studs=hi,head_vertices_faces_and_uvs_identical=True,body_topology_and_uvs_identical=True,chair_edge_crossings=len(hits),edge_crossing_tolerance_studs=tolerance,crossings=hits)
(HERE/'clearance_review.json').write_text(json.dumps(report,indent=2)+'\n')
print('CHAIR SURFACE CROSSINGS',len(hits),'BOUNDS',lo,hi,flush=True)
for hit in hits[:25]:print(hit,flush=True)
if '--report-only' not in sys.argv:assert not hits,('June intersects the rocker',len(hits))
