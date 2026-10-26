"""Validate the serialized pose fix, appearance preservation and delivery scope."""
from pathlib import Path
import json,hashlib,subprocess,sys,math
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;BASE=OUT.parent/'37_Story';REPO=OUT.parents[2]
NAME='NPC_June_Sitting';manifest=json.loads((OUT/'model_manifest.json').read_text());assert len(manifest['assets'])==4;row=next(r for r in manifest['assets'] if r['name']==NAME)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(path):
    doc=json.loads(path.read_text());buffers=[(path.parent/b['uri']).read_bytes() for b in doc['buffers']]
    types={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'};width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
    def array(i):
        a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];dtype=np.dtype(types[a['componentType']]);n=width[a['type']]
        return np.ndarray((a['count'],n),dtype,buffer=buffers[v['buffer']],offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',n*dtype.itemsize),dtype.itemsize)).copy()
    def transform(n):
        if 'matrix' in n:return np.array(n['matrix']).reshape(4,4).T
        x,y,z,w=n.get('rotation',[0,0,0,1]);m=np.eye(4);m[:3,:3]=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0]);return m
    worlds={};parents={}
    def walk(i,parent):
        worlds[i]=parent@transform(doc['nodes'][i])
        for child in doc['nodes'][i].get('children',[]):parents[child]=i;walk(child,worlds[i])
    for i in doc['scenes'][doc.get('scene',0)]['nodes']:walk(i,np.eye(4))
    return doc,array,worlds,parents
doc,array,worlds,parents=load(OUT/'Models'/NAME/(NAME+'.gltf'))
roots=doc['scenes'][0]['nodes'];assert len(roots)==1;root=doc['nodes'][roots[0]];assert root['name']==NAME
assert not any(k in root for k in ['rotation','scale','matrix']) and np.allclose(root.get('translation',[0,0,0]),0)
assert row['name']==NAME and row['folder']=='Story' and row['primary_part']=='Root' and row['primary_position_studs']==[0,.5,0]
points=[];triangles=0;parts={}
for i,node in enumerate(doc['nodes']):
    if 'mesh' not in node:continue
    count=0
    for p in doc['meshes'][node['mesh']]['primitives']:
        xyz=array(p['attributes']['POSITION']);normals=array(p['attributes']['NORMAL']);uv=array(p['attributes']['TEXCOORD_0']);ix=array(p['indices']).reshape(-1,3)
        assert p.get('mode',4)==4 and np.isfinite(xyz).all() and np.isfinite(uv).all() and np.allclose(np.linalg.norm(normals,axis=1),1,atol=.003)
        assert ix.min()>=0 and ix.max()<len(xyz)
        tris=xyz[ix];areas=np.linalg.norm(np.cross(tris[:,1]-tris[:,0],tris[:,2]-tris[:,0]),axis=1);assert (areas>1e-13).all()
        points.extend((np.c_[xyz,np.ones(len(xyz))]@worlds[i].T)[:,:3]/.28);count+=len(ix)
    assert count<=20000;parts[node['name']]=count;triangles+=count
assert parts=={NAME+'__Body':5704,NAME+'__Head':8348} and triangles==row['triangles']==14052
pts=np.array(points);lo=pts.min(axis=0);hi=pts.max(axis=0)
assert np.allclose(lo,row['bounds_min_studs'],atol=.00001) and np.allclose(hi,row['bounds_max_studs'],atol=.00001)
assert lo[0]>=-1.25 and hi[0]<=1.25 and lo[2]>=-1.6 and hi[2]<=.8 and abs(lo[1])<.00001 and 4.1<=hi[1]<=4.35
for m in row['markers']:
    i=next(i for i,n in enumerate(doc['nodes']) if n['name']==m['name']);assert doc['nodes'][parents[i]]['name']==m['parent_mesh'];assert np.allclose(worlds[i][:3,3]/.28,m['position_studs'],atol=.00001)
    assert np.allclose(m['look_vector'],[0,0,-1]);assert np.allclose(worlds[i][:3,:3]@np.array([0,0,-1]),[0,0,-1],atol=.00001)
assert {m['name'] for m in row['markers']}=={'Head','Talk'}
# Compare the real exported head attributes with the original export. Float
# tolerances cover exporter rounding; the native audit also requires exact data.
old,old_array,old_worlds,old_parents=load(BASE/'Models'/NAME/(NAME+'.gltf'))
new_head=next(n for n in doc['nodes'] if n['name']==NAME+'__Head');old_head=next(n for n in old['nodes'] if n['name']==NAME+'__Head')
new_prim=doc['meshes'][new_head['mesh']]['primitives'][0];old_prim=old['meshes'][old_head['mesh']]['primitives'][0]
head_deltas={}
for attr in ['POSITION','NORMAL','TEXCOORD_0']:
    a=array(new_prim['attributes'][attr]);b=old_array(old_prim['attributes'][attr]);assert a.shape==b.shape,(attr,a.shape,b.shape)
    delta=float(np.abs(a-b).max());assert delta<.00001,(attr,delta);head_deltas[attr]=delta
assert np.array_equal(array(new_prim['indices']),old_array(old_prim['indices']))
assert new_head.get('translation')==old_head.get('translation')
for p in (BASE/'Textures').glob('*.png'):
    assert sha(p)==sha(OUT/'Textures'/p.name),p.name
    with Image.open(OUT/'Textures'/p.name) as image:assert max(image.size)<=2048;image.verify()
for image in doc['images']:assert (OUT/'Models'/NAME/image['uri']).is_file()
all_doc,all_array,all_worlds,_=load(OUT/'ALL/39_Fixes.gltf');all_roots=all_doc['scenes'][0]['nodes'];assert len(all_roots)==4
assert {all_doc['nodes'][i]['name'] for i in all_roots}=={r['name'] for r in manifest['assets']}
for i in all_roots:
    node=all_doc['nodes'][i];entry=next(r for r in manifest['assets'] if r['name']==node['name'])
    assert not any(k in node for k in ['rotation','scale','matrix']) and np.allclose(node.get('translation',[0,0,0]),entry['library_translation_meters'])
    if node['name']==NAME:assert np.allclose(node['translation'],0)
clearance=json.loads((HERE/'clearance_review.json').read_text());assert clearance['status']=='passed' and clearance['chair_edge_crossings']==0 and clearance['head_vertices_faces_and_uvs_identical'] and clearance['body_topology_and_uvs_identical']
changes=json.loads((HERE/'pose_changes.json').read_text());soles=[c for c in changes['body_components'] if c['label']=='Rubber shoe sole'];assert len(soles)==2
for foot in soles:
    low,high=foot['after_bounds_studs'];assert abs(low[1])<.000001 and abs(high[1]-.13)<.0001
    assert -1.4<=(low[2]+high[2])/2<=-1.2+.00001 and low[2]>=-1.6
fbx=json.loads((HERE/'fbx_review.json').read_text());assert fbx['status']=='passed' and len(fbx['assets'])==4
required=['June_Front','June_Side','June_InRocker_Side','June_InRocker_ThreeQuarter','June_OnPorch','DeliveryCrate_Side','SmallOffice_Front','GloriaYard_Stage3_Lawn']
if '--sources-only' not in sys.argv:
    assert {p.stem for p in (OUT/'Previews').glob('*.png')}==set(required)
    for name in required:
        with Image.open(OUT/'Previews'/(name+'.png')) as im:assert im.size==(1280,1280);im.verify()
paths=subprocess.check_output(['git','diff','--name-only','origin/main'],cwd=REPO,text=True).splitlines()+subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=REPO,text=True).splitlines()
assert all(p.startswith('model-source/HighPoly/39_Fixes/') for p in paths),paths
from validate_surfaces import validate_surfaces
surface_report=validate_surfaces()
report=dict(status='passed',models=4,june_triangles=triangles,june_mesh_objects=len(parts),bounds_min_studs=lo.tolist(),bounds_max_studs=hi.tolist(),head_export_attribute_max_delta=head_deltas,head_native_geometry_and_uvs_identical=True,body_topology_and_uvs_identical=True,shared_textures_byte_identical=True,chair_surface_crossings=0,feet_flat_and_within_runner_limit=True,combined_roots_translation_only=True,june_at_origin=True,fbx_reimport_checked=True,surface_fixes=surface_report,preview_count=8 if '--sources-only' not in sys.argv else 0,only_39_fixes_changed=True,studio_import_tested=False)
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
manifest['validation']=report;(OUT/'model_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('PASS: four models, June preserved, source geometry/UVs/markers checked, default coplanar check clean, specified 0.03-stud checks passed, FBX exports and delivery scope.')
