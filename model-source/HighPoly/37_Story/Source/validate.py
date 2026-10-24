"""Audit serialized glTF buffers, actual bounds, budgets, pivots and delivery files."""
from pathlib import Path
import json,hashlib,sys
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;OUT=HERE.parent
specs={s['name']:s for s in json.loads((HERE/'specifications.json').read_text())}
manifest=json.loads((OUT/'model_manifest.json').read_text());rows=manifest['assets'];assert len(rows)==23 and {r['name'] for r in rows}==set(specs)
types={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'};width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
report=[]
def transform(node):
    if 'matrix' in node:return np.array(node['matrix']).reshape(4,4).T
    m=np.eye(4);x,y,z,w=node.get('rotation',[0,0,0,1]);m[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    m[:3,:3]=m[:3,:3]@np.diag(node.get('scale',[1,1,1]));m[:3,3]=node.get('translation',[0,0,0]);return m
for row in rows:
    n=row['name'];base=OUT/'Models'/n;path=base/(n+'.gltf');d=json.loads(path.read_text());buffers=[(base/b['uri']).read_bytes() for b in d['buffers']]
    def arr(index):
        a=d['accessors'][index];v=d['bufferViews'][a['bufferView']];dtype=np.dtype(types[a['componentType']]);count=width[a['type']]
        return np.ndarray((a['count'],count),dtype=dtype,buffer=buffers[v['buffer']],offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',count*dtype.itemsize),dtype.itemsize)).copy()
    matrices={}
    def walk(index,parent):
        node=d['nodes'][index];m=parent@transform(node);matrices[index]=m
        for child in node.get('children',[]):walk(child,m)
    for root in d['scenes'][d.get('scene',0)]['nodes']:walk(root,np.eye(4))
    allpoints=[];triangles=0;mesh_count=0
    for index,node in enumerate(d['nodes']):
        if 'mesh' not in node:continue
        mesh_count+=1;node_tri=0
        for p in d['meshes'][node['mesh']]['primitives']:
            assert p.get('mode',4)==4
            vertices=arr(p['attributes']['POSITION']);assert np.isfinite(vertices).all()
            normals=arr(p['attributes']['NORMAL']);assert np.allclose(np.linalg.norm(normals,axis=1),1,atol=.003)
            uv=arr(p['attributes']['TEXCOORD_0']);assert np.isfinite(uv).all()
            ix=arr(p['indices']).reshape(-1,3);assert ix.min()>=0 and ix.max()<len(vertices)
            xyz=vertices[ix];areas=np.linalg.norm(np.cross(xyz[:,1]-xyz[:,0],xyz[:,2]-xyz[:,0]),axis=1)
            assert (areas>1e-13).all(),(n,'degenerate triangle',int((areas<=1e-13).sum()))
            node_tri+=len(ix);points=np.c_[vertices,np.ones(len(vertices))]@matrices[index].T;allpoints.extend(points[:,:3]/.28)
        assert node_tri<=20000,(n,node['name'],node_tri)
        triangles+=node_tri
    pts=np.array(allpoints);lo=pts.min(axis=0);hi=pts.max(axis=0)
    assert np.allclose(lo,row['bounds_min_studs'],atol=.002) and np.allclose(hi,row['bounds_max_studs'],atol=.002),(n,lo,hi)
    low,high=specs[n]['budget'];assert low<=triangles<=high,(n,triangles,low,high)
    assert triangles==row['triangles'] and mesh_count==row['mesh_objects']
    assert row['primary_part']=='Root' and row['primary_position_studs']==[0,.5,0]
    if not n.startswith('GloriaYard'):
        target=np.array(specs[n]['baseline']['dimensions_studs']);assert np.all(np.abs((hi-lo)/target-1)<=.10+1e-5)
        assert abs(lo[1])<.002
    else:assert np.allclose([lo[0],hi[0],lo[2],hi[2]],[-22,22,-48,-18],atol=.002)
    if n.startswith('NPC_'):
        assert mesh_count<=4 and n+'__Head' in [p['name'] for p in row['parts']]
        assert {'Head','Talk'}<=set(m['name'] for m in row['markers'])
    if n.startswith('Debris'):assert mesh_count==1 and row['folder']=='Props' and hi[1]<=.61
    for m in row['markers']:
        assert m['parent_mesh'] in [p['name'] for p in row['parts']]
        assert np.allclose(m['look_vector'],[0,0,-1],atol=1e-5)
    for image in d.get('images',[]):assert (base/image['uri']).exists()
    assert (base/(n+'.fbx')).read_bytes().startswith(b'Kaydara FBX Binary')
    report.append(dict(name=n,triangles=triangles,mesh_objects=mesh_count,bounds_error_studs=float(max(abs(lo-np.array(row['bounds_min_studs'])).max(),abs(hi-np.array(row['bounds_max_studs'])).max())),passed=True))
library=json.loads((OUT/'ALL/37_Story.gltf').read_text());roots=library['scenes'][0]['nodes'];assert len(roots)==23
assert {library['nodes'][i]['name'] for i in roots}==set(specs)
for i in roots:
    n=library['nodes'][i];assert 'rotation' not in n and 'scale' not in n and 'matrix' not in n
by_name={r['name']:r for r in rows}
for ai,a in enumerate(rows):
    amin=np.array(a['bounds_min_studs'])*.28+np.array(a['library_translation_meters']);amax=np.array(a['bounds_max_studs'])*.28+np.array(a['library_translation_meters'])
    for b in rows[ai+1:]:
        bmin=np.array(b['bounds_min_studs'])*.28+np.array(b['library_translation_meters']);bmax=np.array(b['bounds_max_studs'])*.28+np.array(b['library_translation_meters'])
        assert np.any(amax<bmin) or np.any(bmax<amin),('Library grid overlaps',a['name'],b['name'])
house=by_name['GloriaHouse'];house_markers={m['name']:m['position_studs'] for m in house['markers']}
truck=by_name['TurfKingTruck'];truck_min=np.array(truck['bounds_min_studs'])+house_markers['Driveway'];truck_max=np.array(truck['bounds_max_studs'])+house_markers['Driveway']
for name in ['GloriaYard_Stage1','GloriaYard_Stage2','GloriaYard_Stage3']:
    layout=by_name[name]['features']['layout'];assert abs(layout['walk_x']-house_markers['Porch'][0])<.002 and abs(layout['drive_x']-house_markers['Driveway'][0])<.002
    assert truck_min[0]>=layout['drive_x']-layout['drive_width']/2 and truck_max[0]<=layout['drive_x']+layout['drive_width']/2
    assert truck_min[2]>=layout['drive_z'][0] and truck_max[2]<=layout['drive_z'][1]
chair_spot=next(m for m in by_name['PorchDeck']['markers'] if m['name']=='ChairSpot');assert abs(chair_spot['position_studs'][1]-1.6)<.002
for p in (OUT/'Textures').glob('*.png'):
    with Image.open(p) as im:assert max(im.size)<=2048;im.verify()
if '--sources-only' not in sys.argv:
    for n in specs:
        with Image.open(OUT/'Previews'/(n+'_Preview.png')) as im:im.verify()
    for n in ['CharacterSheet','Scene_Porch','Scene_Contest']:
        with Image.open(OUT/'Previews'/(n+'.png')) as im:
            if n=='CharacterSheet':assert im.size==(2048,2048)
            im.verify()
    fbx=json.loads((HERE/'fbx_review.json').read_text());assert len(fbx['assets'])==23 and not fbx['issues']
    manifest['validation']=dict(gltf_export_checked=True,fbx_reimport_checked=True,preview_count=26,studio_import_tested=False)
    (OUT/'model_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(OUT/'validation.json').write_text(json.dumps(dict(status='passed',models=report,combined_roots_translation_only=True,combined_grid_nonoverlap=True,house_yard_walk_drive_and_parked_truck_alignment=True,porch_chair_height_studs=1.6,textures_max_px=2048,studio_import_tested=False),indent=2)+'\n')
print('PASS: 23 story exports; actual geometry, bounds, budgets, normals, UVs, pivots, textures and combined roots.')
