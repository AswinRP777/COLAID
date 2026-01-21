import os

def fix_login_page():
    path = r'c:\Users\loq\OneDrive\Desktop\New folder (5)\New folder\Colaid\colaid\lib\pages\login_page.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # The block to replace
    old_block = """        // Reset CVD Type to None (Standard)
        if (mounted) {
          Provider.of<ThemeProvider>(
            context,
            listen: false,
          ).setCvdType(CvdType.none);
        }"""
        
    new_block = """        // Reset/Reload Settings for this user
        if (mounted) {
          await Provider.of<ThemeProvider>(context, listen: false).refresh();
        }"""

    if old_block in content:
        print("Found block in login_page.dart, replacing...")
        content = content.replace(old_block, new_block)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Fixed login_page.dart")
    else:
        print("Could not find exact block in login_page.dart. checking partial...")
        # Fallback: try to find it line by line or with relaxed whitespace if needed
        # But for now let's hope python string matching works where cortex failed
        pass

def fix_settings_page():
    path = r'c:\Users\loq\OneDrive\Desktop\New folder (5)\New folder\Colaid\colaid\lib\pages\settings_page.dart'
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    fixed = False
    
    # We look for the sequence in Delete Account dialog
    # It has high indentation
    target_line = "                                UserService().clearUserData();\n"
    next_line_start = "                                Navigator.pushNamedAndRemoveUntil("
    
    for i, line in enumerate(lines):
        new_lines.append(line)
        if line == target_line and i+1 < len(lines) and lines[i+1].lstrip().startswith("Navigator.pushNamedAndRemoveUntil"):
             # Insert the refresh call
             indent = "                                "
             new_lines.append(f"{indent}if (context.mounted) {{\n")
             new_lines.append(f"{indent}  Provider.of<ThemeProvider>(context, listen: false).refresh();\n")
             new_lines.append(f"{indent}}}\n")
             fixed = True
             print("Inserted refresh call in settings_page.dart")

    if fixed:
        with open(path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
            print("Fixed settings_page.dart")
    else:
        print("Could not find target in settings_page.dart")

if __name__ == "__main__":
    try:
        fix_login_page()
        fix_settings_page()
    except Exception as e:
        print(f"Error: {e}")
