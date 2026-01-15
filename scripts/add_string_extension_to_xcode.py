#!/usr/bin/env python3
"""
Script to add String+AudioFile.swift to the Xcode project.

This script safely adds the new extension file to project.pbxproj by:
1. Generating unique IDs for Xcode references
2. Adding PBXBuildFile entry
3. Adding PBXFileReference entry
4. Adding to Extensions group
5. Adding to Sources build phase
"""

import re
import sys
from pathlib import Path

def generate_xcode_id():
    """Generate a unique 24-character uppercase hex ID for Xcode."""
    import random
    return ''.join(random.choices('0123456789ABCDEF', k=24))

def add_file_to_project(pbxproj_path: Path, filename: str):
    """Add the file to the Xcode project."""
    
    # Read the project file
    content = pbxproj_path.read_text()
    
    # Generate unique IDs
    build_file_id = generate_xcode_id()
    file_ref_id = generate_xcode_id()
    
    print(f"Generated IDs:")
    print(f"  Build File: {build_file_id}")
    print(f"  File Ref:   {file_ref_id}")
    
    # 1. Add PBXBuildFile entry (after other extension files)
    build_file_pattern = r'(BA06811D2EFB013D0035F5B8 /\* Color\+MindSync\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = BA06810D2EFB013D0035F5B8 /\* Color\+MindSync\.swift \*/; \};)'
    build_file_entry = f'\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};'
    content = re.sub(build_file_pattern, r'\1\n' + build_file_entry, content)
    
    # 2. Add PBXFileReference entry (after other extension files)
    file_ref_pattern = r'(BA06810E2EFB013D0035F5B8 /\* View\+Gestures\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = "View\+Gestures\.swift"; sourceTree = "<group>"; \};)'
    file_ref_entry = f'\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{filename}"; sourceTree = "<group>"; }};'
    content = re.sub(file_ref_pattern, r'\1\n' + file_ref_entry, content)
    
    # 3. Add to Extensions group (children array)
    extensions_group_pattern = r'(/\* Extensions \*/ = \{\s+isa = PBXGroup;\s+children = \(\s+BA06810D2EFB013D0035F5B8 /\* Color\+MindSync\.swift \*/,)'
    extensions_group_entry = f'\n\t\t\t\t{file_ref_id} /* {filename} */,'
    content = re.sub(extensions_group_pattern, r'\1' + extensions_group_entry, content)
    
    # 4. Add to Sources build phase (after View+Gestures.swift)
    sources_pattern = r'(BA0681292EFB013D0035F5B8 /\* View\+Gestures\.swift in Sources \*/,)'
    sources_entry = f'\n\t\t\t\t{build_file_id} /* {filename} in Sources */,'
    content = re.sub(sources_pattern, r'\1' + sources_entry, content)
    
    # Write back
    pbxproj_path.write_text(content)
    print(f"\n✅ Successfully added {filename} to Xcode project!")
    print(f"\nNext steps:")
    print(f"  1. Open the project in Xcode to verify")
    print(f"  2. Build the project to confirm")

if __name__ == "__main__":
    project_root = Path(__file__).parent.parent
    pbxproj = project_root / "MindSync" / "MindSync.xcodeproj" / "project.pbxproj"
    
    if not pbxproj.exists():
        print(f"❌ Error: Could not find {pbxproj}", file=sys.stderr)
        sys.exit(1)
    
    # Create backup
    backup = pbxproj.with_suffix('.pbxproj.backup')
    backup.write_text(pbxproj.read_text())
    print(f"📋 Created backup: {backup}")
    
    try:
        add_file_to_project(pbxproj, "String+AudioFile.swift")
    except Exception as e:
        print(f"\n❌ Error: {e}", file=sys.stderr)
        print(f"Restoring from backup...", file=sys.stderr)
        pbxproj.write_text(backup.read_text())
        sys.exit(1)
