import argparse
import os
from pathlib import Path
import shlex
import sys

from common import API, CorpusError, locked, log
import download


def parser():
    home = Path(os.environ.get('CORPUS_HOME', str(Path.home())))
    p = argparse.ArgumentParser(description='Deterministic Jira/Confluence download and local FTS5 search. No model services are used.')
    p.add_argument('command', choices=['auth', 'spaces', 'estimate', 'sync', 'inventory', 'verify', 'index', 'search', 'test', 'help'])
    p.add_argument('-s', '--source', choices=['jira', 'confluence', 'all'], default=None)
    p.add_argument('-m', '--mode', choices=['full', 'delta', 'resume', 'rebuild', 'update'], default='delta')
    p.add_argument('-R', '--root', type=Path, help='Root for the selected download source')
    p.add_argument('-J', '--jira-root', type=Path, default=home / 'jira-corpus')
    p.add_argument('-C', '--confluence-root', type=Path, default=home / 'confluence-corpus')
    p.add_argument('-I', '--index-root', type=Path, default=home / 'corpus-index')
    p.add_argument('-E', '--credential-file', type=Path, default=home / '.claude/mcp-env/.atlassian.env')
    p.add_argument('-p', '--projects', help='Comma-separated Jira project keys; KEY:folder selects a destination name')
    p.add_argument('-S', '--spaces', help='all or comma-separated Confluence keys; one-key refresh leaves other spaces untouched')
    p.add_argument('-j', '--jql', help='Legacy single-output Jira query; reconciled in full on every run')
    p.add_argument('-f', '--filter', help='Legacy saved Jira filter ID')
    p.add_argument('-a', '--attachments', action='store_true', default=True)
    p.add_argument('-A', '--no-attachments', action='store_false', dest='attachments')
    p.add_argument('-w', '--workers', type=int, choices=range(1, 9), default=4)
    p.add_argument('-H', '--hashes', action='store_true', help='Verify every file SHA-256, including unchanged files')
    p.add_argument('-T', '--text-only', action='store_true', help='Index structured text first; a later update adds attachment contents')
    p.add_argument('-q', '--query', default='', help='FTS5 query; quote phrases using double quotes')
    p.add_argument('-k', '--key', help='Exact Jira key or Confluence content ID')
    p.add_argument('-K', '--sql-kind', choices=['diagnostic', 'data-change', 'schema-change', 'any'])
    p.add_argument('-t', '--table', help='SQL table identifier filter')
    p.add_argument('-d', '--since', help='Updated-date lower bound (ISO date)')
    p.add_argument('-u', '--until', help='Updated-date upper bound (ISO date)')
    p.add_argument('-l', '--limit', type=int, default=20)
    p.add_argument('-F', '--format', choices=['text', 'json'], default='text')
    return p


def main():
    p = parser()
    args = p.parse_args()
    if args.source is None:
        args.source = 'all' if args.command in ('index', 'search', 'inventory', 'verify') else 'jira'
    if args.command == 'help':
        p.print_help()
        return 0
    if args.command == 'test':
        import unittest
        suite = unittest.defaultTestLoader.discover(str(Path(__file__).parent), pattern='test_corpus.py')
        return not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful()
    if args.root:
        if args.source == 'all':
            p.error('--root requires one --source; use --jira-root and --confluence-root for both')
        setattr(args, args.source + '_root', args.root)
    for name in ('jira_root', 'confluence_root', 'index_root'):
        override = os.environ.get('CORPUS_' + name.upper())
        setattr(args, name, Path(override or getattr(args, name)).resolve())
    args.credential_file = Path(os.environ.get('CORPUS_CREDENTIAL_PATH', str(args.credential_file)))
    if args.command == 'index':
        if args.mode not in ('rebuild', 'update'):
            p.error('index requires --mode rebuild or --mode update')
        import indexing
        with locked(args.index_root):
            indexing.build(args)
        return 0
    if args.command == 'search':
        import indexing
        indexing.search(args)
        return 0
    if args.command == 'verify':
        failures = []
        for source in ('jira', 'confluence') if args.source == 'all' else (args.source,):
            root = getattr(args, source + '_root')
            with locked(root):
                failures.extend(download.verify(root, args.hashes))
        return bool(failures)
    if args.command == 'inventory':
        import json
        from common import checked_manifest, safe
        results = []
        for source in ('jira', 'confluence') if args.source == 'all' else (args.source,):
            root = getattr(args, source + '_root')
            catalog = checked_manifest(root / 'corpus.json')
            if not catalog:
                results.append(dict(source=source, status='catalog missing; run delta to adopt local files'))
                continue
            for scope in catalog['scopes']:
                folder = safe(root, scope['path'])
                manifest = checked_manifest(folder / 'manifest.json', catalog['site'])
                records = list((manifest or {}).get('records', {}).values())
                state = checked_manifest(folder / '.sync/state.json', catalog['site']) or {}
                results.append(dict(source=source, key=scope['key'], path=scope['path'], records=len(records), incomplete=sum(not r['complete'] for r in records), json_bytes=sum(r['file']['size'] for r in records), attachment_files=sum(len(r.get('attachments', [])) for r in records), attachment_bytes=sum(a['size'] for r in records for a in r.get('attachments', [])), pending=(folder / '.sync/pending.json').exists(), watermark=state.get('watermark'), last_run=state.get('last_run')))
        print(json.dumps(results))
        return 0
    if args.command == 'spaces':
        args.source = 'confluence'
    if args.source == 'all':
        p.error('Download one source at a time with --source jira or --source confluence')
    if args.mode not in ('full', 'delta', 'resume'):
        p.error('Downloads require --mode full, delta or resume')
    api = API(args.credential_file, args.source)
    api.auth_check()
    if args.command == 'auth':
        return 0
    if args.command == 'spaces':
        values = download.spaces(api)
        for space in values:
            log(f"{space['key']}\t{space['id']}\t{space.get('name', '')}")
        log(f'{len(values)} accessible spaces.')
        return 0
    root = getattr(args, args.source + '_root')
    with locked(root):
        results = download.sync(api, root, args)
    failures = any(r.get('outcome') in ('failed', 'partial') for r in results)
    if failures:
        log('One or more scopes failed; successful scopes have independent checkpoints. Resume after correcting the errors above.')
        retry = ['bash', str(Path(os.environ.get('CORPUS_HOME', str(Path.home())))) + '/claude-kit/scripts/corpus.sh', 'sync', '--source', args.source, '--root', str(root), '--mode', 'resume']
        if args.projects:
            retry.extend(['--projects', args.projects])
        if args.spaces:
            retry.extend(['--spaces', args.spaces])
        log('Resume: ' + shlex.join(retry))
    return bool(failures)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (CorpusError, OSError) as exc:
        message = str(exc) if isinstance(exc, CorpusError) else f'{type(exc).__name__}: local filesystem operation failed. Check free space, ownership and file access.'
        log('FAILED: ' + message)
        command = ['bash', '~/claude-kit/scripts/corpus.sh', *sys.argv[1:]]
        if '--mode' in command and command[command.index('--mode') + 1] == 'full':
            command[command.index('--mode') + 1] = 'resume'
        log('After correcting the problem, rerun: ' + shlex.join(command).replace("'~/claude-kit/scripts/corpus.sh'", '"${HOME}/claude-kit/scripts/corpus.sh"'))
        sys.exit(1)
    except KeyboardInterrupt:
        log('Interrupted. Completed files are retained; rerun sync with --mode resume.')
        sys.exit(130)
    except (KeyError, ValueError, TypeError) as exc:
        log(f'FAILED: {type(exc).__name__} while validating local metadata or an API response. Check manifest schema and run verify; retain raw files and rerun delta after correcting the input.')
        sys.exit(1)
