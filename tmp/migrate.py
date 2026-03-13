import os
import re

def migrate_with_opacity(directory):
    count = 0
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart"):
                path = os.path.join(root, file)
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Target withOpacity(any_expression)
                    new_content = re.sub(r'\.withOpacity\((.*?)\)', r'.withValues(alpha: \1)', content)
                    
                    if new_content != content:
                        with open(path, 'w', encoding='utf-8', newline='') as f:
                            f.write(new_content)
                        count += 1
                        print(f"Migrated: {path}")
                except Exception as e:
                    print(f"Error processing {path}: {e}")
    print(f"Total files migrated: {count}")

if __name__ == "__main__":
    migrate_with_opacity("lib")
