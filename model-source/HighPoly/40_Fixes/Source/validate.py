"""Inspect the serialized delivery against original HP24, HP33 and HP37 data.

Run after the FBX audit. This checks the actual export and the repository's
unmodified overlap detector, including source UVs, collision geometry, markers,
hinge transforms, ALL's mesh arrays, bounds, budgets and preview files.
"""
from pathlib import Path
import copy
import hashlib
import json
import subprocess
import sys

sys.dont_write_bytecode = True
import numpy as np
from PIL import Image
from gltf_tools import Model, components, matrix

HERE = Path(__file__).resolve().parent
OUT = HERE.parent
HP = OUT.parent
REPO = HP.parent.parent
SOURCES = {
    'DeliveryCrate': '33_ShopDesksAndDeliveries',
    'SmallOffice': '24_YardAndBuildings',
    'GloriaYard_Stage1': '37_Story',
    'GloriaYard_Stage2': '37_Story',
    'GloriaYard_Stage3': '37_Story',
}


def material_signature(doc, index):
    result = copy.deepcopy(doc['materials'][index])

    def walk(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if key.lower().endswith('texture') and isinstance(item, dict) and 'index' in item:
                    texture = doc['textures'][item['index']]
                    item['index'] = Path(doc['images'][texture['source']]['uri']).name
                else:
                    walk(item)
        elif isinstance(value, list):
            for item in value:
                walk(item)
    walk(result)
    return result


def indexed(model, primitive, attribute):
    return model.view(primitive['attributes'][attribute])[model.view(primitive['indices']).reshape(-1, 3)]


def standalone(model):
    for item in model.doc.get('buffers',[])+model.doc.get('images',[]):
        path=(model.path.parent/item['uri']).resolve()
        assert path.is_file() and OUT.resolve() in path.parents,(model.path,'external or missing reference',path)


def same_hierarchy(model, library, source_index, combined_index, root=False):
    source=copy.deepcopy(model.doc['nodes'][source_index])
    combined=copy.deepcopy(library.doc['nodes'][combined_index])
    children=source.pop('children',[])
    combined_children=combined.pop('children',[])
    source.pop('mesh',None);combined.pop('mesh',None)
    if root:
        source.pop('translation',None);combined.pop('translation',None)
    assert source==combined,(source.get('name'),'ALL hierarchy metadata/transform')
    assert len(children)==len(combined_children)
    for a,b in zip(children,combined_children):same_hierarchy(model,library,a,b)


def validate():
    manifest = json.loads((OUT / 'model_manifest.json').read_text())
    library = Model(OUT / 'ALL/40_Fixes.gltf')
    standalone(library)
    assert manifest['meters_per_stud'] == .28
    assert {r['name'] for r in manifest['assets']} == set(SOURCES)
    assert len(library.doc['scenes'][0]['nodes']) == 5
    reports = []
    for row in manifest['assets']:
        name = row['name']
        model = Model(OUT / 'Models' / name / (name + '.gltf'))
        standalone(model)
        base = HP / SOURCES[name]
        original = Model(base / 'Models' / name / (name + '.gltf'))
        original_row = next(r for r in json.loads((base / 'model_manifest.json').read_text())['assets'] if r['name'] == name)
        # Includes marker attributes, attachment orientations, hinge pivots,
        # collision roles, source node names and the Root transform.
        assert model.doc['nodes'] == original.doc['nodes'], name
        for key in ['materials', 'textures', 'images', 'samplers']:
            assert model.doc.get(key) == original.doc.get(key), (name, key)
        for key in ['name', 'folder', 'markers', 'slots', 'primary_part', 'primary_position_studs', 'triangle_budget']:
            assert row[key] == original_row[key], (name, key)
        assert row['primary_position_studs'] == [0, .5, 0]
        assert row['instruction'] == 40
        for p, old in zip(row['parts'], original_row['parts']):
            assert {k:v for k,v in p.items() if k != 'triangles'} == {k:v for k,v in old.items() if k != 'triangles'}
        parts, lo, hi = model.geometry_summary()
        assert set(parts) == {p['name'] for p in row['parts']}
        assert sum(parts.values()) == row['triangles'] <= row['triangle_budget']
        assert len(parts) == row['mesh_objects']
        assert all(parts[p['name']] == p['triangles'] for p in row['parts'])
        assert np.allclose(lo, row['bounds_min_studs'], atol=1e-5)
        assert np.allclose(hi, row['bounds_max_studs'], atol=1e-5)
        assert np.allclose(hi-lo, row['dimensions_studs'], atol=1e-5)
        root = library.doc['nodes'][library.node(name)]
        assert not any(key in root for key in ['rotation', 'scale', 'matrix'])
        assert np.allclose(root['translation'], row['library_translation_meters'])
        same_hierarchy(model,library,model.doc['scenes'][0]['nodes'][0],library.node(name),root=True)
        unchanged_parts = []
        for part in parts:
            node_index = model.node(part)
            library_index = library.node(part)
            delta = library.worlds[library_index][:3,3] - model.worlds[node_index][:3,3]
            assert np.allclose(delta, row['library_translation_meters'], atol=1e-5)
            assert np.allclose(library.worlds[library_index][:3,:3], model.worlds[node_index][:3,:3])
            for p, old, combined in zip(model.primitives(part), original.primitives(part), library.primitives(part)):
                assert material_signature(model.doc, p['material']) == material_signature(library.doc, combined['material'])
                for attr, ai in p['attributes'].items():
                    assert np.array_equal(model.view(ai), library.view(combined['attributes'][attr])), (name, part, 'ALL', attr)
                    assert np.isfinite(model.view(ai)).all(), (name, part, attr)
                assert np.array_equal(model.view(p['indices']), library.view(combined['indices']))
                normal = model.view(p['attributes']['NORMAL'])
                assert np.allclose(np.linalg.norm(normal, axis=1), 1, atol=.003)
                triangles = indexed(model, p, 'POSITION')
                areas = np.linalg.norm(np.cross(triangles[:,1]-triangles[:,0], triangles[:,2]-triangles[:,0]), axis=1)
                assert (areas > 1e-13).all(), (name, part, 'degenerate triangles')
                changed_part = part in [name+'__Body', name+'__Lawn', 'SmallOffice__Glass_Door']
                if not changed_part:
                    assert np.array_equal(model.view(p['indices']), original.view(old['indices']))
                    for attr in p['attributes']:
                        assert np.array_equal(model.view(p['attributes'][attr]), original.view(old['attributes'][attr])), (name, part, attr)
                    unchanged_parts.append(part)
                if part.endswith('__Lawn'):
                    # Top faces keep their source order, swatches and topology;
                    # redundant underlying layers are the only removed faces.
                    before = original.positions(part, old)[original.view(old['indices']).reshape(-1,3)]
                    source_top = np.max(before[:,:,1])
                    top_mask = np.all(abs(before[:,:,1]-source_top) < 1e-5, axis=1)
                    base = np.all(before[:,:,1] < .12001, axis=1)
                    base_top = np.all(abs(before[:,:,1]-.12) < 1e-5, axis=1)
                    keep = top_mask | (base & ~base_top)
                    assert np.array_equal(indexed(model,p,'TEXCOORD_0'), indexed(original,old,'TEXCOORD_0')[keep])
                    assert np.array_equal(indexed(model,p,'NORMAL'), indexed(original,old,'NORMAL')[keep])
                    points = model.positions(part,p)
                    assert abs(points[:,1].max()-.129) < 1e-6 and abs(points[:,1].min()) < 1e-6
                    top_tris = points[model.view(p['indices']).reshape(-1,3)]
                    tops = np.all(abs(top_tris[:,:,1]-.129)<1e-5,axis=1)
                    top_points = top_tris[tops]
                    surface_area = np.linalg.norm(np.cross(top_points[:,1]-top_points[:,0],top_points[:,2]-top_points[:,0]),axis=1).sum()/2
                    assert abs(surface_area-1320)<.001, (name,'lawn coverage')
                    continue
                before_ix = original.view(old['indices']).reshape(-1,3)
                keep = np.ones(len(before_ix),bool)
                if name in ['GloriaYard_Stage1','GloriaYard_Stage2'] and part.endswith('__Body'):
                    before = original.positions(part,old)[before_ix]
                    crosses = np.cross(before[:,1]-before[:,0],before[:,2]-before[:,0])
                    buried = (crosses[:,1]<0)&np.all(abs(before[:,:,1]-.1)<1e-5,axis=1)
                    keep = ~buried
                assert np.array_equal(indexed(model,p,'TEXCOORD_0'), indexed(original,old,'TEXCOORD_0')[keep]), (name,part,'UV changes')
                # Every surviving body vertex outside the specified details is
                # compared in world space with its original. No decoration is
                # shifted to compensate for a lawn-height change.
                if part.endswith('__Body'):
                    old_points = original.positions(part,old)
                    groups = components(old_points,before_ix)
                    allowed = np.zeros(len(old_points),bool)
                    if name == 'SmallOffice':
                        permitted = [0,1,87,88,122,123,157,158,202,203,251,252,253,258,264,270,273,275,276,279,290]
                        for i in permitted:allowed[groups[i]['indices']] = True
                    elif name == 'DeliveryCrate':
                        for g in groups:
                            span = g['hi']-g['lo']
                            if span[2]>6.5 and span[0]<.12 and g['lo'][1]>.4:
                                allowed[g['indices']] = True
                    else:
                        for g in groups:
                            if (g['hi']-g['lo'])[2]>29.9 and g['hi'][1]<.2:
                                allowed[g['indices']] = True
                    original_tris = old_points[before_ix][keep]
                    after_tris = model.positions(part,p)[model.view(p['indices']).reshape(-1,3)]
                    assert after_tris.shape == original_tris.shape
                    unchanged = (~allowed)[before_ix][keep]
                    assert np.array_equal(after_tris[unchanged],original_tris[unchanged]), (name,'unrelated geometry moved')
        if name == 'SmallOffice':
            collision = [p['name'] for p in row['parts'] if p['role'].startswith('collision_')]
            assert set(collision) <= set(unchanged_parts)
            assert len(row['slots']) == len(original_row['slots'])
        texture_hashes = {}
        for texture in (HP/SOURCES[name]/'Textures').glob('*.png'):
            target = OUT/'Textures'/texture.name
            assert texture.read_bytes() == target.read_bytes()
            with Image.open(target) as im:
                assert max(im.size)<=2048
                im.verify()
            texture_hashes[texture.name] = hashlib.sha256(target.read_bytes()).hexdigest()
        reports.append(dict(name=name,status='passed',triangles=row['triangles'],budget=row['triangle_budget'],meshes=len(parts),original_node_hierarchy_markers_pivots_and_roles_preserved=True,original_UVs_and_colours_preserved=True,unrelated_geometry_unchanged=True,byte_identical_unchanged_parts=unchanged_parts,texture_sha256=texture_hashes))
    # Require five metres of open space between any two library AABBs, not just
    # between their origins. The chosen 28 m pitch exceeds the requested gap.
    gaps = []
    for i,a in enumerate(manifest['assets']):
        for b in manifest['assets'][i+1:]:
            a0=np.array(a['bounds_min_studs'])*.28+a['library_translation_meters']
            a1=np.array(a['bounds_max_studs'])*.28+a['library_translation_meters']
            b0=np.array(b['bounds_min_studs'])*.28+b['library_translation_meters']
            b1=np.array(b['bounds_max_studs'])*.28+b['library_translation_meters']
            gap=float(np.linalg.norm(np.maximum(np.maximum(a0-b1,b0-a1),0)))
            assert gap>=5,(a['name'],b['name'],gap)
            gaps.append(dict(a=a['name'],b=b['name'],metres=gap))
    checks=[]
    for args,label in [([], 'default'),(['--tol','0.029'],'0.029')]:
        result=subprocess.run([sys.executable,str(REPO/'scripts/check-coplanar.py'),str(OUT),*args],capture_output=True,text=True,cwd=REPO)
        (HERE/('coplanar_'+label+'.txt')).write_text(result.stdout+result.stderr)
        assert result.returncode == 0, result.stdout+result.stderr
        checks.append(dict(tolerance=label,returncode=0,overlaps=0,underside_exception_used=False))
    fbx=json.loads((HERE/'fbx_review.json').read_text())
    assert fbx['status']=='passed' and len(fbx['assets'])==5
    previews=['DeliveryCrate_Side','SmallOffice_Front','SmallOffice_Inside']+[f'GloriaYard_Stage{s}_Lawn' for s in [1,2,3]]
    assert {p.stem for p in (OUT/'Previews').glob('*.png')} == set(previews)
    for name in previews:
        with Image.open(OUT/'Previews'/(name+'.png')) as im:
            assert im.size==(1280,1280)
            im.verify()
    changed=subprocess.check_output(['git','diff','--name-only','7b33629'],cwd=REPO,text=True).splitlines()
    added=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=REPO,text=True).splitlines()
    assert all(p.startswith('model-source/HighPoly/40_Fixes/') for p in changed+added),(changed,added)
    validation=dict(status='passed',instruction=40,assets=reports,coplanar_checks=checks,fbx_roundtrip=fbx,library_bounds_separated_by_at_least_5_metres=True,library_gaps=gaps,all_individual_mesh_arrays_and_materials_match_library=True,preview_count=6,preview_resolution=[1280,1280],original_packs_and_39_Fixes_unchanged=True,only_40_Fixes_changed=True,studio_import_tested=False)
    (OUT/'validation.json').write_text(json.dumps(validation,indent=2)+'\n')
    manifest['validation']={'status':'passed','report':'validation.json','coplanar_default':0,'coplanar_tol_0029':0,'studio_import_tested':False}
    (OUT/'model_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('PASS: five models, source preservation, 5 m grid clearance, zero overlaps at both tolerances, five FBX reimports, six previews, folder scope.')


if __name__=='__main__':
    validate()
