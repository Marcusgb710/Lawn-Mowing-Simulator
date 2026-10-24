import bpy,json,sys
from pathlib import Path
from mathutils import Vector,Matrix
W=Path(__file__).resolve().parent;R=W.parents[3];C=Matrix(((1,0,0),(0,0,-1),(0,1,0)));CI=C.inverted();selected=set(sys.argv[sys.argv.index('--only')+1].split(',')) if '--only' in sys.argv else None;prior=json.loads((W/'fbx_review.json').read_text())['assets'] if selected else [];reports=[r for r in prior if r['name'] not in selected] if selected else [];issues=[]
for file in [W.parent/'model_manifest.json']:
 for row in json.loads(file.read_text())['assets']:
  if selected is not None and row['name'] not in selected:continue
  bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.outliner.orphans_purge(do_recursive=True)
  path=file.parent/'Models'/row['name']/(row['name']+'.fbx');bpy.ops.import_scene.fbx(filepath=str(path),use_anim=False);bpy.context.view_layer.update();meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];points=[];count=0
  for obj in meshes:
   obj.data.calc_loop_triangles();count+=len(obj.data.loop_triangles);points.extend([CI@(obj.matrix_world@v.co)/.28 for v in obj.data.vertices])
  lo=[min(v[i] for v in points) for i in range(3)];hi=[max(v[i] for v in points) for i in range(3)];delta=max(abs(lo[i]-row['bounds_min_studs'][i]) for i in range(3));delta=max(delta,max(abs(hi[i]-row['bounds_max_studs'][i]) for i in range(3)))
  ok=count==row['triangles'] and len(meshes)==row['mesh_objects'] and delta<.002
  report=dict(name=row['name'],triangles=count,mesh_objects=len(meshes),bounds_error_studs=delta,passed=ok);reports.append(report)
  if not ok:issues.append(report)
  print('FBX ROUNDTRIP',row['name'],ok,count,len(meshes),delta,flush=True)
(W/'fbx_review.json').write_text(json.dumps(dict(assets=reports,issues=issues),indent=2));print('FBX ROUNDTRIP TOTAL',len(reports),len(issues),'issues',flush=True)
if issues:raise RuntimeError('FBX roundtrip failed')
