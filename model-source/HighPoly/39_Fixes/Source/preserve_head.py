"""Reuse the original glTF head accessors byte-for-byte after Blender export.

This avoids a second export changing the original head's triangulation or
per-corner attributes. The node keeps its original neck pivot and transform.
"""
from pathlib import Path
import json,copy,hashlib
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;BASE=OUT.parent/'37_Story';NAME='NPC_June_Sitting'
def preserve(path):
    source_path=BASE/'Models'/NAME/(NAME+'.gltf');source=json.loads(source_path.read_text());doc=json.loads(path.read_text())
    old_node=next(n for n in source['nodes'] if n['name']==NAME+'__Head');new_node=next(n for n in doc['nodes'] if n['name']==NAME+'__Head')
    old_mesh=source['meshes'][old_node['mesh']];new_mesh=doc['meshes'][new_node['mesh']]
    original_buffers=[(source_path.parent/b['uri']).read_bytes() for b in source['buffers']]
    target_path=path.parent/doc['buffers'][0]['uri'];data=bytearray(target_path.read_bytes());views={};accessors={};hashes={}
    def accessor(index):
        if index in accessors:return accessors[index]
        row=copy.deepcopy(source['accessors'][index]);view_index=row['bufferView']
        if view_index not in views:
            view=copy.deepcopy(source['bufferViews'][view_index]);first=view.get('byteOffset',0);chunk=original_buffers[view['buffer']][first:first+view['byteLength']]
            while len(data)%4:data.append(0)
            view['buffer']=0;view['byteOffset']=len(data);data.extend(chunk)
            views[view_index]=len(doc['bufferViews']);doc['bufferViews'].append(view);hashes[str(view_index)]=hashlib.sha256(chunk).hexdigest()
        row['bufferView']=views[view_index];accessors[index]=len(doc['accessors']);doc['accessors'].append(row);return accessors[index]
    mesh=copy.deepcopy(old_mesh)
    for i,primitive in enumerate(mesh['primitives']):
        primitive['attributes']={name:accessor(index) for name,index in primitive['attributes'].items()}
        primitive['indices']=accessor(primitive['indices'])
        primitive['material']=new_mesh['primitives'][i]['material']
    doc['meshes'][new_node['mesh']]=mesh;doc['buffers'][0]['byteLength']=len(data)
    target_path.write_bytes(data);path.write_text(json.dumps(doc,indent=2)+'\n')
    return dict(file=path.relative_to(OUT).as_posix(),original_head_buffer_view_sha256=hashes,original_head_attributes_and_indices_reused=True)
def main():
    rows=[preserve(path) for path in [OUT/'Models'/NAME/(NAME+'.gltf'),OUT/'ALL/39_Fixes.gltf']]
    (HERE/'head_preservation.json').write_text(json.dumps(rows,indent=2)+'\n');print('Preserved the original head buffers in both glTF exports.')
if __name__=='__main__':main()
