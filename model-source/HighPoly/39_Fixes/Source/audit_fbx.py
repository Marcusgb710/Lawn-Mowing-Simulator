"""Independent FBX roundtrip of the delivered June, not the authoring scene."""
import bpy,json
from pathlib import Path
from mathutils import Matrix
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;CI=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
name='NPC_June_Sitting';row=json.loads((OUT/'model_manifest.json').read_text())['assets'][0]
bpy.ops.import_scene.fbx(filepath=str(OUT/'Models'/name/(name+'.fbx')),use_anim=False,use_image_search=False)
bpy.context.view_layer.update();meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];points=[];triangles=0
for obj in meshes:
    obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles);points.extend(CI@(obj.matrix_world@v.co)/.28 for v in obj.data.vertices)
lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
error=max(abs(value-row[key][i]) for key,values in [('bounds_min_studs',lo),('bounds_max_studs',hi)] for i,value in enumerate(values))
assert triangles==row['triangles'] and len(meshes)==2 and error<.002
assert {o.name for o in meshes}=={name+'__Body',name+'__Head'}
textures=[]
for image in bpy.data.images:
    if not image.name.startswith('HP37_'):continue
    path=Path(bpy.path.abspath(image.filepath));assert path.is_file(),str(path)
    textures.append(dict(name=image.name,file=path.name))
assert any('Color' in t['name'] for t in textures)
report=dict(status='passed',name=name,triangles=triangles,mesh_objects=len(meshes),bounds_error_studs=error,referenced_texture_files_resolve=True,textures=textures)
(HERE/'fbx_review.json').write_text(json.dumps(report,indent=2)+'\n');print('PASS: FBX reimport',triangles,'triangles,',len(meshes),'meshes, bounds error',error,'studs.')
