#!/usr/bin/env python3
# scripts/oracle-learn.py — ส่งไฟล์เข้า Oracle /api/learn (upsert: ลบ file+DB ก่อน)
# Usage: python3 scripts/oracle-learn.py <file> <pattern> <tags> <oracle_url>

import json, os, re, sqlite3, sys, urllib.request, urllib.error

# Oracle vault: ~/.arra-oracle-v2  (config.ts: ORACLE_DATA_DIR_NAME = '.arra-oracle-v2')
ORACLE_VAULT = os.environ.get('ORACLE_DATA_DIR', os.path.join(os.path.expanduser('~'), '.arra-oracle-v2'))
LEARNINGS_DIR = os.path.join(ORACLE_VAULT, '\u03c8', 'memory', 'learnings')
ORACLE_DB = os.path.join(ORACLE_VAULT, 'oracle.db')

def make_slug(pattern):
    """replicate Oracle slug logic from handlers.ts"""
    slug = pattern[:50].lower()
    slug = re.sub(r'[^a-z0-9\s-]', '', slug)
    slug = re.sub(r'\s+', '-', slug)
    slug = re.sub(r'-+', '-', slug)
    return slug.strip('-')

def delete_existing(slug):
    """ลบ file + DB records ที่มี slug ตรงกัน"""
    if os.path.isdir(LEARNINGS_DIR):
        for fname in os.listdir(LEARNINGS_DIR):
            if fname.endswith('_' + slug + '.md'):
                try:
                    os.remove(os.path.join(LEARNINGS_DIR, fname))
                except Exception:
                    pass
    if os.path.isfile(ORACLE_DB):
        try:
            con = sqlite3.connect(ORACLE_DB)
            cur = con.cursor()
            pattern_like = '%_' + slug + '.md'
            cur.execute("DELETE FROM oracle_documents WHERE source_file LIKE ?", (pattern_like,))
            try:
                cur.execute("DELETE FROM oracle_fts WHERE source_file LIKE ?", (pattern_like,))
            except Exception:
                pass
            con.commit()
            con.close()
        except Exception:
            pass

def main():
    if len(sys.argv) < 5:
        print("000")
        return

    file_path, pattern, tags, oracle_url = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

    try:
        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            raw = f.read(8000)
    except Exception:
        print("000")
        return

    if not raw.strip():
        print("skip")
        return

    # full_pattern = short name + content (Oracle stores this as the indexed content)
    full_pattern = pattern + '\n\n' + raw

    # Upsert: compute slug same way Oracle does, then delete old file+DB
    slug = make_slug(full_pattern)
    delete_existing(slug)

    concepts_list = [t.strip() for t in tags.split(',') if t.strip()]
    payload = json.dumps({
        'pattern': full_pattern,
        'concepts': concepts_list,
    }).encode('utf-8')

    req = urllib.request.Request(
        oracle_url + '/api/learn',
        data=payload,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    try:
        urllib.request.urlopen(req, timeout=10)
        print("200")
    except urllib.error.HTTPError as e:
        print(str(e.code))
    except Exception:
        print("000")

if __name__ == '__main__':
    main()
