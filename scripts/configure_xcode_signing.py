#!/usr/bin/env python3
"""
Configure Xcode project for CI code signing.
Safely modifies the project.pbxproj file to use manual signing with the correct team ID.
"""

import re
import os
import shutil
import sys
from pathlib import Path


def main() -> None:
    project_file = Path("macos/Runner.xcodeproj/project.pbxproj")
    backup_file = project_file.with_suffix(".pbxproj.backup")

    if not project_file.exists():
        print(f"❌ Project file not found: {project_file}")
        sys.exit(1)

    # Get team ID from environment
    team_id = os.environ.get("APPLE_TEAM_ID")
    if not team_id:
        print("❌ APPLE_TEAM_ID environment variable not set")
        sys.exit(1)

    print("⚙️ Configuring Xcode project for CI signing...")
    print(f"Team ID: {team_id}")

    try:
        # Create backup
        print("💾 Creating backup...")
        _ = shutil.copy2(project_file, backup_file)

        # Read project file
        with open(project_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Show original settings
        print("📋 Original settings:")
        for line in content.split("\n"):
            if any(
                setting in line
                for setting in [
                    "CODE_SIGN_STYLE",
                    "DEVELOPMENT_TEAM",
                    "CODE_SIGN_IDENTITY",
                ]
            ):
                print(f"  {line.strip()}")
                break

        # Make replacements
        original_content = content
        content = re.sub(
            r"DEVELOPMENT_TEAM = 2KQDYWP72S;", f"DEVELOPMENT_TEAM = {team_id};", content
        )
        content = re.sub(
            r"CODE_SIGN_STYLE = Automatic;", "CODE_SIGN_STYLE = Manual;", content
        )
        content = re.sub(
            r'"CODE_SIGN_IDENTITY\[sdk=macosx\*\]" = "Apple Development";', "", content
        )

        if content == original_content:
            print("⚠️  No changes made - original settings may already be correct")
        else:
            # Write modified content
            with open(project_file, "w", encoding="utf-8") as f:
                f.write(content)
            print("✅ Project file modified successfully")

        # Show updated settings
        print("📝 Updated settings:")
        for line in content.split("\n"):
            if any(
                setting in line
                for setting in [
                    "CODE_SIGN_STYLE",
                    "DEVELOPMENT_TEAM",
                    "CODE_SIGN_IDENTITY",
                ]
            ):
                if line.strip():
                    print(f"  {line.strip()}")

    except Exception as e:
        print(f"❌ Error modifying project file: {e}")
        if backup_file.exists():
            print("🔄 Restoring backup...")
            _ = shutil.copy2(backup_file, project_file)
            print("⚠️  Restored backup - will use original settings")
        sys.exit(1)


if __name__ == "__main__":
    main()
