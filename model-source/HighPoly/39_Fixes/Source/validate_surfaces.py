"""Validate serialized fixes and unchanged parts against the original packs."""
from pathlib import Path
import json,copy,hashlib,subprocess
import numpy as np
from PIL import Image
from gltf_tools import Model,components
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;HP=OUT.parent
SOURCES={'DeliveryCrate':'33_ShopDesksAndDeliveries','SmallOffice':'24_YardAndBuildings','GloriaYard_Stage3':'37_Story'}
def material_signature(doc,index):
    m=copy.deepcopy(doc['materials'][index])
    def visit(obj):
        if isinstance(obj,dict):
            for key,value in obj.items():
                if key.lower().endswith('texture') and isinstance(value,dict) and 'index' in value:
                    t=doc['textures'][value['index']];value['index']={'image':Path(doc['images'][t['source']]['uri']).name,'sampler':doc.get('samplers',[])[t['sampler']] if 'sampler' in t else None}
                else:visit(value)
        elif isinstance(obj,list):
            for value in obj:visit(value)
    visit(m);return m
def validate_surfaces():
    manifest=json.loads((OUT/'model_manifest.json').read_text());library=Model(OUT/'ALL/39_Fixes.gltf');reports=[]
    for row in manifest['assets']:
        name=row['name'];model=Model(OUT/'Models'/name/(name+'.gltf'));parts,lo,hi=model.geometry_summary()
        assert set(parts)=={p['name'] for p in row['parts']} and sum(parts.values())==row['triangles'] and len(parts)==row['mesh_objects']
        assert all(n<=20000 for n in parts.values()) and row['triangles']<=row['triangle_budget']
        assert np.allclose(lo,row['bounds_min_studs'],atol=.00001) and np.allclose(hi,row['bounds_max_studs'],atol=.00001)
        for part in parts:
            expected=row['library_translation_meters']
            assert np.allclose(library.worlds[library.node(part)][:3,3]-model.worlds[model.node(part)][:3,3],expected,atol=.00001)
            assert np.allclose(library.worlds[library.node(part)][:3,:3],model.worlds[model.node(part)][:3,:3])
            for a,b in zip(model.primitives(part),library.primitives(part)):
                for attr,ai in a['attributes'].items():assert np.array_equal(model.view(ai),library.view(b['attributes'][attr])),(name,part,attr)
                assert np.array_equal(model.view(a['indices']),library.view(b['indices']))
                assert material_signature(model.doc,a['material'])==material_signature(library.doc,b['material'])
                xyz=model.view(a['attributes']['POSITION']);ix=model.view(a['indices']).reshape(-1,3);normal=model.view(a['attributes']['NORMAL']);uv=model.view(a['attributes']['TEXCOORD_0'])
                assert np.isfinite(xyz).all() and np.isfinite(uv).all() and np.allclose(np.linalg.norm(normal,axis=1),1,atol=.003)
                tris=xyz[ix];areas=np.linalg.norm(np.cross(tris[:,1]-tris[:,0],tris[:,2]-tris[:,0]),axis=1);assert (areas>1e-13).all(),(name,part,'degenerate faces',int((areas<=1e-13).sum()))
        if name not in SOURCES:continue
        pack=SOURCES[name];base=HP/pack;original=Model(base/'Models'/name/(name+'.gltf'));old_row=next(r for r in json.loads((base/'model_manifest.json').read_text())['assets'] if r['name']==name)
        assert model.doc['nodes']==original.doc['nodes'],(name,'node/pivot/attachment changes')
        assert model.doc['materials']==original.doc['materials'] and model.doc['textures']==original.doc['textures'] and model.doc['images']==original.doc['images']
        assert row['markers']==old_row['markers'] and row['slots']==old_row['slots'] and row['folder']==old_row['folder']
        assert row['primary_part']==old_row['primary_part'] and row['primary_position_studs']==[0,.5,0]
        for p,old in zip(row['parts'],old_row['parts']):assert {k:v for k,v in p.items() if k!='triangles'}=={k:v for k,v in old.items() if k!='triangles'}
        for part in parts:
            for p,old in zip(model.primitives(part),original.primitives(part)):
                if part.endswith('__Lawn'):
                    assert set(map(tuple,model.view(p['attributes']['TEXCOORD_0'])))<=set(map(tuple,original.view(old['attributes']['TEXCOORD_0'])))
                    assert parts[part]==330
                    y=model.positions(part,p)[:,1];assert np.isclose(y.max(),.129,atol=.000001) and np.isclose(y.min(),0)
                    continue
                assert np.array_equal(model.view(p['indices']),original.view(old['indices']))
                assert np.array_equal(model.view(p['attributes']['TEXCOORD_0']),original.view(old['attributes']['TEXCOORD_0']))
                if part not in [name+'__Body','SmallOffice__Glass_Door']:
                    for attr in p['attributes']:assert np.array_equal(model.view(p['attributes'][attr]),original.view(old['attributes'][attr]))
        body=name+'__Body';p=model.primitives(body)[0];op=original.primitives(body)[0];before=original.positions(body,op);after=model.positions(body,p)
        groups=components(before,original.view(op['indices']).reshape(-1,3));allowed=np.zeros(len(before),bool)
        if name=='DeliveryCrate':
            selected=[g for g in groups if (g['hi']-g['lo'])[2]>6.5 and (g['hi']-g['lo'])[0]<.12 and g['lo'][1]>.4];assert len(selected)==12
            for g in selected:
                inds=g['indices'];allowed[inds]=True;outer=np.max(np.abs(after[inds,0]));assert abs(np.max(np.abs(before[inds,0]))-outer-.031)<.00001
                assert np.allclose(before[inds,1],after[inds,1])
                assert abs(after[inds,2].min()-g['lo'][2]-.02)<.00001 and abs(g['hi'][2]-after[inds,2].max()-.02)<.00001
        elif name=='SmallOffice':
            trim=[g for g in groups if g['lo'][0]<-12 and g['hi'][0]<.4 and g['lo'][1]>10.6 and g['hi'][1]<11.3 and g['lo'][2]<-13.85]
            siding=[g for g in groups if g['lo'][0]>6.934 and g['hi'][0]<6.997 and g['hi'][1]>16.86 and (g['hi']-g['lo'])[2]>25]
            assert len(trim)==len(siding)==1
            inds=trim[0]['indices'];allowed[inds]=True;assert np.allclose(after[inds]-before[inds],[0,.04,-.04],atol=.00001)
            inds=siding[0]['indices'];allowed[inds]=True;assert abs(after[inds,1].max()-16.85)<.00001 and np.array_equal(after[inds][:,[0,2]],before[inds][:,[0,2]])
            glass='SmallOffice__Glass_Door';g=model.positions(glass,model.primitives(glass)[0]);old=original.positions(glass,original.primitives(glass)[0])
            assert abs((g[:,2].max()+g[:,2].min())/2+13.884)<.00001 and np.allclose(g.max(0)-g.min(0),old.max(0)-old.min(0),atol=.00001)
        else:
            paving=[g for g in groups if (g['hi']-g['lo'])[2]>29.9 and g['hi'][1]<.2];assert len(paving)==2
            for g in paving:
                inds=g['indices'];allowed[inds]=True;assert np.array_equal(before[inds][:,:2],after[inds][:,:2]);assert abs(after[inds,2].min()+47.96)<.00001 and abs(after[inds,2].max()+18.04)<.00001
            assert row['triangles']==11366 and row['triangles']<14000
        assert np.array_equal(before[~allowed],after[~allowed]),(name,'unrelated body vertices changed')
        for texture in (base/'Textures').glob('*.png'):
            assert texture.read_bytes()==(OUT/'Textures'/texture.name).read_bytes()
            with Image.open(OUT/'Textures'/texture.name) as im:assert max(im.size)<=2048;im.verify()
        reports.append(dict(name=name,triangles=row['triangles'],mesh_objects=len(parts),original_markers_nodes_pivots_roles_and_sizes_preserved=True,original_texture_atlas_and_uvs_preserved=True,unrelated_geometry_preserved=True))
    for a in manifest['assets']:
        for b in manifest['assets']:
            if a['name']>=b['name']:continue
            a0=np.array(a['bounds_min_studs'])*.28+a['library_translation_meters'];a1=np.array(a['bounds_max_studs'])*.28+a['library_translation_meters'];b0=np.array(b['bounds_min_studs'])*.28+b['library_translation_meters'];b1=np.array(b['bounds_max_studs'])*.28+b['library_translation_meters'];assert np.any(a1<b0) or np.any(b1<a0)
    coplanar=json.loads((HERE/'coplanar_review.json').read_text());assert coplanar['status']=='passed' and coplanar['default_returncode']==0 and not coplanar['expanded_targeted_failures']
    return dict(assets=reports,combined_mesh_data_materials_and_transforms_checked=True,grid_nonoverlapping=True,default_coplanar_checker_clean=True,specified_surfaces_clear_at_003_studs=True,other_original_wide_tolerance_pairs=len(coplanar['expanded_other_original_surface_pairs']))
