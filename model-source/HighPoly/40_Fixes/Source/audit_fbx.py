"""Independent FBX roundtrip of all five delivered models."""
import bpy,json,sys
import numpy as np
from pathlib import Path
from mathutils import Matrix
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;CI=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
sys.dont_write_bytecode=True
sys.path.insert(0,str(HERE))
from gltf_tools import Model
def property_matches(actual,expected):
    if isinstance(expected,list):return actual is not None and list(actual)==expected
    return actual==expected
reports=[]
for row in json.loads((OUT/'model_manifest.json').read_text())['assets']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.data.orphans_purge(do_recursive=True)
    name=row['name'];bpy.ops.import_scene.fbx(filepath=str(OUT/'Models'/name/(name+'.fbx')),use_anim=False,use_image_search=False)
    bpy.context.view_layer.update();meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];points=[];triangles=0
    for obj in meshes:
        obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles);points.extend(CI@(obj.matrix_world@v.co)/.28 for v in obj.data.vertices)
    lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
    error=max(abs(value-row[key][i]) for key,values in [('bounds_min_studs',lo),('bounds_max_studs',hi)] for i,value in enumerate(values))
    assert triangles==row['triangles'] and len(meshes)==row['mesh_objects'] and error<.002,(name,triangles,len(meshes),error)
    assert {o.name for o in meshes}=={p['name'] for p in row['parts']}
    textures=[]
    for image in bpy.data.images:
        if not image.name.startswith('HP'):continue
        path=Path(bpy.path.abspath(image.filepath)).resolve();assert path.is_file(),str(path)
        assert (OUT/'Textures').resolve() in path.parents,('texture outside standalone pack',str(path))
        textures.append(dict(name=image.name,file=path.name))
    assert any('Color' in t['name'] for t in textures)
    source=Model(OUT/'Models'/name/(name+'.gltf'));marker_errors=[];orientation_errors=[];pivot_errors=[]
    conversion=np.array(CI);inverse_conversion=conversion.T
    for node in source.doc['nodes']:
        if 'mesh' not in node:continue
        obj=bpy.data.objects[node['name']];expected=source.worlds[source.node(node['name'])]
        pivot_error=np.linalg.norm(conversion@np.array(obj.matrix_world.translation)/.28-expected[:3,3]/.28)
        rotation_error=np.max(np.abs(conversion@np.array(obj.matrix_world.to_3x3())@inverse_conversion-expected[:3,:3]))
        assert pivot_error<.002 and rotation_error<.0001,(name,node['name'],'mesh pivot',pivot_error,rotation_error)
        pivot_errors.append(float(pivot_error))
    # Repeated attachment names are represented by their roblox_name and
    # attributes, rather than Blender's auto-generated numeric name suffixes.
    for i,node in enumerate(source.doc['nodes']):
        if 'mesh' in node:continue
        props=node.get('extras',{})
        candidates=[obj for obj in bpy.context.scene.objects if obj.type=='EMPTY' and all(property_matches(obj.get(k),v) for k,v in props.items())] if props else [obj for obj in bpy.context.scene.objects if obj.name==node['name']]
        assert candidates,(name,node['name'],'missing marker/properties')
        position=source.worlds[i][:3,3]/.28
        matched=min(candidates,key=lambda obj:np.linalg.norm(conversion@np.array(obj.matrix_world.translation)/.28-position))
        delta=float(np.linalg.norm(conversion@np.array(matched.matrix_world.translation)/.28-position))
        assert delta<.002,(name,node['name'],'marker position',delta)
        rotation_error=float(np.max(np.abs(conversion@np.array(matched.matrix_world.to_3x3())@inverse_conversion-source.worlds[i][:3,:3])))
        assert rotation_error<.0001,(name,node['name'],'marker orientation',rotation_error)
        marker_errors.append(delta)
        orientation_errors.append(rotation_error)
    reports.append(dict(status='passed',name=name,triangles=triangles,mesh_objects=len(meshes),bounds_error_studs=error,mesh_pivot_max_error_studs=max(pivot_errors,default=0),marker_position_max_error_studs=max(marker_errors,default=0),marker_orientation_max_matrix_error=max(orientation_errors,default=0),marker_attributes_preserved=True,referenced_texture_files_resolve_within_pack=True,textures=textures))
    print('PASS: FBX reimport',name,triangles,'triangles,',len(meshes),'meshes, bounds error',error,'studs.',flush=True)
(HERE/'fbx_review.json').write_text(json.dumps(dict(status='passed',assets=reports),indent=2)+'\n')
