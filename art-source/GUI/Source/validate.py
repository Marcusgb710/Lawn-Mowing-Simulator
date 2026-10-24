"""Validate instruction 38's complete art handoff and write manifest.json."""
from design import *
import hashlib,string,subprocess,xml.etree.ElementTree as ET
from fontTools.ttLib import TTFont
REPO=OUT.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=REPO,text=True).strip()
items=json.loads((HERE/'items.json').read_text());portraits=json.loads((HERE/'portraits.json').read_text());slices=json.loads((HERE/'slices.json').read_text());glyphs=json.loads((HERE/'glyphs.json').read_text());words=json.loads((HERE/'wordmarks.json').read_text());fonts=json.loads((HERE/'font_spec.json').read_text())
report={'status':'passed','checks':{}}
assert len(items)==127 and len({r['id'] for r in items})==127
assert {p.stem for p in (OUT/'Items').glob('*.png')}=={r['id'] for r in items}
assert len(portraits)==19 and {p.stem for p in (OUT/'Portraits').glob('*.png')}=={r['id'] for r in portraits}
assert len(glyphs)==60 and {p.stem for p in (OUT/'Icons').glob('*.png')}==set(glyphs)
assert len(slices)==56 and len(words)==14
report['checks']['required_counts']=dict(items=127,portraits=19,glyphs=60,kit_including_taskbar=56,wordmarks=14)
for folder,size,mode in [('Items',(512,512),'RGBA'),('Portraits',(512,512),'RGB'),('Icons',(128,128),'RGBA')]:
    for p in (OUT/folder).glob('*.png'):
        with Image.open(p) as im:
            assert im.size==size and im.mode==mode,(p.name,im.size,im.mode);im.verify()
for p in (OUT/'Icons').glob('*.png'):
    a=np.array(Image.open(p));assert (a[a[:,:,3]>0,:3]==255).all(),p.name
for p in (HERE/'GlyphSVG').glob('*.svg'):
    root=ET.parse(p).getroot();assert not any(node.tag.endswith('text') for node in root.iter())
report['checks']['white_tintable_glyphs_and_vector_sources']=True
for name,row in slices.items():
    with Image.open(OUT/row['file']) as probe:probe.verify()
    with Image.open(OUT/row['file']) as im:
        assert list(im.size)==row['size_px'] and im.mode=='RGBA';assert im.getchannel('A').getextrema()[0]==0 or name.startswith(('ProgressFill','ScoreFill'))
        if row['slice_center_px']:
            l,t,r,b=row['slice_center_px'];assert 0<=l<r<=im.width and 0<=t<b<=im.height
for name,size in [('TouchButton',256),('TouchButton_Small',192),('HoldRing',256),('HoldRing_Fill',256),('PortraitRing',256),('Reticle',64),('Reticle_Active',64),('Reticle_Blocked',64)]:assert Image.open(OUT/'Kit'/(name+'.png')).size==(size,size)
for name in ['ProgressFill','ProgressFill_Money','ProgressFill_TurfKing','ScoreFill_You','ScoreFill_Rival']:
    a=np.array(Image.open(OUT/'Kit'/(name+'.png')));assert np.array_equal(a[:,0],a[:,-1])
report['checks']['nine_slice_bounds_transparency_and_periodic_progress_tiles']=True
font_reports=[]
for name,required in [('Display_Numbers','0123456789$,.+−%/:×R'),('Display_Headline',string.ascii_uppercase+string.ascii_lowercase+string.digits+".,!?'’\"-–:;&()#/$%")]:
    face=json.loads((OUT/'Fonts'/(name+'.fnt')).read_text());border=json.loads((OUT/'Fonts'/(name+'_Outline.fnt')).read_text())
    assert face['chars']==border['chars'] and face['kernings']==border['kernings']
    table={g['id']:g for g in face['chars']};assert set(map(ord,required))<=set(table)
    for g in table.values():assert g['x']>=0 and g['y']>=0 and g['x']+g['width']<=1024 and g['y']+g['height']<=1024
    for doc in [face,border]:
        assert doc['common']['lineHeight']>doc['common']['base']>0
        assert Image.open(OUT/'Fonts'/doc['pages'][0]).size==(1024,1024)
    a=np.array(Image.open(OUT/'Fonts'/face['pages'][0]));assert (a[a[:,:,3]>0,:3]==255).all()
    if name=='Display_Numbers':assert len({table[ord(c)]['xadvance'] for c in string.digits})==1
    else:assert face['kernings']
    font_reports.append(dict(font=name,glyph_count=len(table),kerning_pairs=len(face['kernings']),matching_layers=True))
assert Image.open(OUT/'Fonts/Specimen.png').size==(2048,1024)
assert fonts['live_heading']['roblox_family']=='DenkOne' and fonts['live_body']['roblox_family']=='Nunito'
for name in ['LilitaOne-Regular.ttf','DenkOne-Regular.ttf','Nunito_wght.ttf']:TTFont(OUT/'Fonts/Source'/name)
assert all((OUT/'Fonts/Source'/n).exists() for n in ['lilitaone-OFL.txt','denkone-OFL.txt','nunito-OFL.txt'])
report['checks']['bitmap_fonts']=font_reports
expected_frames={n:(2340,1080) if n.endswith('_Phone') else (2048,2048) if n=='Sheet' else (1920,1080) for n in ['HUD_PC','HUD_Phone','Computer_Jobs','Computer_Orders','Computer_Premium','Computer_Messages','Dialogue_PC','Dialogue_Phone','PayBreakdown','BestYard','Sheet']}
layouts=json.loads((HERE/'frame_layouts.json').read_text());assert set(layouts)==set(expected_frames)
for name,size in expected_frames.items():
    style=OUT/'StyleFrames'/(name+'.png');preview=OUT/'Previews'/(name+'.png');half=OUT/'Previews'/(name+'_50pct.png')
    assert Image.open(style).size==size and sha(style)==sha(preview)
    assert Image.open(half).size==(size[0]//2,size[1]//2)
    for r in layouts[name]:
        x,y,w,h=r['rect_px'];assert x>=0 and y>=0 and x+w<=size[0] and y+h<=size[1],(name,r)
        assert (OUT/r['asset']).exists()
        if name.endswith('_Phone') and r['asset'].startswith('Kit/Button_'):assert h>=88
report['checks']['eleven_frames_and_matching_previews']=True
report['checks']['fifty_percent_phone_review_files']=True
framing=json.loads((HERE/'item_framing.json').read_text());assert len(framing)==127 and {r['id'] for r in framing}=={r['id'] for r in items}
assert all(r['final_longest_projection_fraction']==.8 and r['view_unchanged'] and r['lighting_unchanged'] for r in framing)
report['checks']['actual_model_silhouette_framing']=dict(passed=True,items=127,longest_dimension_fraction=.8)
render_review={r['id']:r for r in json.loads((HERE/'item_render_review.json').read_text())}
paint_ids=['RacingRed','MidnightBlack','ForestGreen','SkyBlue','StealthWrap','ChromeWrap','GoldWrap']
for name in paint_ids:assert render_review[name]['painted_faces']>2000,(name,'body-panel paint mask')
assert len({sha(OUT/'Items'/(name+'.png')) for name in paint_ids})==7
report['checks']['seven_distinct_pickup_finishes_with_body_panel_masks']=True
for n in ['Jobs','Orders','Business','Crew','Messages']:assert Image.open(OUT/'Computer'/('App_'+n+'.png')).size==(256,256)
assert Image.open(OUT/'Computer/Wallpaper.png').size==(1024,576)
for name,size in [('Trophy',(1024,1024)),('Confetti',(1024,1024)),('Sparkle',(256,256))]:
    im=Image.open(OUT/'Moments'/(name+'.png'));assert im.size==size and im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
for name,columns,rows in [('Confetti',4,4),('Sparkle',2,2)]:
    im=Image.open(OUT/'Moments'/(name+'.png'))
    for y in range(rows):
        for x in range(columns):assert im.crop((x*im.width//columns,y*im.height//rows,(x+1)*im.width//columns,(y+1)*im.height//rows)).getbbox()
report['checks']['computer_and_moment_assets']=True
products=[r['id'] for r in items if r['finish'] is not None];assert len(products)==13
store_expected={'GameIcon',*[f'Thumbnail_{i}' for i in range(1,6)],'Pass_DiamondBlades','Pass_RunFlatTires','Pass_EndlessSpool','Pass_BigTank',*products}
assert {p.stem for p in (OUT/'Store').glob('*.png')}==store_expected
for p in (OUT/'Store').glob('*.png'):assert Image.open(p).size==((1920,1080) if p.stem.startswith('Thumbnail_') else (512,512))
report['checks']['store_art']=dict(game_icons=1,thumbnails=5,passes=4,products=13)
def luminance(c):
    v=np.array(rgb(c))/255;v=np.where(v<=.04045,v/12.92,((v+.055)/1.055)**2.4);return float(v@np.array([.2126,.7152,.0722]))
pairs=[('text','panel'),('text','card'),('subtext','card'),('text','primary_face'),('text','danger_face'),('text','disabled'),('subtext','locked_card'),('ink','money'),('ink','grandma'),('ink','gold')]
contrasts=[]
for foreground,background in pairs:
    a,b=sorted([luminance(P[foreground]),luminance(P[background])]);ratio=(b+.05)/(a+.05);assert ratio>=4.5,(foreground,background,ratio)
    contrasts.append(dict(foreground=foreground,background=background,ratio=round(ratio,3)))
report['checks']['text_contrast']=contrasts
upload_folders={'Kit','Icons','Items','Portraits','Wordmarks','Computer','Moments','Fonts'}
for folder in upload_folders:
    for p in (OUT/folder).glob('*.png'):
        if p.name=='Specimen.png':continue
        with Image.open(p) as im:assert max(im.size)<=1024;im.verify()
report['checks']['upload_png_size_cap']=1024
for n in ['Items_ContactSheet.png','Portraits_ContactSheet.png','Glyphs_32px.png']:assert (OUT/'Previews'/n).is_file()
allowed=('art-source/GUI/','model-source/HighPoly/37_Story/')
paths=git('diff','--name-only','origin/main').splitlines()+git('ls-files','--others','--exclude-standard').splitlines()
outside=[p for p in paths if p and not p.startswith(allowed)];assert not outside,outside
report['checks']['only_authorized_folders_changed']=list(allowed)
report['manual_review']=dict(no_text_in_kit_glyphs_or_item_pictures=True,all_19_portrait_identities_and_expressions_reviewed=True,all_11_screens_reviewed_at_full_and_half_size=True,no_robux_symbol_drawn=True,original_kit_and_existing_models_preserved=True)
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
files=[];item_ids={r['id'] for r in items};portrait_ids={r['id'] for r in portraits}
purposes={'Kit':'Text-free 2x UI piece; see slice_centers for scaling','Icons':'White tintable 128px glyph, readable at 32px','Items':'Actual model studio picture, common camera and light, transparent','Portraits':'Painted story portrait with circular-crop-safe face','Computer':'Shop desktop art','Moments':'Big moment artwork or sprite sheet','Store':'Roblox page or purchase art','Wordmarks':'Outlined Lilita One lettering, transparent','StyleFrames':'Finished Maple Grove Summer screen composition','Previews':'Review image or contact sheet','Fonts':'Layered bitmap font, specimen or licensed font source','Source':'Editable/reproducible authoring source'}
for p in sorted(OUT.rglob('*')):
    if not p.is_file() or p.name=='manifest.json' or '__pycache__' in p.parts or p.suffix=='.blend1':continue
    rel=p.relative_to(OUT).as_posix();folder=rel.split('/')[0];entry=dict(path=rel,bytes=p.stat().st_size,sha256=sha(p),purpose=purposes.get(folder,'Handoff documentation'),role='authoring_source' if folder=='Source' else 'review' if folder in ['StyleFrames','Previews'] or p.name=='Specimen.png' else 'font_source' if 'Source' in p.parts else 'upload' if folder in upload_folders or folder=='Store' else 'documentation')
    if p.suffix.lower()=='.png':
        with Image.open(p) as im:entry.update(size_px=list(im.size),mode=im.mode);im.verify()
    else:entry['size_px']=None
    if p.suffix=='.fnt':entry['role']='runtime_metadata'
    if folder=='Items':entry['item_id']=p.stem
    if folder=='Portraits':entry['portrait_id']=p.stem
    if folder=='Store':entry['store_id']=p.stem.removeprefix('Pass_')
    files.append(entry)
files.append(dict(path='manifest.json',size_px=None,role='documentation',purpose='This inventory; self-hash intentionally omitted'))
manifest=dict(schema_version=1,instruction=38,replaces_instruction=36,art_direction='Maple Grove Summer',reviewed_main_commit=git('rev-parse','origin/main'),files=files,palette=P,typography=fonts,slice_centers=slices,bitmap_font_files=fonts['bitmap_fonts'],sprite_sheets=json.loads((HERE/'sprite_sheets.json').read_text()),item_ids=[r['id'] for r in items],portrait_ids=[r['id'] for r in portraits],store_products=products,contrast_pairs=contrasts,portrait_mask=dict(frame_size_px=[256,256],inner_circle_size_px=[208,208],inner_offset_px=[24,24]),local_integration=dict(account='Big Dink Studios',uploads_performed=False,runtime_changes_performed=False,images_not_uploadable_as_font_files=True))
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('PASS: GUI kit, 60 glyphs, 127 item pictures, 19 portraits, fonts, 14 wordmarks, 11 frames, moments, store art, contrast and repository scope.')
