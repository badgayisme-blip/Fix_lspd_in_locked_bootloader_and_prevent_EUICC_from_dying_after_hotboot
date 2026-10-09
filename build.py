#!/usr/bin/env python3
import os
import zipfile

OUTPUT_ZIP = "KernelSU_LSPosed_eUICC_Fix.zip"

FILES_TO_PACK = [
    "action.sh",
    "customize.sh",
    "main",
    "module.prop",
    "service.sh",
    "YHyc",
    os.path.join("webroot", "index.html"),
    os.path.join("system", "bin", "fix-euicc"),
]

def main():
    root_dir = os.path.dirname(os.path.abspath(__file__))
    out_path = os.path.join(root_dir, OUTPUT_ZIP)
    
    print(f"Building {OUTPUT_ZIP}...")
    with zipfile.ZipFile(out_path, 'w', compression=zipfile.ZIP_DEFLATED) as z:
        for rel_path in FILES_TO_PACK:
            full_path = os.path.join(root_dir, rel_path)
            if not os.path.exists(full_path):
                print(f"ERROR: Missing file {rel_path}")
                return 1
            
            # Read and ensure Unix LF for shell scripts
            data = open(full_path, 'rb').read()
            if rel_path.endswith('.sh') or rel_path.endswith('fix-euicc') or rel_path.endswith('.prop'):
                data = data.replace(b'\r\n', b'\n')
            
            # Use forward slashes inside zip
            archive_name = rel_path.replace('\\', '/')
            info = zipfile.ZipInfo(archive_name)
            info.external_attr = 0o755 << 16  # rwxr-xr-x
            z.writestr(info, data)
            print(f"  Added {archive_name} ({len(data)} bytes)")
            
    print(f"\n[OK] Successfully created flashable zip: {out_path}")
    return 0

if __name__ == "__main__":
    exit(main())
