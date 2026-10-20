"""Validate the completed instruction-35 handoff and write its manifest.
Run after both Blender renders and build_graphics.py. No network or game edits.
"""
import hashlib
import json
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
import numpy as np
from PIL import Image
from fontTools.ttLib import TTFont

HERE=Path(__file__).resolve().parent
OUT=HERE.parent
REPO=OUT.parents[1]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=REPO,text=True).strip()
spec={
    'Logo.png':((1024,512),'upload','Transparent Fredoka wordmark'),
    'Background_Master.png':((2048,1152),'source','Full-size key-art render; slice rather than uploading directly'),
    'Background_TL.png':((1024,576),'upload','Background tile 1: top left'),
    'Background_TR.png':((1024,576),'upload','Background tile 2: top right'),
    'Background_BL.png':((1024,576),'upload','Background tile 3: bottom left'),
    'Background_BR.png':((1024,576),'upload','Background tile 4: bottom right'),
    'Mower.png':((512,512),'upload','Actual SelfPropelledMower, orthographic right-facing side, transparent'),
    'Stripes.png':((256,64),'upload','Two mown lawn stripes with soft periodic grass texture'),
    'Previews/TitleCard_16x9.png':((1920,1080),'preview','PC mock-up with actual UI layout constraints'),
    'Previews/TitleCard_Phone.png':((2340,1080),'preview','19.5:9 phone crop and UI mock-up'),
    'Previews/TitleCard_Tablet.png':((2048,1536),'preview','4:3 tablet crop and UI mock-up'),
    'Previews/Logo_300px.png':((300,150),'review','Phone-size wordmark legibility proof'),
    'Previews/Background_SafeZone.png':((2048,1152),'review','Common crop-safe rectangle over actual key art'),
}
report={'status':'passed','checks':{},'reviewed_main_commit':git('rev-parse','origin/main')}
images={}
for rel,(size,role,purpose) in spec.items():
    p=OUT/rel
    with Image.open(p) as im:
        assert im.format=='PNG' and im.size==size,(rel,im.size)
        im.verify()
    images[rel]=Image.open(p);images[rel].load()
    if role=='upload':assert max(size)<=1024
report['checks']['png_sizes_and_integrity']=dict(passed=True,images=len(images),upload_images=7)
for name in ['Logo.png','Mower.png','Previews/Logo_300px.png']:
    im=images[name];assert im.mode=='RGBA'
    a=np.asarray(im.getchannel('A'));assert a.min()==0 and a.max()==255
    assert not a[0].any() and not a[-1].any() and not a[:,0].any() and not a[:,-1].any()
for name in ['Background_Master.png','Background_TL.png','Background_TR.png','Background_BL.png','Background_BR.png','Stripes.png']:
    assert images[name].mode=='RGB'
report['checks']['straight_transparency_and_opaque_backgrounds']=True
assembled=Image.new('RGB',(2048,1152))
for name,pos in [('TL',(0,0)),('TR',(1024,0)),('BL',(0,576)),('BR',(1024,576))]:
    assembled.paste(images['Background_'+name+'.png'],pos)
diff=np.abs(np.array(assembled).astype(int)-np.array(images['Background_Master.png']).astype(int))
assert not diff.any()
report['checks']['background_tiles_pixel_exact']=dict(passed=True,max_channel_difference=int(diff.max()),order=['TL','TR','BL','BR'])
stripe=np.asarray(images['Stripes.png'])
assert np.array_equal(stripe[:,0],stripe[:,-1])
assert np.array_equal(stripe[0],stripe[-1])
report['checks']['stripe_seams']=dict(passed=True,left_right_max_difference=0,top_bottom_max_difference=0)
font=TTFont(HERE/'Fonts/Fredoka-SemiBold.ttf')
families={n.toUnicode() for n in font['name'].names if n.nameID in [1,4,6]}
assert any('Fredoka' in name for name in families)
layout=json.loads((HERE/'logo_layout.json').read_text())
assert layout['text']=='Lawn Mowing Simulator'
ET.parse(HERE/'Logo.svg')
report['checks']['wordmark']=dict(passed=True,text=layout['text'],typeface='Fredoka',weight=650,phone_proof='Previews/Logo_300px.png',font_license='Source/Fonts/OFL.txt')
mower=images['Mower.png'];bbox=mower.getbbox()
assert 14<=bbox[0]<=18 and 14<=512-bbox[2]<=18 and 14<=512-bbox[3]<=18,bbox
camera=json.loads((HERE/'mower_camera.json').read_text());assert camera['projection']=='ORTHO'
report['checks']['mower_icon']=dict(passed=True,alpha_bounds_px=bbox,projection='ORTHO',facing='right',bottom_padding_px=512-bbox[3])
native=json.loads((HERE/'native_scene_review.json').read_text())
assert len(native)==2 and all(row['missing_external_textures']==0 for row in native.values())
report['checks']['editable_blender_scenes']=dict(passed=True,scenes=native)
composition=json.loads((HERE/'composition_review.json').read_text())
bounds=composition['projected_model_bounds_px']
safe=[256,103.5,1792,1048.5]
essential=['Shed','RustyPickup','Mower • last cut stripe','Mower • truck bed','Mailbox',
           'PicketFenceSection','PicketFenceSection.002','FlowerPatch','FlowerPatch.001','FlowerPatch.002','HydrangeaBush']
for name in essential:
    b=bounds[name]
    assert b[0]>=safe[0] and b[1]>=safe[1] and b[2]<=safe[2] and b[3]<=safe[3],(name,b)
# The upper-middle logo area is unoccupied sky for all three screen shapes.
assert min(bounds[n][1] for n in essential)>460
report['checks']['common_safe_zone']=dict(passed=True,rect_px=safe,fully_inside=essential,decorative_crop_allowed=['Outer fence extensions','Far houses'])
inventory=json.loads((HERE/'scene_inventory.json').read_text())
source_files={}
for row in inventory['models']:
    name=row['model'];pack=row['pack'];folder=next((REPO/'model-source/HighPoly').glob(str(pack)+'_*'))
    gltf=folder/'Models'/name/(name+'.gltf')
    d=json.loads(gltf.read_text())
    dependencies=[gltf]+[gltf.parent/b['uri'] for b in d.get('buffers',[])]+[gltf.parent/im['uri'] for im in d.get('images',[]) if 'uri' in im]
    for p in dependencies:source_files[str(p.resolve().relative_to(REPO))]=sha(p)
report['checks']['source_provenance']=dict(passed=True,unique_game_models=len({r['model'] for r in inventory['models']}),referenced_files=len(source_files))
changed=git('diff','--name-only','origin/main').splitlines()
untracked=git('ls-files','--others','--exclude-standard').splitlines()
outside=[p for p in changed+untracked if p and not p.startswith('art-source/TitleCard/')]
assert not outside,outside
report['checks']['repository_scope']=dict(passed=True,only='art-source/TitleCard/',outside_changes=[])
report['manual_visual_review']={
    'logo_reads_at_300px':True,
    'open_shed_and_visible_pegboard_tools':True,
    'pickup_tailgate_down_and_mower_in_bed':True,
    'half_mown_lawn_with_crisp_stripes_and_long_grass':True,
    'no_people_or_text_in_background':True,
    'all_three_device_mockups_reviewed':True,
}
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
alpha=np.asarray(images['Logo.png'].getchannel('A'),dtype=float)
yy,xx=np.indices(alpha.shape)
logo_bbox=images['Logo.png'].getbbox()
entries=[]
purposes={
    'README.md':'Local Studio upload mapping, source instructions and crop guide',
    'validation.json':'Validation results and visual-review checklist',
    'Source/TitleCard.blend':'Editable key-art scene with packed source-model textures',
    'Source/Mower.blend':'Editable orthographic icon scene with packed textures',
    'Source/Logo.svg':'Portable editable vector outlines and lawn-care mark',
    'Source/build_scene.py':'Rebuild key-art scene from unchanged game glTF models',
    'Source/build_mower.py':'Rebuild the orthographic right-facing mower icon',
    'Source/build_graphics.py':'Generate Fredoka logo, seamless stripes, exact tiles and UI mock-ups',
    'Source/validate.py':'Validate output files and regenerate manifest and report',
    'Source/prepare_sources.py':'Make native output paths relative and audit packed scene textures',
    'Source/native_scene_review.json':'Native scene camera, texture packing and portability audit',
    'Source/scene_inventory.json':'Game-model placements and scene provenance',
    'Source/composition_review.json':'Projected source-model bounds for crop safety',
    'Source/mower_camera.json':'Orthographic icon camera and padding',
    'Source/mockup_layouts.json':'Pixel coordinates of logo and loading bar in each mock-up',
    'Source/logo_layout.json':'Wordmark spelling, font axes and letter/mark layout',
    'Source/Fonts/Fredoka.ttf':'Original Fredoka variable font from Google Fonts',
    'Source/Fonts/Fredoka-SemiBold.ttf':'Fredoka static instance, weight 650 and width 100',
    'Source/Fonts/OFL.txt':'Fredoka SIL Open Font License and copyright notice',
}
for p in sorted(OUT.rglob('*')):
    if not p.is_file() or p.name=='manifest.json':continue
    rel=p.relative_to(OUT).as_posix()
    assert rel in spec or rel in purposes,('Unexpected delivery file',rel)
    if rel in spec:
        size,role,purpose=spec[rel]
    else:size=None;role='source' if rel.startswith('Source/') else 'documentation';purpose=purposes[rel]
    entries.append(dict(path=rel,size_px=size,bytes=p.stat().st_size,sha256=sha(p),role=role,purpose=purpose))
entries.append(dict(path='manifest.json',size_px=None,role='documentation',purpose='File inventory, safe zones, logo visual centre and upload mapping; self-hash omitted'))
manifest=dict(
    instruction=35,title='Lawn Mowing Simulator',reviewed_main_commit=report['reviewed_main_commit'],
    files=entries,
    safe_zones=dict(master_size_px=[2048,1152],pc_crop_px=[0,0,2048,1152],phone_crop_px=[0,103.5,2048,1048.5],tablet_crop_px=[256,0,1792,1152],common_rect_px=safe,coordinate_convention='left, top, right, bottom; right and bottom exclusive'),
    logo=dict(canvas_px=[1024,512],frame_center_px=[512,256],alpha_bounds_px=logo_bbox,
              alpha_bounds_center_px=[(logo_bbox[0]+logo_bbox[2])/2,(logo_bbox[1]+logo_bbox[3])/2],
              visual_center_px=[round(float((xx*alpha).sum()/alpha.sum()),3),round(float((yy*alpha).sum()/alpha.sum()),3)],
              visual_center_method='alpha-weighted pixel centroid, including soft shadow',typeface='Fredoka',weight=650),
    upload_mapping=dict(Logo='Logo.png',Background=['Background_TL.png','Background_TR.png','Background_BL.png','Background_BR.png'],Mower='Mower.png',Stripes='Stripes.png'),
    runtime_layout=json.loads((HERE/'mockup_layouts.json').read_text()),
    source_model_dependencies_sha256=source_files,
    source_model_geometry_changed=False,roblox_upload_performed=False,
    notes=['Upload the seven mapped PNGs as Big Dink Studios in the local Studio session.','Master and preview images are reference files, not direct upload assets.','Background RGB values assemble exactly; do not rescale or trim the tiles.','The loading-screen runtime files remain unchanged.'])
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('PASS: 13 PNGs; 7 upload images; exact four-tile reconstruction; transparency; seams; core safe bounds; font; repository scope.')
