"""Instruction 39's three surface fixes, applied to the original glTF data.

Keeps node transforms, markers, materials, UVs and all unrelated geometry intact.
June's already delivered files are not rewritten.
"""
from pathlib import Path
import sys,json,copy,shutil,hashlib
sys.dont_write_bytecode=True
import numpy as np
from gltf_tools import Model,components
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;HP=OUT.parent
SOURCES={'DeliveryCrate':'33_ShopDesksAndDeliveries','SmallOffice':'24_YardAndBuildings','GloriaYard_Stage3':'37_Story'}
reports=[];rows=[]
for name,pack in SOURCES.items():
    base=HP/pack;model=Model(base/'Models'/name/(name+'.gltf'));original_nodes=copy.deepcopy(model.doc['nodes']);changes=[]
    body=name+'__Body';primitive=model.primitives(body)[0];points=model.positions(body,primitive);indices=model.view(primitive['indices']).reshape(-1,3).copy();groups=components(points,indices)
    if name=='DeliveryCrate':
        selected=[g for g in groups if (g['hi']-g['lo'])[2]>6.5 and (g['hi']-g['lo'])[0]<.12 and g['lo'][1]>.4]
        assert len(selected)==12
        assert np.allclose(model.worlds[model.node(body)][:3,:3],np.eye(3))
        normals=model.view(primitive['attributes']['NORMAL'])
        for g in selected:
            shift=-np.sign(g['centre'][0])*.031;points[g['indices'],0]+=shift
            # Their short end faces otherwise come within 0.0195 of the posts'
            # end faces after the inset. Keep those ends hidden behind the posts.
            scale=((g['hi'][2]-g['lo'][2])-.04)/(g['hi'][2]-g['lo'][2])
            points[g['indices'],2]=g['centre'][2]+(points[g['indices'],2]-g['centre'][2])*scale
            normals[g['indices'],2]/=scale
            normals[g['indices']]/=np.linalg.norm(normals[g['indices']],axis=1)[:,None]
        changes.append(dict(surface='twelve horizontal side slats',count=12,inset_studs=.031,end_inset_studs=.02,post_positions_unchanged=True))
    elif name=='SmallOffice':
        trim=[g for g in groups if g['lo'][0]<-12 and g['hi'][0]<.4 and g['lo'][1]>10.6 and g['hi'][1]<11.3 and g['lo'][2]<-13.85]
        assert len(trim)==1
        points[trim[0]['indices'],2]-=.04
        # Moving the deep lintel forward also exposes its top beside a siding
        # course cap. Raise the complete strip 0.04, preserving its dimensions,
        # so this second same-facing pair is separated as well.
        points[trim[0]['indices'],1]+=.04
        siding=[g for g in groups if g['lo'][0]>6.934 and g['hi'][0]<6.997 and g['hi'][1]>16.86 and (g['hi']-g['lo'])[2]>25]
        assert len(siding)==1
        points[siding[0]['indices'],1]=np.minimum(points[siding[0]['indices'],1],16.85)
        glass=name+'__Glass_Door';gp=model.primitives(glass)[0];glass_points=model.positions(glass,gp);old_centre=(glass_points[:,2].min()+glass_points[:,2].max())/2
        glass_points[:,2]+=-13.884-old_centre;model.set_positions(glass,gp,glass_points)
        changes.extend([dict(surface='garage lintel trim',outward_shift_studs=.04,upward_shift_studs=.04,new_front_z_studs=float(points[trim[0]['indices'],2].min()),dimensions_unchanged=True),dict(surface='partition lap siding',new_top_y_studs=16.85,beam_unchanged=True),dict(surface='open door glazing',centre_z_studs=-13.884,minimum_front_wall_gap_studs=.0315,pivot_unchanged=True)])
    else:
        paving=[g for g in groups if (g['hi']-g['lo'])[2]>29.9 and g['hi'][1]<.2]
        assert len(paving)==2
        for g in paving:points[g['indices'],2]=np.clip(points[g['indices'],2],-47.96,-18.04)
        changes.append(dict(surface='walk and driveway end faces',front_z_studs=-47.96,back_z_studs=-18.04,lawn_edge_gap_studs=.04))
    model.set_positions(body,primitive,points)
    if name=='GloriaYard_Stage3':
        lawn=name+'__Lawn';lp=model.primitives(lawn)[0];xyz=model.positions(lawn,lp);tris=model.view(lp['indices']).reshape(-1,3).copy();face_points=xyz[tris]
        upper=np.all(np.abs(face_points[:,:,1]-.143)<.00001,axis=1)
        base_layer=np.all(face_points[:,:,1]<.12001,axis=1)
        base_top=np.all(np.abs(face_points[:,:,1]-.12)<.00001,axis=1)
        keep=upper|(base_layer&~base_top)
        assert int(upper.sum())==320 and int((base_layer&~base_top).sum())==10
        top_vertices=np.unique(tris[upper]);xyz[top_vertices,0]=-22+np.rint((xyz[top_vertices,0]+22)/2.75)*2.75
        xyz[top_vertices,2]=-48+np.rint((xyz[top_vertices,2]+48)/3)*3
        xyz[np.abs(xyz[:,1]-.12)<.00001,1]=.129;xyz[top_vertices,1]=.129
        model.set_positions(lawn,lp,xyz);model.compact(lp,keep)
        changes.append(dict(surface='checkerboard lawn',method='one non-overlapping top layer; original tile UVs',columns=16,rows=10,top_y_studs=.129,paving_gaps_studs=dict(driveway=.031,walk=.041),triangles_before=len(tris),triangles_after=int(keep.sum()),body_decorations_unchanged=True))
    assert model.doc['nodes']==original_nodes
    target=OUT/'Models'/name/(name+'.gltf');model.save(target)
    for texture in (base/'Textures').glob('*.png'):
        dest=OUT/'Textures'/texture.name
        if dest.exists():assert dest.read_bytes()==texture.read_bytes(),texture.name
        else:shutil.copyfile(texture,dest)
    source_row=next(r for r in json.loads((base/'model_manifest.json').read_text())['assets'] if r['name']==name)
    row=copy.deepcopy(source_row);parts,lo,hi=model.geometry_summary()
    assert set(parts)=={p['name'] for p in row['parts']}
    assert np.allclose(lo,source_row['bounds_min_studs'],atol=.00001) and np.allclose(hi,source_row['bounds_max_studs'],atol=.00001)
    row.update(instruction=39,triangles=sum(parts.values()),mesh_objects=len(parts),bounds_min_studs=lo.tolist(),bounds_max_studs=hi.tolist(),dimensions_studs=(hi-lo).tolist(),baseline_source_pack=pack,baseline_triangles=source_row['triangles'])
    for part in row['parts']:part['triangles']=parts[part['name']]
    row['features']['surface_fixes']=changes;rows.append(row)
    reports.append(dict(name=name,source_pack=pack,changes=changes,triangles=row['triangles'],mesh_objects=len(parts),original_nodes_transforms_markers_and_pivots_preserved=True))
    print('FIXED',name,row['triangles'],len(parts),'meshes',flush=True)
manifest=json.loads((OUT/'model_manifest.json').read_text());june=next(r for r in manifest['assets'] if r['name']=='NPC_June_Sitting')
manifest['assets']=[june]+rows;manifest['source_main_commit']='92b2573';manifest.pop('validation',None)
(OUT/'model_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(HERE/'surface_fixes.json').write_text(json.dumps(reports,indent=2)+'\n')
