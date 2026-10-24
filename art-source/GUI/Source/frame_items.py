"""Frame true projected silhouettes at 80%, preserving the original studio PNGs.

The render camera initially fits mesh bounding boxes. For curved and diagonal
objects those boxes contain empty corners. This geometric affine crop uses the
actual serialized vertices, including transparent pieces, rather than shadows.
"""
from pathlib import Path
import json,itertools,sys
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;REPO=OUT.parents[1]
C=np.array([[1,0,0],[0,0,-1],[0,1,0]],dtype=float)
forward=np.array([6,-9,-5],dtype=float);forward/=np.linalg.norm(forward)
right=np.cross(forward,[0,0,1]);right/=np.linalg.norm(right);up=np.cross(right,forward)
def matrix(n):
    if 'matrix' in n:return np.array(n['matrix']).reshape(4,4).T
    x,y,z,w=n.get('rotation',[0,0,0,1]);m=np.eye(4)
    m[:3,:3]=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])@np.diag(n.get('scale',[1,1,1]))
    m[:3,3]=n.get('translation',[0,0,0]);return m
def picture_bounds(path):
    d=json.loads(path.read_text());buffers=[(path.parent/b['uri']).read_bytes() for b in d['buffers']];matrices={}
    def walk(i,parent):
        matrices[i]=parent@matrix(d['nodes'][i])
        for j in d['nodes'][i].get('children',[]):walk(j,matrices[i])
    for i in d['scenes'][d.get('scene',0)]['nodes']:walk(i,np.eye(4))
    clouds=[];boxes=[]
    for i,n in enumerate(d['nodes']):
        if 'mesh' not in n or i not in matrices:continue
        verts=[]
        for p in d['meshes'][n['mesh']]['primitives']:
            a=d['accessors'][p['attributes']['POSITION']];v=d['bufferViews'][a['bufferView']]
            assert a['componentType']==5126
            verts.append(np.ndarray((a['count'],3),dtype='<f4',buffer=buffers[v['buffer']],offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',12),4)).copy())
        points=np.concatenate(verts);lo=points.min(axis=0);hi=points.max(axis=0)
        corners=np.array(list(itertools.product(*zip(lo,hi))))
        world=(np.c_[points,np.ones(len(points))]@matrices[i].T)[:,:3]@C.T
        box=(np.c_[corners,np.ones(8)]@matrices[i].T)[:,:3]@C.T
        clouds.append(world);boxes.append(box)
    points=np.concatenate(clouds);box=np.concatenate(boxes);lo=box.min(axis=0);hi=box.max(axis=0)
    factor=2.7/max(hi-lo);translation=-(lo+hi)/2*factor+np.array([0,0,(hi[2]-lo[2])*factor/2])
    points=points*factor+translation;box=box*factor+translation
    axes=np.stack([right,up],axis=1);a=points@axes;b=box@axes
    centre=(b.min(axis=0)+b.max(axis=0))/2;scale=max(b.max(axis=0)-b.min(axis=0))/.8
    pix=(a-centre)/scale*512;pix[:,0]+=256;pix[:,1]=256-pix[:,1]
    return [float(pix[:,0].min()),float(pix[:,1].min()),float(pix[:,0].max()),float(pix[:,1].max())]
def main():
    raw=HERE/'ItemRenders';raw.mkdir(exist_ok=True)
    selected=set(sys.argv[sys.argv.index('--only')+1].split(',')) if '--only' in sys.argv else None
    review_path=HERE/'item_framing.json';records=json.loads(review_path.read_text()) if review_path.exists() else []
    for row in json.loads((HERE/'items.json').read_text()):
        name=row['id']
        if selected and name not in selected:continue
        source=raw/(name+'.png');dest=OUT/'Items'/(name+'.png')
        if '--capture-raw' in sys.argv or not source.exists():source.write_bytes(dest.read_bytes())
        bounds=picture_bounds(REPO/row['path']);x0,y0,x1,y1=bounds
        scale=.8*512/max(x1-x0,y1-y0);tx=256-scale*(x0+x1)/2;ty=256-scale*(y0+y1)/2
        with Image.open(source) as image:
            result=image.convert('RGBa').transform((512,512),Image.Transform.AFFINE,(1/scale,0,-tx/scale,0,1/scale,-ty/scale),resample=Image.Resampling.BICUBIC).convert('RGBA')
            result.save(dest)
        record=dict(id=name,raw_source='Source/ItemRenders/'+name+'.png',source_projection_bounds_px=bounds,uniform_scale=scale,translation_px=[tx,ty],final_longest_projection_fraction=.8,view_unchanged=True,lighting_unchanged=True)
        records=[r for r in records if r['id']!=name]+[record]
    review_path.write_text(json.dumps(records,indent=2)+'\n');print('Framed',len(records),'item pictures from actual model vertex projections.')
if __name__=='__main__':main()
