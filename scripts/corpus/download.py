import concurrent.futures
import datetime as dt
import json
import os
from pathlib import Path
import re
import shutil
import time
import uuid
import urllib.parse
from zoneinfo import ZoneInfo

from common import (CorpusError, SCHEMA, atomic, checked_manifest, check_disk, date,
                    estimate, identifier, intact, load, log, now, receipt, safe, show_estimate)


def files_ok(root, record, attachments=True, hashes=False):
    return bool(record.get('complete')) and intact(root, record['file'], hashes) and all(
        intact(root, item, hashes) for item in record.get('attachments', [])
    ) and (not attachments or record.get('attachments_complete', True))


def project_catalog(root, api, args):
    catalog = checked_manifest(root / 'corpus.json', api.site)
    if catalog:
        if catalog.get('source') != 'jira':
            raise CorpusError('This root belongs to another source. Choose the Jira corpus root.')
        projects = catalog['scopes']
    else:
        projects = []
        candidates = {}
        folders = [root] if (root / 'issues').is_dir() else sorted(p.parent for p in root.glob('*/issues'))
        for folder in folders:
            paths = list((folder / 'issues').glob('*.json'))
            for path in paths:
                try:
                    issue = load(path)
                except CorpusError:
                    continue
                project = issue.get('fields', {}).get('project', {})
                if project.get('key'):
                    key = identifier(project['key'])
                    parsed = urllib.parse.urlsplit(issue.get('self', ''))
                    if parsed.netloc and parsed.netloc.lower() != urllib.parse.urlsplit(api.site).netloc:
                        raise CorpusError(f'Site mismatch in {path}. Use credentials for this corpus site.')
                    scope = dict(id=str(project.get('id', key)), key=key, path=str(folder.relative_to(root)), jql=f'project = "{key}"')
                    if key not in candidates or len(paths) > candidates[key][0]:
                        candidates[key] = (len(paths), scope)
                    break
        projects = [item[1] for item in candidates.values()]
        if projects:
            log('Adopting largest existing snapshot for each project; smaller duplicate snapshots and analysis are retained separately.')
    if args.jql or args.filter:
        query = args.jql or f'filter = {identifier(args.filter)}'
        if catalog and any(p['jql'] != query for p in projects):
            raise CorpusError('The saved query differs from this request. Use a separate output directory for a different filter.')
        projects = [dict(id='query', key='query', path='.', jql=query)]
    elif args.projects:
        selected = []
        for item in args.projects.split(','):
            key, _, folder = item.partition(':')
            key = identifier(key)
            existing = next((p for p in projects if p['key'] == key), None)
            if not existing:
                metadata = api.request('/rest/api/3/project/' + urllib.parse.quote(key))
                existing = dict(id=str(metadata['id']), key=metadata['key'], path=folder or key, jql=f'project = "{key}"')
                safe(root, existing['path'])
                projects.append(existing)
            selected.append(existing)
        selected_ids = {p['id'] for p in selected}
    else:
        selected_ids = {p['id'] for p in projects}
    if not projects:
        raise CorpusError('No existing Jira projects found. For a new corpus supply --projects KEY1,KEY2 or --jql with an explicit scope.')
    destinations = [safe(root, project['path']) for project in projects]
    if len(set(destinations)) != len(destinations) or any(a != b and a.is_relative_to(b) for a in destinations for b in destinations):
        raise CorpusError('Project destinations overlap. Give each project its own directory and retry.')
    catalog = dict(schema=SCHEMA, source='jira', site=api.site, scopes=projects)
    return catalog, [p for p in projects if p['id'] in selected_ids] if not (args.jql or args.filter) else projects


def attachment_path(root, key, attachment):
    ident = identifier(attachment['id'])
    folder = safe(root, 'attachments/' + identifier(key))
    matches = list(folder.glob(ident + '_*'))
    if len(matches) == 1 and matches[0].is_file() and '.part-' not in matches[0].name:
        return safe(root, matches[0].relative_to(root))
    name = attachment.get('filename', 'content').replace('/', '_').lstrip('.')
    name = name[:160] or 'content'
    return safe(root, (folder / (ident + '_' + name)).relative_to(root))


def jira_record(root, issue, api=None, binaries=True):
    key = identifier(issue['key'])
    fields = issue['fields']
    path = safe(root, f'issues/{key}.json')
    comments = fields.get('comment', {})
    complete = len(comments.get('comments', [])) == comments.get('total', 0)
    attachments = []
    for att in fields.get('attachment', []):
        file = attachment_path(root, key, att)
        expected = att.get('size', 0)
        exists = file.is_file() and (file.stat().st_size == expected or expected == 0)
        if binaries and not exists and api:
            api.request(att['content'], target=file, size=expected)
            exists = True
        if exists:
            attachments.append(receipt(root, file, id=str(att['id']), name=att.get('filename', ''), media_type=att.get('mimeType', ''), remote_size=expected, validation='remote-size' if expected else 'local-hash-size-unknown'))
        elif binaries:
            complete = False
    return dict(id=str(issue['id']), key=key, project=fields.get('project', {}).get('key', ''), updated=fields.get('updated', ''), file=receipt(root, path), attachments=attachments, complete=complete, attachments_complete=len(attachments) == len(fields.get('attachment', [])), availability='available')


def inventory(root, site, source):
    manifest = checked_manifest(root / 'manifest.json', site)
    if manifest is None:
        manifest = dict(schema=SCHEMA, site=site, source=source, records={})
        if source == 'jira':
            for n, path in enumerate(sorted((root / 'issues').glob('*.json')), 1):
                try:
                    issue = load(path)
                    if issue and issue.get('id') and issue.get('key'):
                        record = jira_record(root, issue)
                        previous = manifest['records'].get(record['id'])
                        if previous is None or record['updated'] >= previous['updated']:
                            manifest['records'][record['id']] = record
                except (CorpusError, KeyError, ValueError):
                    log(f'Adoption: invalid/incomplete issue file {path.name}; metadata reconciliation will repair it.')
                if n % 2000 == 0:
                    log(f'Adoption: validated {n} local Jira records and attachment receipts.')
        else:
            for kind in ('pages', 'blogposts', 'comments'):
                for path in (root / kind).glob('*.json'):
                    try:
                        content = load(path)
                        record = confluence_record(root, content, path)
                        manifest['records'][record['id']] = record
                    except (CorpusError, KeyError, ValueError):
                        log(f'Adoption: invalid {kind} file {path.name}; metadata reconciliation will repair it.')
            for path in (root / 'attachments').glob('*/v*/metadata.json'):
                try:
                    content = load(path)
                    record = confluence_record(root, content, path)
                    previous = manifest['records'].get(record['id'])
                    if previous is None or previous['version'] < record['version']:
                        manifest['records'][record['id']] = record
                except (CorpusError, KeyError, ValueError):
                    log(f'Adoption: incomplete attachment {path.parent.parent.name}; delta will repair it.')
    for path in (root / '.sync/receipts').glob('*.json'):
        record = load(path)
        manifest['records'][record['id']] = record
    return manifest


def save_manifest(root, manifest):
    atomic(root / 'manifest.json', manifest)
    for path in (root / '.sync/receipts').glob('*.json'):
        path.unlink()


def fresh(record, remote, source):
    if source == 'jira':
        return record.get('updated', '') >= remote['fields'].get('updated', '') and record.get('key') == remote['key']
    return record.get('version', 0) >= remote.get('version', {}).get('number', 0) and record.get('kind') == remote['type']


def jira_listing(api, jql):
    token = None
    seen = set()
    results = {}
    while True:
        params = dict(jql=jql, fields='id,key,updated,attachment', maxResults=100)
        if token:
            params['nextPageToken'] = token
        page = api.request('/rest/api/3/search/jql', params)
        if not isinstance(page.get('issues'), list):
            raise CorpusError('Jira search omitted issues. Check account access and the API response contract.')
        for issue in page['issues']:
            results[str(issue['id'])] = issue
        token = page.get('nextPageToken')
        if not token:
            break
        if token in seen:
            raise CorpusError('Jira pagination repeated a cursor. Rerun to restart metadata discovery.')
        seen.add(token)
    return list(results.values())


def jira_fetch(api, root, remote, binaries=True, previous=None, hashes=False):
    issue = api.request('/rest/api/3/issue/' + identifier(remote['id']), {'fields': '*all'})
    if str(issue.get('id')) != str(remote['id']) or not issue.get('key'):
        raise CorpusError('Jira issue identity mismatch. Retry after checking API/proxy configuration.')
    comments = issue['fields'].get('comment', {})
    if len(comments.get('comments', [])) != comments.get('total', 0):
        all_comments = {}
        start = 0
        while True:
            page = api.request('/rest/api/3/issue/' + identifier(issue['id']) + '/comment', {'startAt': start, 'maxResults': 100})
            values = page.get('comments', [])
            for comment in values:
                all_comments[str(comment['id'])] = comment
            start += len(values)
            total = page['total']
            if start >= total:
                break
            if not values:
                raise CorpusError('Comment pagination ended early. Retry the ticket; its previous JSON is retained.')
        if len(all_comments) != total:
            raise CorpusError('Comments changed during pagination. Retry the ticket for a consistent comment snapshot.')
        issue['fields']['comment'] = dict(comments=list(all_comments.values()), total=total, maxResults=total, startAt=0)
    for att in issue['fields'].get('attachment', []) if binaries else []:
        path = attachment_path(root, issue['key'], att)
        expected = att.get('size', 0)
        old = next((a for a in (previous or {}).get('attachments', []) if a['id'] == str(att['id'])), None)
        if old and old['path'] != str(path.relative_to(root)) and intact(root, old, hashes) and (not expected or old['size'] == expected):
            path.parent.mkdir(parents=True, exist_ok=True)
            temp = path.with_name(path.name + '.part-' + uuid.uuid4().hex)
            try:
                try:
                    os.link(safe(root, old['path']), temp)
                except OSError:
                    shutil.copy2(safe(root, old['path']), temp)
                temp.replace(path)
            finally:
                temp.unlink(missing_ok=True)
        if not path.is_file() or (expected > 0 and path.stat().st_size != expected) or (old and not intact(root, old, hashes)):
            api.request(att['content'], target=path, size=expected)
    path = safe(root, 'issues/' + identifier(issue['key']) + '.json')
    atomic(path, issue)
    return jira_record(root, issue, binaries=binaries)


def spaces(api):
    values = []
    link = '/api/v2/spaces?limit=250'
    seen = set()
    while link:
        if link in seen:
            raise CorpusError('Confluence spaces pagination repeated a cursor. Retry discovery.')
        seen.add(link)
        page = api.request(link)
        if not isinstance(page.get('results'), list):
            raise CorpusError('Confluence spaces response omitted results. Check authentication and permissions.')
        values.extend(page['results'])
        link = page.get('_links', {}).get('next')
    return sorted(values, key=lambda value: value['key'])


def confluence_catalog(root, api, args):
    catalog = checked_manifest(root / 'corpus.json', api.site) or dict(schema=SCHEMA, site=api.site, source='confluence', scopes=[], selection='all')
    if catalog.get('source') != 'confluence':
        raise CorpusError('This root belongs to another source. Choose the Confluence corpus root.')
    current = spaces(api)
    selection = args.spaces or catalog.get('selection', 'all')
    selected_keys = {s['key'] for s in current} if selection == 'all' else set(selection.split(','))
    missing = selected_keys - {s['key'] for s in current}
    if missing:
        raise CorpusError(f'Confluence keys not accessible: {", ".join(sorted(missing))}. Run spaces and check the account has access; no checkpoints were changed.')
    selected = []
    for space in current:
        if space['key'] not in selected_keys:
            continue
        sid = identifier(space['id'])
        scope = next((s for s in catalog['scopes'] if s['id'] == sid), None)
        if scope is None:
            scope = dict(id=sid, key=space['key'], path='spaces/' + sid, aliases=[])
            catalog['scopes'].append(scope)
        elif scope['key'] != space['key']:
            scope.setdefault('aliases', []).append(scope['key'])
            scope['key'] = space['key']
        selected.append(dict(scope, remote=space))
    return catalog, selected


def confluence_listing(api, key, since=None):
    cql = 'space = ' + json.dumps(key) + ' AND type IN (page,blogpost,comment,attachment)'
    if since:
        # CQL dates use the account timezone; two UTC calendar days cover the 24h overlap in every timezone.
        cql += ' AND lastmodified >= ' + json.dumps((date(since) - dt.timedelta(days=2)).strftime('%Y-%m-%d'))
    link = '/rest/api/content/search?' + urllib.parse.urlencode(dict(cql=cql + ' ORDER BY lastmodified ASC', limit=100, expand='version,container,space'))
    results = {}
    seen = set()
    while link:
        if link in seen:
            raise CorpusError('Confluence pagination repeated a cursor. Retry to restart metadata discovery.')
        seen.add(link)
        page = api.request(link)
        if not isinstance(page.get('results'), list):
            raise CorpusError('Confluence content search omitted results. Check account access.')
        for item in page['results']:
            results[str(item['id'])] = item
        link = page.get('_links', {}).get('next')
    return list(results.values())


def confluence_record(root, content, path):
    kind = content['type']
    attachments = []
    complete = True
    if kind == 'attachment':
        binary = path.parent / 'content'
        size = content.get('extensions', {}).get('fileSize', 0)
        complete = binary.is_file() and (size == 0 or binary.stat().st_size == size)
        if complete:
            attachments.append(receipt(root, binary, id=str(content['id']), name=content.get('title', ''), media_type=content.get('extensions', {}).get('mediaType', ''), remote_size=size, validation='remote-size' if size else 'local-hash-size-unknown'))
    return dict(id=str(content['id']), key=str(content['id']), kind=kind, version=content.get('version', {}).get('number', 0), updated=content.get('version', {}).get('when', ''), parent_id=str(content.get('container', {}).get('id', '')), file=receipt(root, path), attachments=attachments, complete=complete, attachments_complete=complete, availability='available')


def confluence_fetch(api, root, remote, previous=None, hashes=False):
    ident = identifier(remote['id'])
    content = api.request('/rest/api/content/' + ident, {'expand': 'body.storage,version,container,ancestors,space,metadata.labels'})
    if str(content.get('id')) != ident or content.get('type') not in ('page', 'blogpost', 'comment', 'attachment'):
        raise CorpusError('Confluence content identity/type mismatch. Retry after checking API/proxy configuration.')
    kind = content['type']
    if kind == 'attachment':
        version = identifier(content['version']['number'])
        path = safe(root, f'attachments/{ident}/v{version}/metadata.json')
        binary = path.parent / 'content'
        size = content.get('extensions', {}).get('fileSize', 0)
        atomic(path, content)
        old = next(iter((previous or {}).get('attachments', [])), None)
        if not binary.is_file() or (size > 0 and binary.stat().st_size != size) or (old and old['path'] == str(binary.relative_to(root)) and not intact(root, old, hashes)):
            link = content.get('_links', {}).get('download') or remote.get('_links', {}).get('download')
            if not link:
                raise CorpusError('Attachment download link is missing. Check content access and retry.')
            try:
                api.request(link, target=binary, size=size)
            except CorpusError as exc:
                exc.partial_record = confluence_record(root, content, path)
                raise
    else:
        path = safe(root, f'{kind}s/{ident}.json')
        if not content.get('body', {}).get('storage'):
            raise CorpusError('Confluence response omitted the requested body. Check access and retry; previous content is retained.')
    atomic(path, content)
    return confluence_record(root, content, path)


def sync_scope(api, root, scope, args):
    root.mkdir(parents=True, exist_ok=True)
    source = args.source
    started = time.monotonic()
    started_at = now()
    attempt_at = started_at
    manifest = inventory(root, api.site, source)
    state = checked_manifest(root / '.sync/state.json', api.site) or {}
    pending = checked_manifest(root / '.sync/pending.json', api.site)
    reconcile = not state.get('reconciled_at') or date(started_at) - date(state['reconciled_at']) > dt.timedelta(days=7)
    full = reconcile or not state.get('watermark') or bool(args.jql or args.filter)
    if pending and args.mode == 'resume':
        if pending['scope_id'] != scope['id']:
            raise CorpusError('Pending run belongs to another scope. Check the destination directory.')
        remote = pending['records']
        started_at = pending['started_at']
        full = pending['full_inventory']
        log(f"{scope['key']}: resuming frozen metadata selection ({len(remote)} records).")
    else:
        log(f"{scope['key']}: {'complete metadata reconciliation' if full else 'delta metadata discovery with overlap'}...")
        if source == 'jira':
            query = re.sub(r'\s+ORDER\s+BY\s+.*$', '', scope['jql'], flags=re.I)
            if not full:
                lower = date(state['watermark']) - dt.timedelta(hours=24)
                zone = ZoneInfo(api.timezone)
                upper = date(started_at) + dt.timedelta(minutes=1)
                query = f'({query}) AND updated >= "{lower.astimezone(zone).strftime("%Y-%m-%d %H:%M")}" AND updated < "{upper.astimezone(zone).strftime("%Y-%m-%d %H:%M")}"'
            remote = jira_listing(api, query + ' ORDER BY updated ASC, key ASC')
        else:
            remote = confluence_listing(api, scope['key'], None if full else state['watermark'])
        if args.command == 'sync':
            atomic(root / '.sync/pending.json', dict(schema=SCHEMA, site=api.site, scope_id=scope['id'], started_at=started_at, full_inventory=full, records=remote))
    records = manifest['records']
    remote_ids = {str(r['id']) for r in remote}
    repairs = []
    for ident, record in records.items():
        if ident not in remote_ids and not files_ok(root, record, args.attachments, args.hashes):
            if source == 'jira':
                repairs.append(dict(id=ident, key=record['key'], fields={'updated': record['updated']}))
            else:
                repairs.append(dict(id=ident, type=record['kind'], version={'number': record['version']}))
    selected = []
    for item in remote + repairs:
        old = records.get(str(item['id']))
        if not old or not fresh(old, item, source) or not files_ok(root, old, args.attachments, args.hashes):
            selected.append(item)
    binary_bytes = 0
    for item in selected:
        if source == 'jira' and args.attachments:
            for att in item.get('fields', {}).get('attachment', []):
                file = attachment_path(root, item['key'], att)
                size = att.get('size', 0)
                if not file.is_file() or (size > 0 and file.stat().st_size != size):
                    binary_bytes += size
        elif source == 'confluence' and item['type'] == 'attachment':
            binary_bytes += item.get('extensions', {}).get('fileSize', 0)
    history = state.get('last_transfer_run') or state.get('last_run')
    forecast = estimate(len(selected), binary_bytes, history, args.workers)
    log(f"{scope['key']}: {len(remote)} metadata records, {len(selected)} to fetch/repair, {len(remote) + len(repairs) - len(selected)} reused.")
    show_estimate(forecast)
    if args.command == 'estimate':
        return dict(scope=scope['key'], **forecast)
    check_disk(root, binary_bytes)
    discovery_seconds = time.monotonic() - started
    before = dict(api.stats)
    failures = []
    completed = 0
    download_start = time.monotonic()
    last_log = download_start
    save_manifest(root, manifest)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(jira_fetch, api, root, item, args.attachments, records.get(str(item['id'])), args.hashes) if source == 'jira' else pool.submit(confluence_fetch, api, root, item, records.get(str(item['id'])), args.hashes): item for item in selected}
        for future in concurrent.futures.as_completed(futures):
            item = futures[future]
            try:
                record = future.result()
                if not record['complete'] or (args.attachments and not record.get('attachments_complete', True)):
                    raise CorpusError('Downloaded record is incomplete. Retry the item; the checkpoint is retained.')
                records[record['id']] = record
                atomic(root / '.sync/receipts' / (identifier(record['id']) + '.json'), record)
                completed += 1
                if completed % 100 == 0:
                    save_manifest(root, manifest)
            except Exception as exc:
                partial = getattr(exc, 'partial_record', None)
                if partial:
                    records[partial['id']] = partial
                    atomic(root / '.sync/receipts' / (identifier(partial['id']) + '.json'), partial)
                label = item.get('key', item['id'])
                message = str(exc) if isinstance(exc, CorpusError) else f'{type(exc).__name__}: local processing failed; check the input record and permissions.'
                failures.append(dict(id=str(item['id']), error=message))
                log(f"FAILED {source}/{scope['key']}/{label}: {message}")
            elapsed = time.monotonic() - download_start
            if time.monotonic() - last_log > 20 or completed + len(failures) == len(selected):
                remaining = (len(selected) - completed - len(failures)) * elapsed / max(1, completed + len(failures))
                log(f"{scope['key']}: {completed}/{len(selected)} complete, {len(failures)} failed, {(api.stats['downloaded_bytes'] - before['downloaded_bytes']) / 1e9:.3f} GB transferred, ETA {remaining / 60:.1f} min.")
                last_log = time.monotonic()
    if full:
        for ident, record in records.items():
            if ident not in remote_ids:
                record['availability'] = 'not-seen-in-current-scope; retained'
    save_manifest(root, manifest)
    if source == 'jira':
        keys = sorted({r['key'] for r in records.values()})
        atomic(root / 'keys.txt', ('\n'.join(keys) + '\n').encode(), binary=True)
    result = dict(schema=SCHEMA, source=source, scope=scope['key'], scope_id=scope['id'], started_at=started_at, attempt_at=attempt_at, finished_at=now(), outcome='partial' if failures else 'complete', selected=len(selected), fetched=completed, reused=len(remote) + len(repairs) - len(selected), discovered=len(remote), forecast=forecast, discovery_seconds=round(discovery_seconds, 3), download_seconds=round(time.monotonic() - download_start, 3), elapsed_seconds=round(time.monotonic() - started, 3), concurrency=args.workers, failures=failures, **{k: v - before[k] for k, v in api.stats.items()})
    run_id = attempt_at.replace(':', '').replace('+', '_')
    atomic(root / '.sync/runs' / (run_id + '.json'), result)
    if not failures:
        if completed:
            state['last_transfer_run'] = result
        elif history and history.get('fetched'):
            state['last_transfer_run'] = history
        state.update(schema=SCHEMA, site=api.site, watermark=started_at, last_run=result)
        if full:
            state['reconciled_at'] = started_at
        atomic(root / '.sync/state.json', state)
        (root / '.sync/pending.json').unlink(missing_ok=True)
    log(f"{scope['key']}: {result['outcome']}; {result['elapsed_seconds']:.1f}s actual; {result['downloaded_bytes'] / 1e9:.3f} GB downloaded. Checkpoint {'retained' if failures else 'advanced'}.")
    return result


def sync(api, root, args):
    catalog, selected = project_catalog(root, api, args) if args.source == 'jira' else confluence_catalog(root, api, args)
    if args.mode == 'full':
        occupied = [s['key'] for s in selected if any(safe(root, s['path']).glob('issues/*.json')) or any(safe(root, s['path']).glob('pages/*.json')) or (safe(root, s['path']) / 'manifest.json').exists()]
        if occupied:
            raise CorpusError('Full mode requires empty selected destinations: ' + ', '.join(occupied) + '. Use --mode delta or --mode resume to preserve and reuse these files.')
    if args.command == 'sync':
        atomic(root / 'corpus.json', catalog)
    results = []
    for scope in selected:
        folder = safe(root, scope['path'])
        try:
            if args.source == 'confluence' and args.command == 'sync':
                atomic(folder / 'space.json', scope['remote'])
            results.append(sync_scope(api, folder, scope, args))
        except CorpusError as exc:
            log(f"FAILED {args.source}/{scope['key']} during discovery/validation: {exc}")
            results.append(dict(scope=scope['key'], outcome='failed', error=str(exc)))
    if args.command == 'sync':
        atomic(root / '.sync/last-run.json', dict(source=args.source, finished_at=now(), results=results, api=api.stats))
    return results


def verify(root, hashes=False):
    catalog = checked_manifest(root / 'corpus.json')
    if not catalog:
        raise CorpusError('No corpus catalog. Run sync --mode delta to adopt local files and reconcile metadata.')
    errors = []
    count = 0
    for scope in catalog['scopes']:
        folder = safe(root, scope['path'])
        manifest = checked_manifest(folder / 'manifest.json', catalog['site'])
        if manifest is None:
            errors.append(f"{scope['key']}: manifest missing; run delta to adopt existing files")
            continue
        if (folder / '.sync/pending.json').exists():
            errors.append(f"{scope['key']}: unfinished sync selection; run resume and review any inaccessible remote records")
        for record in manifest['records'].values():
            count += 1
            if count % 2000 == 0:
                log(f'Verify: {count} records checked; {len(errors)} problems so far.')
            if not record.get('complete'):
                errors.append(f"{scope['key']}/{record['id']}: incomplete record")
            for component in [record['file']] + record.get('attachments', []):
                if not intact(folder, component, hashes):
                    errors.append(f"{scope['key']}/{record['id']}: missing or changed {component['path']}")
    for error in errors[:30]:
        log('VERIFY FAILED: ' + error + '. Run sync --mode delta --hashes to repair selectively.')
    log(f'Verified {count} records; {len(errors)} problems; binary verification: {"SHA-256" if hashes else "size and changed-file SHA-256"}.')
    return errors
