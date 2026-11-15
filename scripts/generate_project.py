#!/usr/bin/env python3
"""Generate a dependency-free iOS Xcode project (no XcodeGen needed)."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[1]
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def q(s): return '"'+s+'"'
objects=[]
def obj(name, body): objects.append(f'{uid(name)} = {{ {body} }};'); return uid(name)
swifts=sorted((root/'HanziSprout').glob('*.swift'))
refs=[]; builds=[]
for path in swifts:
 refs.append(obj(path.name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(path.name)}; sourceTree = "<group>";'))
 builds.append(obj('build'+path.name, f'isa = PBXBuildFile; fileRef = {uid(path.name)};'))
resources=obj('resources','isa = PBXFileReference; lastKnownFileType = folder; path = Resources; sourceTree = "<group>";')
rbuild=obj('resourcebuild',f'isa = PBXBuildFile; fileRef = {resources};')
product=obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = HanziSprout.app; sourceTree = BUILT_PRODUCTS_DIR;')
sourcegroup=obj('sourcegroup',f'isa = PBXGroup; children = ({",".join(refs+[resources])},); path = HanziSprout; sourceTree = "<group>";')
products=obj('products',f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
main=obj('main',f'isa = PBXGroup; children = ({sourcegroup},{products},); sourceTree = "<group>";')
sources=obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
resourcephase=obj('resourcephase',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({rbuild},); runOnlyForDeploymentPostprocessing = 0;')
frameworks=obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
projectconfigs=[]; targetconfigs=[]
for config in ['Debug','Release']:
 projectconfigs.append(obj('project'+config,f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{ SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 16.0; CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; }};'))
 settings='''PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = com.ningfeng.HanziSprout; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = HanziSprout/Info.plist; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; ENABLE_USER_SCRIPT_SANDBOXING = NO; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 1.0; SWIFT_EMIT_LOC_STRINGS = YES;'''
 if config=='Debug': settings+=' SWIFT_OPTIMIZATION_LEVEL = "-Onone";'
 targetconfigs.append(obj('target'+config,f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{{settings}}};'))
pc=obj('pc',f'isa = XCConfigurationList; buildConfigurations = ({",".join(projectconfigs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
tc=obj('tc',f'isa = XCConfigurationList; buildConfigurations = ({",".join(targetconfigs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
prepare=obj('prepare', 'isa = PBXShellScriptBuildPhase; buildActionMask = 2147483647; files = (); inputPaths = (); outputPaths = (); runOnlyForDeploymentPostprocessing = 0; shellPath = /bin/sh; shellScript = \"/bin/sh \\\"$SRCROOT/scripts/prepare_data.sh\\\"\";')
target=obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {tc}; buildPhases = ({prepare},{sources},{frameworks},{resourcephase},); buildRules = (); dependencies = (); name = HanziSprout; productName = HanziSprout; productReference = {product}; productType = "com.apple.product-type.application";')
project=obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; TargetAttributes = {{ {target} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh_CN; hasScannedForEncodings = 0; knownRegions = (zh_CN,en,Base,); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
folder=root/'HanziSprout.xcodeproj'; folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
scheme=folder/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
(scheme/'HanziSprout.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="HanziSprout.app" BlueprintName="HanziSprout" ReferencedContainer="container:HanziSprout.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="HanziSprout.app" BlueprintName="HanziSprout" ReferencedContainer="container:HanziSprout.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print('Generated',folder)
