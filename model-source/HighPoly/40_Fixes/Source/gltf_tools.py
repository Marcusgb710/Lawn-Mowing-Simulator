"""Small glTF buffer helpers: preserve node transforms, UVs and mesh splits."""
import copy,json,struct
from pathlib import Path
import numpy as np
STUD=.28
TYPES={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
WIDTH={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def matrix(node):
    if 'matrix' in node:return np.array(node['matrix']).reshape(4,4).T
    x,y,z,w=node.get('rotation',[0,0,0,1]);m=np.eye(4)
    m[:3,:3]=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])@np.diag(node.get('scale',[1,1,1]));m[:3,3]=node.get('translation',[0,0,0]);return m
class Model:
    def __init__(self,path):
        self.path=Path(path);self.doc=json.loads(self.path.read_text());self.buffers=[bytearray((self.path.parent/b['uri']).read_bytes()) for b in self.doc['buffers']];self.worlds={}
        def walk(i,parent):
            self.worlds[i]=parent@matrix(self.doc['nodes'][i])
            for child in self.doc['nodes'][i].get('children',[]):walk(child,self.worlds[i])
        for i in self.doc['scenes'][self.doc.get('scene',0)]['nodes']:walk(i,np.eye(4))
    def view(self,index):
        a=self.doc['accessors'][index];v=self.doc['bufferViews'][a['bufferView']];dtype=np.dtype(TYPES[a['componentType']]);width=WIDTH[a['type']]
        return np.ndarray((a['count'],width),dtype,buffer=self.buffers[v.get('buffer',0)],offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',width*dtype.itemsize),dtype.itemsize))
    def node(self,name):return next(i for i,n in enumerate(self.doc['nodes']) if n['name']==name)
    def primitives(self,name):return self.doc['meshes'][self.doc['nodes'][self.node(name)]['mesh']]['primitives']
    def positions(self,name,primitive):
        local=self.view(primitive['attributes']['POSITION']);world=self.worlds[self.node(name)]
        return (np.c_[local,np.ones(len(local))]@world.T)[:,:3]/STUD
    def set_positions(self,name,primitive,points):
        inv=np.linalg.inv(self.worlds[self.node(name)]);local=(np.c_[np.array(points)*STUD,np.ones(len(points))]@inv.T)[:,:3]
        array=self.view(primitive['attributes']['POSITION']);array[:]=local
        accessor=self.doc['accessors'][primitive['attributes']['POSITION']];accessor['min']=array.min(axis=0).tolist();accessor['max']=array.max(axis=0).tolist()
    def append(self,array,kind,component=5126,target=34962):
        values=np.asarray(array,dtype=TYPES[component]);data=values.tobytes();buffer=bytearray(self.buffers[0]);self.buffers[0]=buffer
        while len(buffer)%4:buffer.append(0)
        view=dict(buffer=0,byteOffset=len(buffer),byteLength=len(data),target=target);buffer.extend(data)
        vi=len(self.doc['bufferViews']);self.doc['bufferViews'].append(view)
        accessor=dict(bufferView=vi,componentType=component,count=len(values),type=kind)
        if kind!='SCALAR':accessor.update(min=values.min(axis=0).tolist(),max=values.max(axis=0).tolist())
        ai=len(self.doc['accessors']);self.doc['accessors'].append(accessor);return ai
    def compact(self,primitive,keep_triangles,new_positions=None):
        indices=self.view(primitive['indices']).ravel()[np.asarray(keep_triangles,dtype=int).reshape(-1)] if np.asarray(keep_triangles).ndim==2 else self.view(primitive['indices']).reshape(-1,3)[keep_triangles].ravel()
        used,new=np.unique(indices,return_inverse=True)
        attrs={name:self.view(index).copy()[used] for name,index in primitive['attributes'].items()}
        if new_positions is not None:attrs['POSITION']=np.asarray(new_positions)[used]
        primitive['attributes']={name:self.append(values,{1:'SCALAR',2:'VEC2',3:'VEC3',4:'VEC4'}[values.shape[1]]) for name,values in attrs.items()}
        primitive['indices']=self.append(new.reshape(-1,1),'SCALAR',5125,34963)
    def geometry_summary(self):
        parts={};points=[]
        for node in self.doc['nodes']:
            if 'mesh' not in node:continue
            count=0
            for p in self.primitives(node['name']):
                count+=len(self.view(p['indices']))//3;ix=np.unique(self.view(p['indices']));points.extend(self.positions(node['name'],p)[ix])
            parts[node['name']]=count
        a=np.array(points);return parts,a.min(axis=0),a.max(axis=0)
    def save(self,path):
        path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
        for i,buffer in enumerate(self.buffers):
            filename=path.stem+('' if i==0 else '_'+str(i))+'.bin';self.doc['buffers'][i].update(uri=filename,byteLength=len(buffer));(path.parent/filename).write_bytes(buffer)
        path.write_text(json.dumps(self.doc,indent=2)+'\n')
def components(points,triangles):
    """Weld equal positions for analysis only; never change the exported vertices."""
    parent=list(range(len(points)));seen={}
    def find(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for i,p in enumerate(points):
        key=tuple(np.round(p,5))
        if key in seen:parent[find(i)]=find(seen[key])
        else:seen[key]=i
    for tri in triangles:
        roots=[find(int(i)) for i in tri]
        for j in roots[1:]:parent[find(j)]=find(roots[0])
    groups={}
    for i in range(len(points)):groups.setdefault(find(i),[]).append(i)
    result=[]
    for inds in groups.values():
        p=points[inds];result.append(dict(indices=np.array(inds),lo=p.min(axis=0),hi=p.max(axis=0),centre=(p.min(axis=0)+p.max(axis=0))/2))
    return result
