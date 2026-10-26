"""Re-pose the original June mesh, preserving topology, UVs and the entire head.

Blender 4.3.2: blender -b -t 4 --python-exit-code 1 --python Source/repose.py
Only 39_Fixes is written. The rocker and porch are unchanged preview references.
"""
import bpy,sys,json,math,hashlib,shutil,copy
sys.dont_write_bytecode=True
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

HERE=Path(__file__).resolve().parent;OUT=HERE.parent;REPO=OUT.parents[2]
BASE=OUT.parent/'37_Story';sys.path.insert(0,str(BASE/'Source'))
import build37
from core import C,CI,S,Asset
NAME='NPC_June_Sitting'
for folder in ['Models/'+NAME,'ALL','Textures','Previews']: (OUT/folder).mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'Source/Story.blend'))
source_manifest=json.loads((BASE/'model_manifest.json').read_text())
source_row=next(r for r in source_manifest['assets'] if r['name']==NAME)
root=bpy.data.objects[NAME];body=bpy.data.objects[NAME+'__Body'];head=bpy.data.objects[NAME+'__Head']
root.location=(0,0,0);root.scale=(1,1,1)
raw=build37.character(NAME).parts[NAME+'__Body']
features=raw.feature_components

def components(mesh):
    parent=list(range(len(mesh.vertices)))
    def find(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for edge in mesh.edges:
        a,b=map(find,edge.vertices);parent[a]=b
    groups={}
    for v in mesh.vertices:groups.setdefault(find(v.index),[]).append(v.index)
    return list(groups.values())

def stud_point(obj,v):return CI@v.co/S+Vector(obj.get('stud_origin',[0,0,0]))
def bounds(points):return [min(p[j] for p in points) for j in range(3)],[max(p[j] for p in points) for j in range(3)]
def clamp(x):return max(0,min(1,x))
def lean(p):
    q=p.copy();q.z+=-.06+.26*clamp((p.y-1.90)/1.05);return q
def lean_normal(p,n):
    k=.26/1.05 if 1.9<p.y<2.95 else 0
    return Vector((n.x,n.y-k*n.z,n.z)).normalized()

# Match the native mesh's disconnected authored surfaces to the original source
# components. No remeshing, global fitting, decimation or UV edits are performed.
feature_bounds=[]
for f in features:
    lo,hi=bounds(raw.verts[f['vertices'][0]:f['vertices'][1]])
    feature_bounds.append((lo,hi))
groups=components(body.data);assert len(groups)==len(features)==53
matched={}
for indices in groups:
    lo,hi=bounds([stud_point(body,body.data.vertices[i]) for i in indices])
    k=min(range(len(features)),key=lambda k:sum((lo[j]-feature_bounds[k][0][j])**2+(hi[j]-feature_bounds[k][1][j])**2 for j in range(3)))
    assert k not in matched,('Ambiguous original mesh component',k)
    matched[k]=indices
assert set(matched)==set(range(53))

def new_limb(points,radii,n=24):
    temporary=Asset(NAME);build37.limb(temporary,'Pose correspondence',points,radii,'khaki',n)
    return temporary.parts[NAME+'__Body'].verts

target={};translations={};normal_rotations={};changes=[];fold_to_leg={}
for side,sole,shoe,leg,folds in [(-1,0,1,2,[3,4,5]),(1,6,7,8,[9,10,11])]:
    translations[sole]=translations[shoe]=Vector((0,0,.80))
    x=side*.31
    target[leg]=new_limb([(x,.30,-1.10),(x,2.05,-1.05),(side*.30,2.12,.20)],[.16,.22,.27])
    for k in folds:fold_to_leg[k]=leg

# Preserve the original hands/mug as rigid surfaces. Rest the right fingers just
# above the armrest and move the mug hand inwards to fit the requested envelope.
left_delta=Vector((.10,-.05,.05));right_delta=Vector((0,.12,.04))
for k in list(range(24,34))+[50,51,52]:translations[k]=left_delta
for k in range(38,48):translations[k]=right_delta
for side,p,delta,sleeve,forearm,folds in [(-1,Vector((-1.10,2.65,-.65)),left_delta,22,23,[34,35]),(1,Vector((1.0,2.48,-.88)),right_delta,36,37,[48,49])]:
    shoulder=Vector((side*.51,2.84,.26));elbow=Vector((side*.68,(3.0+p.y)/2-.16,p.z*.35));end=shoulder.lerp(elbow,1).lerp(p,.78)
    new_shoulder=lean(shoulder);new_p=p+delta;new_elbow=elbow+delta*.48+Vector((0,0,.05));new_end=new_elbow.lerp(new_p,.78)
    target[sleeve]=new_limb([new_shoulder,new_elbow,new_end],[.22,.17,.145],20)
    target[forearm]=new_limb([new_end,new_end.lerp(new_p,.7),new_p],[.14,.115,.10],16)
    for k in folds:translations[k]=new_elbow-elbow

old_coordinates=[v.co.copy() for v in body.data.vertices]
old_normals=[n.vector.copy() for n in body.data.corner_normals]
rotations=[Matrix.Identity(3) for _ in body.data.vertices]
body_origin=Vector(body.get('stud_origin',[0,0,0]))
for k,indices in sorted(matched.items()):
    label=features[k]['name'];first,last=features[k]['vertices'];before=[stud_point(body,body.data.vertices[i]) for i in indices]
    if k in target or k in fold_to_leg:
        mapping=fold_to_leg.get(k,k);map_first,map_last=features[mapping]['vertices']
        old=raw.verts[map_first:map_last];new=target[mapping];assert len(old)==len(new),(k,label,len(old),len(new))
        faces=[tuple(i-map_first for i in face) for face in raw.faces if map_first<=face[0]<map_last]
        triangles=[]
        for face in faces:
            for j in range(1,len(face)-1):
                tri=(face[0],face[j],face[j+1])
                if (old[tri[1]]-old[tri[0]]).cross(old[tri[2]]-old[tri[0]]).length>1e-9:triangles.append(tri)
        tree=BVHTree.FromPolygons(old,triangles,all_triangles=True)
        for i,p in zip(indices,before):
            near,n,face,distance=tree.find_nearest(p);tri=triangles[face];a,b,c=[old[t] for t in tri];u,v,w=[new[t] for t in tri]
            old_n=(b-a).cross(c-a).normalized();new_n=(v-u).cross(w-u).normalized()
            old_u=(b-a).normalized();new_u=(v-u).normalized()
            old_basis=Matrix((old_u,old_n.cross(old_u),old_n)).transposed();new_basis=Matrix((new_u,new_n.cross(new_u),new_n)).transposed()
            rot=new_basis@old_basis.transposed();q=barycentric_transform(near,a,b,c,u,v,w)+rot@(p-near)
            if mapping in [2,8]:
                # The cushion's front rail projects beyond its upholstery.
                # Keep the knees at the requested height, and bring only the
                # lower trouser legs clear of that rail towards the clogs.
                if q.y<=1.75:
                    clearance=.10+.06*clamp((q.y-.30)/1.20)
                    derivative=.05 if .30<q.y<1.50 else 0
                elif q.y<2.05:
                    clearance=.16*(2.05-q.y)/.30;derivative=-.16/.30
                else:clearance=derivative=0
                q.z-=clearance
                shear=Matrix(((1,0,0),(0,1,0),(0,-derivative,1)))
                normal_rotations[i]=shear.inverted().transposed()
            body.data.vertices[i].co=C@(q-body_origin)*S;rotations[i]=C@rot@CI
            if i in normal_rotations:rotations[i]=C@normal_rotations[i]@CI@rotations[i]
    elif k in translations:
        for i,p in zip(indices,before):body.data.vertices[i].co=C@(p+translations[k]-body_origin)*S
    elif k in [12,14,15,16,17,18,19,20,21]:
        for i,p in zip(indices,before):
            q=lean(p)
            if k==14 and p.y<2.10:q.y=1.85+(p.y-1.749)/(2.10-1.749)*.25
            body.data.vertices[i].co=C@(q-body_origin)*S
            shear=Matrix(((1,0,0),(0,1,0),(0,.26/1.05 if 1.9<p.y<2.95 else 0,1)))
            rotations[i]=C@shear.inverted().transposed()@CI
    elif k==13:
        for i,p in zip(indices,before):
            q=p.copy();q.z+=.15*clamp((3.174-p.y)/.728);body.data.vertices[i].co=C@(q-body_origin)*S
            shear=Matrix(((1,0,0),(0,1,0),(0,-.15/.728 if 2.446<p.y<3.174 else 0,1)))
            rotations[i]=C@shear.inverted().transposed()@CI
    after=[stud_point(body,body.data.vertices[i]) for i in indices]
    changes.append(dict(component=k,label=label,vertices=len(indices),before_bounds_studs=bounds(before),after_bounds_studs=bounds(after),changed=any((a-b).length>1e-7 for a,b in zip(before,after))))
body.data.update()
body.data.normals_split_custom_set([(rotations[loop.vertex_index]@old_normals[loop.index]).normalized() for loop in body.data.loops])

# Save a small native scene containing the fixed June plus unchanged reference
# geometry. Selection for exchange export always excludes those references.
keep_names=[NAME,'PorchRockingChair','PorchDeck']
keep=set()
for name in keep_names:
    col=bpy.data.collections[name];col.hide_render=False;keep.update(col.objects)
    bpy.data.objects[name].location=(0,0,0)
for obj in list(bpy.data.objects):
    if obj not in keep:bpy.data.objects.remove(obj,do_unlink=True)
for name in ['PorchRockingChair','PorchDeck']:bpy.data.objects[name]['preview_reference_only']=True

def file_hash(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for path in (BASE/'Textures').glob('*.png'):shutil.copyfile(path,OUT/'Textures'/path.name)
for image in bpy.data.images:
    if image.name.startswith('HP37_'):image.filepath=str(OUT/'Textures'/(image.name+'.png'))
def copy_textures():
    for path in (BASE/'Textures').glob('*.png'):shutil.copyfile(path,OUT/'Textures'/path.name)
def select_june():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.collections[NAME].objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=root
root['instruction']=39;root['folder']='Story';root['primary_part']='Root';root['primary_position_studs']=[0,.5,0]
root.location=(0,0,0);root.rotation_euler=(0,0,0);root.scale=(1,1,1)
select_june();dest=OUT/'Models'/NAME
bpy.ops.export_scene.gltf(filepath=str(dest/(NAME+'.gltf')),export_format='GLTF_SEPARATE',use_selection=True,export_texture_dir='../../Textures',export_yup=True,export_cameras=False,export_lights=False,export_extras=True)
bpy.ops.export_scene.fbx(filepath=str(dest/(NAME+'.fbx')),use_selection=True,object_types={'MESH','EMPTY'},apply_unit_scale=True,add_leaf_bones=False,bake_anim=False,axis_forward='-Z',axis_up='Y',path_mode='RELATIVE',use_custom_props=True)
select_june()
bpy.ops.export_scene.gltf(filepath=str(OUT/'ALL/39_Fixes.gltf'),export_format='GLTF_SEPARATE',use_selection=True,export_texture_dir='../Textures',export_yup=True,export_cameras=False,export_lights=False,export_extras=True)
for path in [dest/(NAME+'.gltf'),OUT/'ALL/39_Fixes.gltf']:
    doc=json.loads(path.read_text())
    for node in doc['nodes']:
        if node.get('extras',{}).get('roblox_class')=='Attachment':node['name']=node['extras']['roblox_name']
    path.write_text(json.dumps(doc,indent=2)+'\n')
sys.path.insert(0,str(HERE))
from preserve_head import main as preserve_head
preserve_head()
copy_textures()
points=[stud_point(obj,v) for obj in [body,head] for v in obj.data.vertices];lo,hi=bounds(points)
row=copy.deepcopy(source_row);row.update(instruction=39,dimensions_studs=[hi[i]-lo[i] for i in range(3)],bounds_min_studs=lo,bounds_max_studs=hi,baseline_source_pack='37_Story',baseline_triangles=source_row['triangles'],library_translation_meters=[0,0,0],authoring_fit=dict(scale=[1,1,1],offset=[0,0,0],authored_at_nominal_size=True))
row['features'].update(seated_pose_fix=39,feet_centres_studs=[[-.31,.065,-1.20],[.31,.065,-1.20]],knee_centres_studs=[[-.31,2.05,-1.05],[.31,2.05,-1.05]],hip_centres_studs=[[-.30,2.12,.20],[.30,2.12,.20]],head_mesh_preserved=True,original_topology_and_uvs_preserved=True)
(OUT/'model_manifest.json').write_text(json.dumps(dict(assets=[row],meters_per_stud=.28,source_main_commit='8e9d26a',original_packs_preserved=True,studio_import_tested=False),indent=2)+'\n')
report=dict(source_scene='model-source/HighPoly/37_Story/Source/Story.blend',source_scene_sha256=file_hash(BASE/'Source/Story.blend'),head_geometry_edited=False,body_topology_edited=False,uvs_edited=False,body_components=changes,texture_hashes={p.name:file_hash(p) for p in (OUT/'Textures').glob('*.png')},reference_models_not_exported=['PorchRockingChair','PorchDeck'])
(HERE/'pose_changes.json').write_text(json.dumps(report,indent=2)+'\n')
for image in bpy.data.images:
    if image.name.startswith('HP37_'):
        if not image.packed_file:image.pack()
        image.filepath='//../Textures/'+image.name+'.png'
bpy.context.scene['delivery_folder']='model-source/HighPoly/39_Fixes';bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'June_Seated.blend'),compress=True)
print('POSE EXPORTED',row['dimensions_studs'],row['bounds_min_studs'],row['bounds_max_studs'],flush=True)
