import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import sqlite3
import subprocess
import time
import xml.etree.ElementTree as ET
import zipfile

from common import CorpusError, atomic, checked_manifest, intact, load, log, now, safe

EXTRACTOR_VERSION = '1'
DETECTOR_VERSION = '1'
MAX_EXTRACT_BYTES = 256 * 1024 * 1024
PLAIN = {'.txt', '.sql', '.log', '.csv', '.tsv', '.json', '.xml', '.yaml', '.yml', '.md', '.ini', '.conf', '.config', '.php', '.py', '.js', '.sh', '.html', '.htm', '.css', '.properties', '.out', '.diff', '.patch'}
SQL = re.compile(r'\b(?:SELECT\b[\s\S]{0,4000}?\bFROM\s+[`"\w.]+|UPDATE\s+[`"\w.]+\s+SET\s+[`"\w.]+\s*=|DELETE\s+FROM\s+[`"\w.]+|INSERT\s+(?:IGNORE\s+)?INTO\s+[`"\w.]+|REPLACE\s+INTO\s+[`"\w.]+|(?:ALTER|CREATE|DROP|TRUNCATE)\s+(?:TABLE|VIEW|INDEX)\s+(?:IF\s+(?:NOT\s+)?EXISTS\s+)?[`"\w.]+)', re.I)
TABLES = re.compile(r'\b(?:FROM|JOIN|UPDATE|INTO|TABLE|VIEW)\s+([`"\w.]+)', re.I)
FIX = re.compile(r'\b(fix(?:ed)?|resolv(?:e|ed|es)|workaround|solution|correct(?:ed|ion)|repair(?:ed)?)\b', re.I)


class StorageText(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag in ('p', 'div', 'br', 'li', 'tr', 'pre', 'code', 'ac:plain-text-body'):
            self.parts.append('\n')
        for name, value in attrs:
            if name in ('href', 'ri:filename', 'ri:content-title'):
                self.parts.append(' ' + value + ' ')

    def handle_endtag(self, tag):
        if tag in ('p', 'div', 'li', 'tr', 'pre', 'code', 'ac:plain-text-body'):
            self.parts.append('\n')

    def handle_data(self, data):
        self.parts.append(data)

    def unknown_decl(self, data):
        if data.startswith('CDATA['):
            self.parts.append(data[6:])


def text(value):
    if value is None:
        return ''
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return ''.join(text(item) for item in value)
    if isinstance(value, dict):
        if value.get('type') == 'text':
            output = value.get('text', '')
        else:
            output = text(value.get('content', []))
        if value.get('type') in ('paragraph', 'codeBlock', 'heading', 'listItem', 'hardBreak', 'tableRow'):
            output += '\n'
        attrs = value.get('attrs', {})
        if value.get('type') in ('inlineCard', 'blockCard'):
            output += attrs.get('url', '')
        for mark in value.get('marks', []):
            if mark.get('type') == 'link':
                output += ' ' + mark.get('attrs', {}).get('href', '')
        return output
    return str(value)


def storage(value):
    parser = StorageText()
    parser.feed(value)
    parser.close()
    return ''.join(parser.parts)


def extract(path, name, media):
    suffix = Path(name).suffix.lower()
    if suffix not in PLAIN | {'.pdf', '.docx', '.xlsx', '.pptx', '.odt', '.ods', '.odp'} and not media.startswith('text/'):
        return '', 'metadata-only: unsupported format (no OCR or transcription)'
    if path.stat().st_size > MAX_EXTRACT_BYTES:
        return '', 'not-extracted: exceeds 256 MiB per-file extraction limit'
    try:
        if suffix == '.pdf':
            result = subprocess.run(['pdftotext', '-layout', str(path), '-'], capture_output=True, timeout=120)
            if result.returncode:
                return '', 'extraction-error: PDF unreadable or encrypted'
            output = result.stdout.decode('utf-8', errors='replace')
            return output, 'extracted: pdf' if output.strip() else 'metadata-only: PDF has no extractable text'
        if suffix in {'.docx', '.xlsx', '.pptx', '.odt', '.ods', '.odp'}:
            parts = []
            with zipfile.ZipFile(path) as archive:
                selected = [item for item in archive.infolist() if item.filename.endswith('.xml') and (item.filename.startswith(('word/', 'xl/worksheets/', 'ppt/slides/', 'ppt/notesSlides/')) or item.filename in ('xl/sharedStrings.xml', 'content.xml'))]
                if sum(item.file_size for item in selected) > MAX_EXTRACT_BYTES:
                    return '', 'not-extracted: Office XML exceeds 256 MiB extraction limit'
                for item in sorted(selected, key=lambda value: value.filename):
                    document = ET.fromstring(archive.read(item))
                    parts.append(item.filename + '\n' + ' '.join(document.itertext()))
            return '\n'.join(parts), 'extracted: office-xml'
        raw = path.read_bytes()
        encoding = 'utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig'
        try:
            output = raw.decode(encoding)
            status = 'extracted: text'
        except UnicodeError:
            output = raw.decode('cp1252', errors='replace')
            status = 'extracted: text (cp1252 fallback; replacement possible)'
        if '\x00' in output:
            return '', 'metadata-only: binary content in text-like file'
        return storage(output) if suffix in ('.html', '.htm') else output, status
    except (OSError, ValueError, ET.ParseError, zipfile.BadZipFile, subprocess.TimeoutExpired):
        return '', 'extraction-error: invalid, encrypted or timed-out file; inspect locally and retry after repair'


def sql_candidates(segments):
    for location, value in segments:
        for match in SQL.finditer(value):
            start = match.start()
            end = value.find(';', match.end())
            line_end = value.find('\n\n', match.end())
            if end < 0 or end - start > 16000:
                end = min(len(value), start + 16000)
            else:
                end += 1
            if line_end >= 0:
                end = min(end, line_end)
            statement = value[start:end].strip()
            verb = match.group().split()[0].upper()
            kind = 'diagnostic' if verb == 'SELECT' else 'data-change' if verb in ('UPDATE', 'INSERT', 'DELETE', 'REPLACE') else 'schema-change'
            context = value[max(0, start - 350):min(len(value), end + 350)]
            tables = sorted({m.strip('`"') for m in TABLES.findall(statement)})
            fix_context = bool(FIX.search(context))
            yield dict(kind=kind, statement=statement, tables=tables, location=f'{location}:characters {start}-{end}', context=context, evidence='SQL content with fix context' if fix_context else 'SQL content; fix not confirmed', score=(10 if fix_context else 0) + (3 if kind == 'data-change' else 1), truncated=end - start >= 16000)


def components(source, site, scope, folder, record):
    ident = record['id']
    for kind, component in [('record', record['file'])] + [('attachment', value) for value in record.get('attachments', [])]:
        uid = f"{site}|{source}|{'attachment-binary' if kind == 'attachment' else record.get('kind', 'issue')}|{component.get('id', ident)}"
        signature = hashlib.sha256(json.dumps([component['sha256'], record.get('updated'), record.get('key'), scope['id'], scope['key'], record.get('availability'), EXTRACTOR_VERSION, DETECTOR_VERSION, kind], sort_keys=True).encode()).hexdigest()
        yield dict(uid=uid, fingerprint=signature, component=component, kind=kind, path=str(Path(scope['path']) / component['path']))


def make_document(source, site, scope, folder, record, part, hashes=False):
    file = safe(folder, part['component']['path'])
    if not intact(folder, part['component'], hashes):
        raise CorpusError(f"Cannot index {scope['key']}/{record['id']}: missing or changed local file. Run sync --mode delta to repair it.")
    segments = []
    key = record['key']
    title = key
    remote = site
    status = 'extracted: structured text'
    if part['kind'] == 'attachment':
        comp = part['component']
        title = comp.get('name', '')
        body, status = extract(file, title, comp.get('media_type', ''))
        segments = [('attachment/' + str(comp['id']), body)]
        remote += '/browse/' + key if source == 'jira' else '/wiki/pages/viewpage.action?pageId=' + record.get('parent_id', record['id'])
    else:
        raw = load(file)
        if source == 'jira':
            fields = raw['fields']
            title = fields.get('summary', '')
            segments = [('description', text(fields.get('description'))), ('environment', text(fields.get('environment')))]
            segments.extend(('comment/' + str(c['id']), text(c.get('body'))) for c in fields.get('comment', {}).get('comments', []))
            body = '\n'.join(value for _, value in segments)
            body += '\n' + ' '.join(fields.get('labels', [])) + '\n' + '\n'.join(att.get('filename', '') for att in fields.get('attachment', []))
            body += '\n' + text(fields.get('resolution', {}).get('name') if fields.get('resolution') else '')
            remote += '/browse/' + key
        else:
            title = raw.get('title', '')
            if record.get('kind') == 'attachment' and not record.get('complete'):
                status = 'metadata-only: binary unavailable (incomplete download)'
            body = storage(raw.get('body', {}).get('storage', {}).get('value', ''))
            segments = [('body.storage', body)]
            body += '\n' + ' '.join(label.get('name', '') for label in raw.get('metadata', {}).get('labels', {}).get('results', []))
            link = raw.get('_links', {}).get('webui')
            remote += '/wiki' + link if link and not link.startswith('/wiki') else link or '/wiki/pages/viewpage.action?pageId=' + record['id']
    return dict(uid=part['uid'], source=source, site=site, scope_id=scope['id'], scope=scope['key'], key=key, entity=record.get('kind', 'issue') if part['kind'] == 'record' else 'attachment', title=title, body=body, updated=record.get('updated', ''), path=part['path'], remote_url=remote, fingerprint=part['fingerprint'], extraction=status, availability=record.get('availability', 'available')), list(sql_candidates(segments))


DDL = '''
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS documents (id INTEGER PRIMARY KEY, uid TEXT UNIQUE NOT NULL, source TEXT, site TEXT, scope_id TEXT, scope TEXT, key TEXT, entity TEXT, title TEXT, body TEXT, updated TEXT, path TEXT, remote_url TEXT, fingerprint TEXT, extraction TEXT, availability TEXT);
CREATE INDEX IF NOT EXISTS document_key ON documents(source,key);
CREATE INDEX IF NOT EXISTS document_scope ON documents(source,scope_id);
CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(title,body,keywords,tokenize='unicode61');
CREATE TABLE IF NOT EXISTS sql_candidates (id INTEGER PRIMARY KEY, doc_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE, kind TEXT, statement TEXT, tables_json TEXT, location TEXT, context TEXT, evidence TEXT, score INTEGER, truncated INTEGER);
CREATE INDEX IF NOT EXISTS sql_kind ON sql_candidates(kind,doc_id);
CREATE INDEX IF NOT EXISTS sql_document ON sql_candidates(doc_id);
'''


def connection(path):
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys=ON')
    db.executescript(DDL)
    version = db.execute("SELECT value FROM meta WHERE key='schema'").fetchone()
    if version and version[0] != '1':
        db.close()
        raise CorpusError('Unsupported index schema. Run index --mode rebuild with a compatible script.')
    db.execute("INSERT OR IGNORE INTO meta VALUES ('schema','1')")
    db.commit()
    return db


def put(db, document, candidates):
    existing = db.execute('SELECT id FROM documents WHERE uid=?', (document['uid'],)).fetchone()
    if existing:
        db.execute('DELETE FROM documents_fts WHERE rowid=?', (existing['id'],))
        db.execute('DELETE FROM documents WHERE id=?', (existing['id'],))
    columns = ','.join(document)
    marks = ','.join('?' for _ in document)
    rowid = db.execute(f'INSERT INTO documents ({columns}) VALUES ({marks})', tuple(document.values())).lastrowid
    db.execute('INSERT INTO documents_fts(rowid,title,body,keywords) VALUES (?,?,?,?)', (rowid, document['title'], document['body'], document['key'] + ' ' + document['scope'] + ' ' + document['entity']))
    for item in candidates:
        db.execute('INSERT INTO sql_candidates(doc_id,kind,statement,tables_json,location,context,evidence,score,truncated) VALUES (?,?,?,?,?,?,?,?,?)', (rowid, item['kind'], item['statement'], json.dumps(item['tables']), item['location'], item['context'], item['evidence'], item['score'], item['truncated']))


def build(args):
    started = time.monotonic()
    args.index_root.mkdir(parents=True, exist_ok=True)
    target = args.index_root / 'corpus.sqlite'
    rebuild = args.mode == 'rebuild' or not target.exists()
    if rebuild and (args.spaces not in (None, 'all') or args.projects):
        raise CorpusError('A rebuild must include the complete local corpus. Use index --mode update with a space or project filter.')
    path = args.index_root / 'corpus.building.sqlite' if rebuild else target
    if rebuild:
        path.unlink(missing_ok=True)
    db = connection(path)
    changed = reused = count = candidates = 0
    matched_scopes = 0
    statuses = {}
    source_counts = {}
    try:
        for source in ('jira', 'confluence') if args.source == 'all' else (args.source,):
            root = getattr(args, source + '_root')
            catalog = checked_manifest(root / 'corpus.json')
            if not catalog:
                if args.source != 'all':
                    raise CorpusError(f'{source}: catalog missing. Run sync --mode delta to adopt/reconcile the local corpus.')
                continue
            if catalog.get('source') != source:
                raise CorpusError(f'{source}: the supplied root belongs to another source. Correct the Jira/Confluence root arguments.')
            selection = args.projects if source == 'jira' else args.spaces
            if selection and selection != 'all':
                missing = set(selection.split(',')) - {scope['key'] for scope in catalog['scopes']}
                if missing:
                    raise CorpusError(f'{source}: requested keys are absent from the local catalog: {", ".join(sorted(missing))}. Download those scopes first or correct the selection.')
            for scope in catalog['scopes']:
                if selection and selection != 'all' and scope['key'] not in selection.split(','):
                    continue
                folder = safe(root, scope['path'])
                matched_scopes += 1
                manifest = checked_manifest(folder / 'manifest.json', catalog['site'])
                if not manifest:
                    raise CorpusError(f"{source}/{scope['key']}: manifest missing. Run sync --mode delta to reconstruct it before indexing.")
                scope_start = time.monotonic()
                with db:
                    old = {row['uid']: (row['id'], row['fingerprint']) for row in db.execute('SELECT id,uid,fingerprint FROM documents WHERE source=? AND site=? AND scope_id=?', (source, catalog['site'], scope['id']))}
                    seen = set()
                    for record in manifest['records'].values():
                        for part in components(source, catalog['site'], scope, folder, record):
                            if args.text_only and part['kind'] == 'attachment':
                                continue
                            count += 1
                            source_counts[source] = source_counts.get(source, 0) + 1
                            seen.add(part['uid'])
                            current = db.execute('SELECT scope_id,availability,updated FROM documents WHERE uid=?', (part['uid'],)).fetchone()
                            if current and current['scope_id'] != scope['id'] and current['availability'] == 'available' and (record.get('availability') != 'available' or current['updated'] > record.get('updated', '')):
                                reused += 1
                                continue
                            if part['uid'] in old and old[part['uid']][1] == part['fingerprint']:
                                if not intact(folder, part['component'], args.hashes):
                                    raise CorpusError(f"{scope['key']}/{record['id']}: local file changed. Run delta before updating the index.")
                                reused += 1
                                continue
                            document, found = make_document(source, catalog['site'], scope, folder, record, part, args.hashes)
                            put(db, document, found)
                            candidates += len(found)
                            changed += 1
                            statuses[document['extraction']] = statuses.get(document['extraction'], 0) + 1
                            if changed % 2000 == 0:
                                log(f'Index: {changed} documents updated, {reused} reused, {time.monotonic() - started:.1f}s elapsed.')
                    for uid in old.keys() - seen:
                        if args.text_only and '|attachment-binary|' in uid:
                            continue
                        db.execute('DELETE FROM documents_fts WHERE rowid=?', (old[uid][0],))
                        db.execute('DELETE FROM documents WHERE id=?', (old[uid][0],))
                log(f"Index {source}/{scope['key']}: transaction committed in {time.monotonic() - scope_start:.1f}s.")
        if not matched_scopes:
            raise CorpusError('No local records matched. Check source, project/space selection and corpus catalogs.')
        with db:
            db.execute("INSERT OR REPLACE INTO meta VALUES ('extractor_version',?)", (EXTRACTOR_VERSION,))
            db.execute("INSERT OR REPLACE INTO meta VALUES ('detector_version',?)", (DETECTOR_VERSION,))
            db.execute("INSERT OR REPLACE INTO meta VALUES ('updated_at',?)", (now(),))
            if rebuild or args.hashes:
                db.execute("INSERT INTO documents_fts(documents_fts) VALUES ('integrity-check')")
        if rebuild or args.hashes:
            integrity = db.execute('PRAGMA quick_check').fetchone()[0]
            if integrity != 'ok':
                raise CorpusError('SQLite integrity check failed. Rebuild the derived index from raw files.')
        totals = dict(documents=db.execute('SELECT count(*) FROM documents').fetchone()[0], sql_candidates=db.execute('SELECT count(*) FROM sql_candidates').fetchone()[0], coverage={row[0]: row[1] for row in db.execute('SELECT extraction,count(*) FROM documents GROUP BY extraction')})
    finally:
        db.close()
    if rebuild:
        path.replace(target)
    result = dict(finished_at=now(), mode='rebuild' if rebuild else 'update', text_only=args.text_only, integrity='full' if rebuild or args.hashes else 'transactional update; full check available with --hashes', seconds=round(time.monotonic() - started, 3), bytes=target.stat().st_size, changed=changed, reused=reused, source_documents=source_counts, extraction=statuses, **totals)
    atomic(args.index_root / 'last-index-run.json', result)
    atomic(args.index_root / 'runs' / (result['finished_at'].replace(':', '') + '.json'), result)
    log(json.dumps(result))


def search(args):
    path = args.index_root / 'corpus.sqlite'
    if not path.exists():
        raise CorpusError('Index missing. Run index --source all --mode rebuild; only local files are needed.')
    if not 1 <= args.limit <= 1000:
        raise CorpusError('Search limit must be between 1 and 1000.')
    started = time.monotonic()
    db = sqlite3.connect(path.as_uri() + '?mode=ro', uri=True)
    db.row_factory = sqlite3.Row
    where, params = [], []
    join = ''
    rank = '0'
    snippet = "substr(d.body,1,240)"
    if args.query:
        join += ' JOIN documents_fts ON documents_fts.rowid=d.id'
        where.append('documents_fts MATCH ?')
        params.append(args.query)
        rank = 'bm25(documents_fts,5.0,1.0,3.0)'
        snippet = "snippet(documents_fts,1,'[',']','...',32)"
    if args.source != 'all':
        where.append('d.source=?')
        params.append(args.source)
    for column, value, operator in [('key', args.key, '='), ('updated', args.since, '>='), ('updated', args.until, '<=')]:
        if value:
            where.append(f'd.{column}{operator}?')
            params.append(value)
    for source, selection in [('jira', args.projects), ('confluence', args.spaces)]:
        if selection and selection != 'all':
            keys = selection.split(',')
            where.append('(d.source != ? OR d.scope IN (' + ','.join('?' for _ in keys) + '))')
            params.extend([source, *keys])
    extra = ''
    order = 'rank ASC,d.id'
    if args.sql_kind or args.table:
        join += ' JOIN sql_candidates s ON s.doc_id=d.id'
        extra = ',s.kind,s.statement,s.tables_json,s.location,s.context,s.evidence,s.truncated,s.score'
        order = 's.score DESC,rank ASC,d.id'
        if args.sql_kind and args.sql_kind != 'any':
            where.append('s.kind=?')
            params.append(args.sql_kind)
        if args.table:
            where.append('EXISTS (SELECT 1 FROM json_each(s.tables_json) WHERE lower(value)=lower(?))')
            params.append(args.table)
    sql = f'SELECT d.source,d.scope,d.key,d.entity,d.title,d.path,d.remote_url,d.extraction,d.availability,{rank} AS rank,{snippet} AS snippet{extra} FROM documents d{join}'
    if where:
        sql += ' WHERE ' + ' AND '.join(where)
    sql += f' ORDER BY {order} LIMIT ?'
    try:
        rows = [dict(row) for row in db.execute(sql, [*params, args.limit])]
    except sqlite3.Error as exc:
        if 'locked' in str(exc).lower():
            raise CorpusError('The index is busy committing an update. Retry search after that update completes.') from exc
        raise CorpusError('Invalid FTS query or incompatible index. Quote phrases and hyphenated keys, or use --key for exact lookup. Rebuild if the index schema changed.') from exc
    finally:
        db.close()
    elapsed = (time.monotonic() - started) * 1000
    for row in rows:
        row['local_file'] = str(safe(getattr(args, row['source'] + '_root'), row['path']))
        if 'tables_json' in row:
            row['tables'] = json.loads(row.pop('tables_json'))
    if args.format == 'json':
        print(json.dumps(dict(milliseconds=round(elapsed, 3), results=rows), ensure_ascii=False))
    else:
        for row in rows:
            print(f"{row['source']}/{row['scope']} {row['key']} ({row['entity']}): {row['title']}\n  {row['snippet']}\n  {row['local_file']}\n  {row['remote_url']}")
            if 'kind' in row:
                print(f"  {row['kind']}; {row['evidence']}; {row['location']}; tables={','.join(row['tables'])}\n  {row['statement']}")
        print(f'{len(rows)} results in {elapsed:.3f} ms.')
