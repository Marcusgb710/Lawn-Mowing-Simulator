import sys,os,math,json,importlib,bpy,bmesh
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parent))
from core import *
number=37;module=importlib.import_module('build37')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
getattr(module,'build'+str(number))()
rows=[s for s in SPECS if s['instruction']==number];out=REPO/rows[0]['output_folder'];out.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
collection=bpy.data.collections.new('HIGH DETAIL '+str(number));scene.collection.children.link(collection)
used=sorted(set(c for a in ASSETS.values() for g in a.parts.values() for c in g.colors));N=8;tile=256;res=2048;assert len(used)<=N*N
palette={k:i for i,k in enumerate(used)};rng=np.random.default_rng(1024+number);texdir=out/'Textures';texdir.mkdir(exist_ok=True)
# New atlas surfaces: gentle paint variation, fine wood fibers and material-specific roughness.
images={}
for channel in ['Color','Roughness','Metalness','Normal']:
 arr=np.ones((res,res,4),dtype=np.float32)
 for key,idx in palette.items():
  x=idx%N*tile;y=idx//N*tile;kind=KINDS.get(key,'paint');noise=rng.normal(0,.004,(tile,tile));xx=np.arange(tile)[None,:];yy=np.arange(tile)[:,None]
  if kind=='wood':noise+=.032*np.sin(xx*.19+1.3*np.sin(yy*.018))+.009*np.sin(xx*.8+yy*.012)
  if kind in ['rubber','fabric','stone','soil']:noise+=rng.normal(0,.008,(tile,tile))
  m=material(key);p=m.node_tree.nodes.get('Principled BSDF')
  height=noise.copy()
  if kind=='pegboard':
   dx=((xx*47/tile+.5)%1-.5);dy=((yy*31/tile+.5)%1-.5);distance=np.sqrt(dx*dx+dy*dy);hole=distance<.11;rim=(distance>=.11)&(distance<.16);height-=np.clip((.16-distance)/.05,0,1)*.08
  if channel=='Color':
   rgb=np.array(COLORS[key],dtype=np.float32)/255;v=np.clip(rgb[None,None,:]*(1+noise[:,:,None]),0,1);
   if kind=='pegboard':v[hole]=np.array([.10,.075,.045]);v[rim]*=.82
  elif channel=='Normal':
   gy,gx=np.gradient(height);norm=np.dstack((-gx*8,-gy*8,np.ones_like(height)));norm/=np.linalg.norm(norm,axis=2)[:,:,None];v=norm*.5+.5
  else:
   value=p.inputs['Roughness' if channel=='Roughness' else 'Metallic'].default_value;v=np.repeat(np.clip(value+noise*.8 if channel=='Roughness' else np.full_like(noise,value),0,1)[:,:,None],3,axis=2)
  arr[y:y+tile,x:x+tile,:3]=v
 im=bpy.data.images.new(f'HP{number}_{channel}',width=res,height=res,alpha=False);im.colorspace_settings.name='sRGB' if channel=='Color' else 'Non-Color';im.pixels.foreach_set(arr.ravel());im.file_format='PNG';im.filepath_raw=str(texdir/f'HP{number}_{channel}.png');im.save();images[channel]=im
atlas=bpy.data.materials.new('HP shared PBR '+str(number));atlas.use_nodes=True;p=atlas.node_tree.nodes.get('Principled BSDF')
for channel,socket in [('Color','Base Color'),('Roughness','Roughness'),('Metalness','Metallic')]:
 n=atlas.node_tree.nodes.new('ShaderNodeTexImage');n.image=images[channel];atlas.node_tree.links.new(n.outputs['Color'],p.inputs[socket])

n=atlas.node_tree.nodes.new('ShaderNodeTexImage');n.image=images['Normal'];normal=atlas.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.45;atlas.node_tree.links.new(n.outputs['Color'],normal.inputs['Color']);atlas.node_tree.links.new(normal.outputs['Normal'],p.inputs['Normal'])

def chunks(g):
 if g.triangles<=19500:return [g]
 out=[];current=[];count=0
 # Components were authored independently; split only between complete closed components.
 for component in g.feature_components:
  if count+component['triangles']>19000 and current:out.append(current);current=[];count=0
  current.append(component);count+=component['triangles']
 if current:out.append(current)
 results=[]
 for idx,components in enumerate(out):
  ng=Geo(g.name if idx==0 else g.name.replace('__Body','__Details_'+str(idx)),g.origin,g.role)
  for comp in components:
   low,high=comp['vertices'];v=g.verts[low:high];uv=g.uvs[low:high]
   fi=[i for i,f in enumerate(g.faces) if low<=f[0]<high];ng.verts.extend(v);ng.uvs.extend(uv);start=len(ng.verts)-len(v)
   for i in fi:ng.faces.append(tuple(j-low+start for j in g.faces[i]));ng.colors.append(g.colors[i]);ng.smooth.append(g.smooth[i])
  results.append(ng)
 return results

manifest=[]
for spec in rows:
 a=ASSETS[spec['name']];a.fit();base=a.base;coll=bpy.data.collections.new(a.name);collection.children.link(coll)
 root=bpy.data.objects.new(a.name,None);coll.objects.link(root);root['folder']=spec['folder'];root['stud_to_meter']=S
 root['primary_part']=base['primary_part'];root['primary_position_studs']=[float(v) for v in base['primary_position_studs']]
 root['markers_json']=json.dumps(base['markers']+getattr(a,'extra_markers',[]));root['slots_json']=json.dumps(getattr(a,'new_slots',base['slots']))
 all_parts=[]
 for g in a.parts.values():
  if not g.verts:continue
  for geo in chunks(g):
   assert geo.triangles<=20000,(a.name,geo.name,geo.triangles)
   data=bpy.data.meshes.new(geo.name);data.from_pydata([C@(v-geo.origin)*S for v in geo.verts],[],geo.faces);data.update()
   obj=bpy.data.objects.new(geo.name,data);coll.objects.link(obj);obj.location=C@geo.origin*S;obj.parent=root
   glass=next((c for c in geo.colors if KINDS.get(c)=='glass'),None)
   data.materials.append(material('screen_gray') if geo.role=='screen' else material(glass) if glass else atlas)
   uv=data.uv_layers.new(name='UVMap')
   for i,poly in enumerate(data.polygons):
    poly.use_smooth=geo.smooth[i]
    idx=palette[geo.colors[i]]
    for loop in poly.loop_indices:
     uu,vv=geo.uvs[data.loops[loop].vertex_index];uv.data[loop].uv=((idx%N+(8+min(.999,max(0,uu))*240)/tile)/N,(idx//N+(8+min(.999,max(0,vv))*240)/tile)/N)
   bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(data);bm.free();data.update()
   bpy.context.view_layer.objects.active=obj
   mod=obj.modifiers.new('Weighted hard surface normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=50
   bpy.ops.object.modifier_apply(modifier=mod.name)
   # Triangulate once for both exchange formats and discard zero-area remnants
   # from collapsed cloth details. These faces have no visible surface area.
   bm=bmesh.new();bm.from_mesh(data);bmesh.ops.triangulate(bm,faces=list(bm.faces))
   bad=[f for f in bm.faces if f.calc_area()<1e-11]
   if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
   bm.to_mesh(data);bm.free();data.update();data.calc_loop_triangles();actual_triangles=len(data.loop_triangles)
   obj['role']=geo.role;obj['animation_axis']=getattr(geo,'animation_axis',None) or ('X' if '__Wheel' in obj.name or geo.role in ['tailgate','ramp'] else 'Y' if any(t in obj.name for t in ['__CutterRotor','__Spool']) or geo.role.startswith('hinged_door') or geo.role=='rear_door' else '');obj['stud_origin']=list(geo.origin)
   obj['can_collide']=geo.role.startswith('collision_') or spec['folder'] in ['Trucks','Trailers']
   obj['collision_fidelity']='Hull' if geo.role.startswith('collision_') or geo.role in ['wheel','ramp','tailgate'] else 'PreciseConvexDecomposition' if spec['folder'] in ['Trucks','Trailers'] else 'Default'
   if hasattr(geo,'moves_with'):obj['moves_with']=geo.moves_with
   obj['motion_mode']='TranslateY' if geo.role in ['rear_door','garage_door'] else 'Rotate' if obj['animation_axis'] else ''
   all_parts.append(dict(name=obj.name,triangles=actual_triangles,origin_studs=list(geo.origin),role=geo.role,can_collide=obj['can_collide'],collision_fidelity=obj['collision_fidelity'],animation_axis=obj['animation_axis'],motion_mode=obj['motion_mode'],moves_with=getattr(geo,'moves_with',None)))
 # Named attachment empties are actual children of their specified collision floor/worktop mesh.
 for idx,mark in enumerate(getattr(a,'extra_markers',[])):
  attachment=bpy.data.objects.new(mark['name'],None);coll.objects.link(attachment);parent=bpy.data.objects.get(mark['parent_mesh']);assert parent is not None,mark
  attachment.parent=parent;attachment.location=C@(Vector(mark['position_studs'])-Vector(parent['stud_origin']))*S
  orient=R(*mark['orientation_degrees']);attachment.rotation_euler=(C@orient@CI).to_euler()
  attachment['roblox_class']='Attachment';attachment['roblox_name']=mark['name'];attachment['attributes_json']=json.dumps(mark['attributes']);attachment['parent_mesh']=mark['parent_mesh']
  for key,value in mark['attributes'].items():attachment[key]=value
 lo,hi=a.bounds();tris=sum(p['triangles'] for p in all_parts);budget=budget_for(spec)[1]
 assert tris<=budget,(a.name,tris,budget)
 row=dict(name=a.name,folder=spec['folder'],instruction=number,triangle_budget=budget,detail_guidance_min=budget_for(spec)[0],dimensions_studs=[round(v,6) for v in hi-lo],bounds_min_studs=list(lo),bounds_max_studs=list(hi),primary_part=base['primary_part'],primary_position_studs=base['primary_position_studs'],markers=base['markers']+getattr(a,'extra_markers',[]),slots=getattr(a,'new_slots',base['slots']),triangles=tris,mesh_objects=len(all_parts),parts=all_parts,features=a.features,baseline_source_pack=base['source_pack'],baseline_triangles=base['triangles'],authoring_fit=a.placement_transform,size_exception_limits_studs=getattr(a,'size_limits',None),studio_import_tested=False)
 manifest.append(row)
 if '--models' in sys.argv and a.name not in sys.argv[sys.argv.index('--models')+1].split(','):continue
 target=out/'Models'/a.name;target.mkdir(parents=True,exist_ok=True)
 bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
 for obj in coll.objects:obj.select_set(True)
 bpy.context.view_layer.objects.active=root
 bpy.ops.export_scene.gltf(filepath=str(target/(a.name+'.gltf')),export_format='GLTF_SEPARATE',use_selection=True,export_texture_dir='../../Textures',export_yup=True,export_cameras=False,export_lights=False,export_extras=True)
 bpy.ops.export_scene.fbx(filepath=str(target/(a.name+'.fbx')),use_selection=True,object_types={'MESH','EMPTY'},apply_unit_scale=True,add_leaf_bones=False,bake_anim=False,axis_forward='-Z',axis_up='Y',path_mode='RELATIVE',use_custom_props=True)
 docpath=target/(a.name+'.gltf');doc=json.loads(docpath.read_text())
 for node in doc['nodes']:
  if node.get('extras',{}).get('roblox_class')=='Attachment':node['name']=node['extras']['roblox_name']
 docpath.write_text(json.dumps(doc,indent=2))
 print('EXPORTED',a.name,tris,len(all_parts),flush=True)
# Every library root has only a translation, with no rotation or scale.
cols=math.ceil(math.sqrt(len(rows)));stepx=(max(r['bounds_max_studs'][0] for r in manifest)-min(r['bounds_min_studs'][0] for r in manifest))*S+1.5;stepy=(max(r['bounds_max_studs'][2] for r in manifest)-min(r['bounds_min_studs'][2] for r in manifest))*S+1.5
for i,row in enumerate(manifest):
 root=bpy.data.objects[row['name']];root.location=(i%cols*stepx,i//cols*stepy,0);row['library_translation_meters']=list(CI@root.location)
bpy.ops.object.select_all(action='DESELECT')
for coll in collection.children:
 for obj in coll.objects:obj.select_set(True)
allout=out/'ALL';allout.mkdir(exist_ok=True);library_name=out.name
bpy.ops.export_scene.gltf(filepath=str(allout/(library_name+'.gltf')),export_format='GLTF_SEPARATE',use_selection=True,export_texture_dir='../Textures',export_yup=True,export_cameras=False,export_lights=False,export_extras=True)
docpath=allout/(library_name+'.gltf');doc=json.loads(docpath.read_text())
for node in doc['nodes']:
 if node.get('extras',{}).get('roblox_class')=='Attachment':node['name']=node['extras']['roblox_name']
docpath.write_text(json.dumps(doc,indent=2))
(out/'model_manifest.json').write_text(json.dumps(dict(assets=manifest,meters_per_stud=S,source_main_commit='c6a01d3',original_packs_preserved=True,studio_import_tested=False),indent=2))
for im in images.values():im.pack();im.filepath='//Textures/'+Path(im.filepath).name
# Retain the editable native source alongside the portable exports.
scene['output_folder']=str(out);bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'Story.blend'),compress=True)
print('PACK COMPLETE',number,len(manifest),flush=True)
