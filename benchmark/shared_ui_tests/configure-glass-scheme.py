from pathlib import Path
import os,sys,xml.etree.ElementTree as ET
if os.environ.get('EROS_VERIFY_GLASS') != '1':
    raise SystemExit(0)
scheme=Path(sys.argv[1]).resolve()
root=Path(__file__).resolve().parents[2]
assert not scheme.is_relative_to(root), 'Generated scheme must be outside the checkout'
assert scheme.name == 'CustomBranchAcceptance.xcscheme'
tree=ET.parse(scheme);action=tree.getroot().find('TestAction');assert action is not None
action.set('shouldUseLaunchSchemeArgsEnv','NO')
envs=action.find('EnvironmentVariables')
if envs is None:envs=ET.SubElement(action,'EnvironmentVariables')
item=next((e for e in envs if e.get('key')=='EROS_VERIFY_GLASS'),None)
if item is None:item=ET.SubElement(envs,'EnvironmentVariable')
item.attrib.update(key='EROS_VERIFY_GLASS',value='1',isEnabled='YES')
tree.write(scheme,encoding='UTF-8',xml_declaration=True)
