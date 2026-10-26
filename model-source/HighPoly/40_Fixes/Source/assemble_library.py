"""Assemble five source-faithful models into a translation-only glTF library."""
from pathlib import Path
import json,copy
HERE=Path(__file__).resolve().parent;OUT=HERE.parent
placements={'DeliveryCrate':[0,0,0],'SmallOffice':[100,0,0],'GloriaYard_Stage1':[0,0,100],'GloriaYard_Stage2':[100,0,100],'GloriaYard_Stage3':[200,0,100]}
result=dict(asset={'version':'2.0','generator':'Instruction 40 source-preserving library assembly'},scene=0,scenes=[{'nodes':[]}])
keys=['nodes','meshes','accessors','bufferViews','materials','textures','images','samplers']
for key in keys:result[key]=[]
data=bytearray();used=set();required=set()
for name,position in placements.items():
    source=OUT/'Models'/name/(name+'.gltf');doc=json.loads(source.read_text());offset={key:len(result[key]) for key in keys};starts=[]
    assert not doc.get('animations') and not doc.get('skins') and not doc.get('cameras')
    for buffer in doc['buffers']:
        while len(data)%4:data.append(0)
        starts.append(len(data));data.extend((source.parent/buffer['uri']).read_bytes())
    for v in doc.get('bufferViews',[]):
        row=copy.deepcopy(v);row['byteOffset']=row.get('byteOffset',0)+starts[row.get('buffer',0)];row['buffer']=0;result['bufferViews'].append(row)
    for a in doc.get('accessors',[]):
        row=copy.deepcopy(a)
        if 'bufferView' in row:row['bufferView']+=offset['bufferViews']
        if 'sparse' in row:
            for field in ['indices','values']:row['sparse'][field]['bufferView']+=offset['bufferViews']
        result['accessors'].append(row)
    for m in doc.get('meshes',[]):
        row=copy.deepcopy(m)
        for p in row['primitives']:
            p['attributes']={k:v+offset['accessors'] for k,v in p['attributes'].items()}
            if 'indices' in p:p['indices']+=offset['accessors']
            if 'material' in p:p['material']+=offset['materials']
        result['meshes'].append(row)
    def texture_refs(obj):
        if isinstance(obj,dict):
            for key,value in obj.items():
                if key.lower().endswith('texture') and isinstance(value,dict) and 'index' in value:value['index']+=offset['textures']
                else:texture_refs(value)
        elif isinstance(obj,list):
            for value in obj:texture_refs(value)
    for m in doc.get('materials',[]):
        row=copy.deepcopy(m);texture_refs(row);result['materials'].append(row)
    for t in doc.get('textures',[]):
        row=copy.deepcopy(t)
        if 'source' in row:row['source']+=offset['images']
        if 'sampler' in row:row['sampler']+=offset['samplers']
        result['textures'].append(row)
    for image in doc.get('images',[]):
        row=copy.deepcopy(image);assert 'uri' in row;row['uri']='../Textures/'+Path(row['uri']).name;result['images'].append(row)
    result['samplers'].extend(copy.deepcopy(doc.get('samplers',[])))
    roots=doc['scenes'][doc.get('scene',0)]['nodes'];assert len(roots)==1
    for i,n in enumerate(doc['nodes']):
        row=copy.deepcopy(n)
        if 'children' in row:row['children']=[v+offset['nodes'] for v in row['children']]
        if 'mesh' in row:row['mesh']+=offset['meshes']
        if i==roots[0]:
            assert not any(k in row for k in ['rotation','scale','matrix'])
            row['translation']=[v*.28 for v in position];result['scenes'][0]['nodes'].append(i+offset['nodes'])
        result['nodes'].append(row)
    used.update(doc.get('extensionsUsed',[]));required.update(doc.get('extensionsRequired',[]))
if used:result['extensionsUsed']=sorted(used)
if required:result['extensionsRequired']=sorted(required)
result['buffers']=[dict(byteLength=len(data),uri='40_Fixes.bin')]
(OUT/'ALL/40_Fixes.bin').write_bytes(data);(OUT/'ALL/40_Fixes.gltf').write_text(json.dumps(result,indent=2)+'\n')
manifest=json.loads((OUT/'model_manifest.json').read_text())
for row in manifest['assets']:row['library_translation_meters']=[v*.28 for v in placements[row['name']]]
(OUT/'model_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('LIBRARY: five roots, disjoint bounds and 28 m grid pitch, original local mesh and marker transforms preserved.')
