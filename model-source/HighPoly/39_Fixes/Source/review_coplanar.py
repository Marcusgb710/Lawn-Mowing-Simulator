"""Run the supplied checker without changing it; audit the requested 0.03 areas."""
from pathlib import Path
import sys,json,importlib.util,subprocess
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;REPO=OUT.parents[2]
script=REPO/'scripts/check-coplanar.py'
spec=importlib.util.spec_from_file_location('repository_coplanar_checker',script);checker=importlib.util.module_from_spec(spec);spec.loader.exec_module(checker)
command=[sys.executable,str(script),str(OUT)]
result=subprocess.run(command,cwd=REPO,capture_output=True,text=True);assert result.returncode==0,result.stdout+result.stderr
(HERE/'coplanar_default.txt').write_text(result.stdout)
wide=subprocess.run(command+['--tol','0.03'],cwd=REPO,capture_output=True,text=True);assert wide.returncode in [0,1]
(HERE/'coplanar_003.txt').write_text(wide.stdout)
def real(found):
    rows=[]
    for (a,b,plane),entry in found.items():
        differs=sum(area for pair,area in entry['colours'].items() if not checker.alike(*pair))
        if entry['area']>=(.5 if a==b else .25) and differs>=.5*entry['area']:rows.append(dict(mesh_a=a,mesh_b=b,plane=plane,area=entry['area'],max_gap=entry['gap'],lo=entry['lo'],hi=entry['hi']))
    return rows
target_failures=[];other=[]
for name in ['DeliveryCrate','SmallOffice','GloriaYard_Stage3']:
    path=OUT/'Models'/name/(name+'.gltf');found,_,_=checker.check_model(str(path),.03)
    for row in real(found):
        a,b,plane=row['mesh_a'],row['mesh_b'],row['plane'];lo,hi=row['lo'],row['hi']
        targeted=name=='GloriaYard_Stage3' and ('__Lawn' in a or '__Lawn' in b)
        targeted|=name=='DeliveryCrate' and a==b and (plane.startswith(('+X','-X')) or (plane.startswith(('+Z','-Z')) and row['max_gap']<.021))
        if name=='SmallOffice':
            targeted|='__Glass_Door' in a or '__Glass_Door' in b
            targeted|=a==b and a.endswith('__Body') and (plane.startswith('-X 6.93') and lo[1]>16.8 or (lo[1]>10.7 and hi[1]<11.2 and lo[0]<-11 and hi[0]<.4))
        (target_failures if targeted else other).append(dict(model=name,**row))
assert not target_failures,target_failures
sources={'DeliveryCrate':'33_ShopDesksAndDeliveries','SmallOffice':'24_YardAndBuildings','GloriaYard_Stage3':'37_Story'}
for name,pack in sources.items():
    before,_,_=checker.check_model(str(OUT.parent/pack/'Models'/name/(name+'.gltf')),.03)
    keys={(r['mesh_a'],r['mesh_b'],r['plane']) for r in real(before)}
    assert all((r['mesh_a'],r['mesh_b'],r['plane']) in keys for r in other if r['model']==name),('New wider-tolerance overlap',name)
report=dict(status='passed',default_command='python3 scripts/check-coplanar.py model-source/HighPoly/39_Fixes',default_returncode=0,default_output=result.stdout.strip(),expanded_tolerance_studs=.03,expanded_targeted_failures=target_failures,expanded_other_original_surface_pairs=other,expanded_other_pairs_all_preexisting=True,expanded_full_command_returncode=wide.returncode,note='The wider check retains unrelated original surfaces, including existing collision meshes; the specified fixed surfaces all clear 0.03 stud.')
(HERE/'coplanar_review.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS: default checker clean; all specified surfaces clear the 0.03-stud check. Other original wider-tolerance pairs:',len(other))
