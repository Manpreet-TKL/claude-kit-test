import copy
import io
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request

from common import API, CorpusError, Redirect, atomic, checked_manifest, digest, load, receipt, safe
import download
import indexing
from main import parser


def issue(number=1, updated='2025-01-01T12:00:00+00:00'):
    return dict(id=str(number), key=f'TEST-{number}', fields=dict(project=dict(id='1', key='TEST'), summary='Example SQL repair', updated=updated, description={'type': 'doc', 'content': [{'type': 'codeBlock', 'content': [{'type': 'text', 'text': 'Fixed duplicates using UPDATE sample_table SET active=0 WHERE id=7;'}]}]}, comment=dict(total=2, comments=[dict(id='1', body='First comment')]), attachment=[dict(id=str(100 + number), filename='repair.sql', size=36, content='/binary/' + str(number), mimeType='text/plain')]))


class FakeAPI:
    site = 'https://example.invalid'
    timezone = 'UTC'

    def __init__(self, source='jira'):
        self.source = source
        self.stats = dict(requests=0, retries=0, json_bytes=0, downloaded_bytes=0)
        self.calls = []
        self.issues = [issue()]
        self.broken = False
        self.delta_empty = False
        self.contents = {
            '10': dict(id='10', type='page', title='Example', version=dict(number=1, when='2025-01-01T00:00:00Z'), body=dict(storage=dict(value='<p>SQL example</p>')), space=dict(key='SPACE')),
            '11': dict(id='11', type='comment', title='', version=dict(number=1, when='2025-01-01T00:00:00Z'), body=dict(storage=dict(value='<p>Resolved using DELETE FROM sample_table WHERE id=7;</p>')), container=dict(id='10'), space=dict(key='SPACE')),
            '12': dict(id='12', type='attachment', title='repair.sql', version=dict(number=1, when='2025-01-01T00:00:00Z'), extensions=dict(fileSize=36, mediaType='text/plain'), container=dict(id='10'), _links=dict(download='/download/12'), space=dict(key='SPACE')),
        }

    def request(self, link, params=None, target=None, size=None):
        self.calls.append((link, params))
        self.stats['requests'] += 1
        if target:
            if self.broken:
                raise CorpusError('HTTP 503. Synthetic interrupted attachment; resume to repair.')
            data = b'UPDATE sample_table SET active = 0;\n'
            Path(target).parent.mkdir(parents=True, exist_ok=True)
            Path(target).write_bytes(data)
            self.stats['downloaded_bytes'] += len(data)
            return len(data)
        if link == '/rest/api/3/search/jql':
            if self.delta_empty and 'updated >=' in params['jql']:
                return dict(issues=[])
            if params.get('nextPageToken'):
                return dict(issues=copy.deepcopy(self.issues[1:]))
            return dict(issues=copy.deepcopy(self.issues[:1]), **({'nextPageToken': 'next'} if len(self.issues) > 1 else {}))
        if link.startswith('/rest/api/3/project/'):
            return dict(id='1', key='TEST')
        if link.endswith('/comment'):
            start = params['startAt']
            return dict(total=2, comments=[dict(id=str(start + 1), body='Resolved using DELETE FROM sample_table WHERE id=7;')])
        if link.startswith('/rest/api/3/issue/'):
            return copy.deepcopy(next(i for i in self.issues if i['id'] == link.split('/')[-1]))
        if link.startswith('/api/v2/spaces'):
            return dict(results=[dict(id='1', key='SPACE', name='Synthetic'), dict(id='2', key='SECOND', name='Synthetic second')])
        if link.startswith('/rest/api/content/search'):
            from urllib.parse import parse_qs, urlsplit
            query = parse_qs(urlsplit(link).query)['cql'][0]
            if 'SECOND' in query:
                return dict(results=[])
            if self.delta_empty and 'lastmodified' in query:
                return dict(results=[])
            return dict(results=copy.deepcopy(list(self.contents.values())))
        if link.startswith('/rest/api/content/'):
            return copy.deepcopy(self.contents[link.split('/')[-1]])
        raise AssertionError(link)


class CorpusTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.api = FakeAPI()
        self.args = parser().parse_args(['sync', '--source', 'jira', '--projects', 'TEST'])

    def tearDown(self):
        self.temp.cleanup()

    def sync(self, root=None):
        return download.sync(self.api, root or self.root, self.args)

    def test_jira_full_pagination_delta_and_noop(self):
        self.api.issues.append(issue(2))
        self.args.mode = 'full'
        first = self.sync()[0]
        self.assertEqual(first['fetched'], 2)
        saved = load(self.root / 'TEST/issues/TEST-1.json')
        self.assertEqual(len(saved['fields']['comment']['comments']), 2)
        self.args.mode = 'delta'
        second = self.sync()[0]
        self.assertEqual(second['downloaded_bytes'], 0)
        self.assertEqual(second['fetched'], 0)
        self.api.issues[0]['fields']['updated'] = '2025-02-01T12:00:00+00:00'
        third = self.sync()[0]
        self.assertEqual(third['fetched'], 1)
        self.assertEqual(third['downloaded_bytes'], 0)

    def test_failure_does_not_advance_and_resume_reuses(self):
        self.api.broken = True
        result = self.sync()[0]
        self.assertEqual(result['outcome'], 'partial')
        self.assertFalse((self.root / 'TEST/.sync/state.json').exists())
        self.api.broken = False
        self.args.mode = 'resume'
        self.assertEqual(self.sync()[0]['fetched'], 1)
        self.assertTrue((self.root / 'TEST/.sync/state.json').exists())

    def test_relocation_missing_state_and_same_size_damage(self):
        self.sync()
        copied = self.root / 'relocated'
        copied.mkdir()
        shutil.copytree(self.root / 'TEST', copied / 'TEST')
        shutil.copy2(self.root / 'corpus.json', copied / 'corpus.json')
        self.assertEqual(self.sync(copied)[0]['fetched'], 0)
        shutil.rmtree(copied / 'TEST/.sync')
        (copied / 'TEST/manifest.json').unlink()
        self.assertEqual(self.sync(copied)[0]['fetched'], 0)
        binary = next((copied / 'TEST/attachments/TEST-1').iterdir())
        binary.write_bytes(b'x' * binary.stat().st_size)
        self.api.delta_empty = True
        result = self.sync(copied)[0]
        self.assertEqual(result['fetched'], 1)
        self.assertGreater(result['downloaded_bytes'], 0)
        self.assertEqual(download.verify(copied, hashes=True), [])

    def test_legacy_zero_size_adoption(self):
        self.sync()
        path = self.root / 'TEST/issues/TEST-1.json'
        saved = load(path)
        saved['fields']['attachment'][0]['size'] = 0
        atomic(path, saved)
        (self.root / 'TEST/manifest.json').unlink()
        shutil.rmtree(self.root / 'TEST/.sync')
        self.api.issues[0]['fields']['attachment'][0]['size'] = 0
        result = self.sync()[0]
        self.assertEqual(result['fetched'], 0)
        att = load(self.root / 'TEST/manifest.json')['records']['1']['attachments'][0]
        self.assertEqual(att['validation'], 'local-hash-size-unknown')

    def test_full_refuses_existing_scope(self):
        self.sync()
        self.args.mode = 'full'
        with self.assertRaises(CorpusError):
            self.sync()

    def test_confluence_single_space_and_independent_comments(self):
        self.api = FakeAPI('confluence')
        self.args = parser().parse_args(['sync', '--source', 'confluence', '--spaces', 'all'])
        self.sync()
        baseline = {str(p.relative_to(self.root)): p.read_bytes() for p in (self.root / 'spaces/2').rglob('*') if p.is_file()}
        self.args.spaces = 'SPACE'
        self.api.contents['11']['version']['number'] = 2
        result = self.sync()[0]
        self.assertEqual(result['fetched'], 1)
        self.assertEqual(load(self.root / 'corpus.json')['selection'], 'all')
        for relative, data in baseline.items():
            self.assertEqual((self.root / relative).read_bytes(), data)
        self.assertEqual(load(self.root / 'spaces/1/manifest.json')['records']['11']['version'], 2)

    def test_path_and_schema_guards(self):
        with self.assertRaises(CorpusError):
            safe(self.root, '../escape')
        atomic(self.root / 'corpus.json', dict(schema=999, site=self.api.site))
        with self.assertRaises(CorpusError):
            checked_manifest(self.root / 'corpus.json', self.api.site)
        atomic(self.root / 'corpus.json', dict(schema=1, site='https://other.invalid'))
        with self.assertRaises(CorpusError):
            checked_manifest(self.root / 'corpus.json', self.api.site)

    def test_anonymous_success_is_rejected(self):
        api = API.__new__(API)
        api.source = 'confluence'
        api.request = lambda _: dict(type='anonymous')
        with self.assertRaises(CorpusError):
            api.auth_check()

    def test_redirect_strips_credentials(self):
        req = urllib.request.Request('https://example.invalid/a', headers={'Authorization': 'Basic synthetic'})
        result = Redirect().redirect_request(req, None, 302, '', {}, 'https://media.invalid/file')
        self.assertIsNone(result.get_header('Authorization'))
        with self.assertRaises(CorpusError):
            Redirect().redirect_request(req, None, 302, '', {}, 'http://media.invalid/file')

    def test_index_incremental_and_detector_rebuild_offline(self):
        self.sync()
        args = parser().parse_args(['index', '--source', 'jira', '--mode', 'rebuild'])
        args.jira_root = self.root
        args.index_root = self.root / 'index'
        indexing.build(args)
        import sqlite3
        db = sqlite3.connect(args.index_root / 'corpus.sqlite')
        self.assertEqual(db.execute('SELECT count(*) FROM documents').fetchone()[0], 2)
        self.assertGreater(db.execute("SELECT count(*) FROM sql_candidates WHERE kind='data-change'").fetchone()[0], 0)
        db.close()
        args.mode = 'update'
        indexing.build(args)
        self.assertEqual(load(args.index_root / 'last-index-run.json')['changed'], 0)
        with patch.object(indexing, 'DETECTOR_VERSION', 'test-next'):
            indexing.build(args)
        self.assertEqual(load(args.index_root / 'last-index-run.json')['changed'], 2)
        (args.index_root / 'corpus.sqlite').unlink()
        indexing.build(args)
        self.assertEqual(load(args.index_root / 'last-index-run.json')['mode'], 'rebuild')

    def test_sql_content_not_filename_or_loose_prose(self):
        self.assertEqual(list(indexing.sql_candidates([('description', 'Attach repair.sql and update your settings.')])), [])
        found = list(indexing.sql_candidates([('comment/1', 'Fixed using UPDATE sample_table SET active=0 WHERE id=7;')]))
        self.assertEqual(found[0]['kind'], 'data-change')
        self.assertIn('sample_table', found[0]['tables'])
        self.assertIn('comment/1', found[0]['location'])

    def test_text_first_then_attachment_index_and_scoped_update(self):
        self.api = FakeAPI('confluence')
        self.args = parser().parse_args(['sync', '--source', 'confluence', '--spaces', 'all'])
        self.sync()
        args = parser().parse_args(['index', '--source', 'confluence', '--mode', 'rebuild', '--text-only'])
        args.confluence_root = self.root
        args.index_root = self.root / 'index'
        indexing.build(args)
        self.assertEqual(load(args.index_root / 'last-index-run.json')['documents'], 3)
        args.text_only = False
        args.mode = 'update'
        indexing.build(args)
        self.assertEqual(load(args.index_root / 'last-index-run.json')['documents'], 4)
        import sqlite3
        db = sqlite3.connect(args.index_root / 'corpus.sqlite')
        original = db.execute('SELECT * FROM documents ORDER BY id').fetchall()
        db.close()
        args.spaces = 'SECOND'
        indexing.build(args)
        self.assertEqual(load(args.index_root / 'last-index-run.json')['changed'], 0)
        db = sqlite3.connect(args.index_root / 'corpus.sqlite')
        self.assertEqual(original, db.execute('SELECT * FROM documents ORDER BY id').fetchall())
        db.close()

    def test_search_filters_and_sql_provenance(self):
        self.sync()
        args = parser().parse_args(['index', '--source', 'jira', '--mode', 'rebuild'])
        args.jira_root = self.root
        args.index_root = self.root / 'index'
        indexing.build(args)
        args.command = 'search'
        args.query = 'duplicates'
        args.sql_kind = 'data-change'
        args.format = 'json'
        with patch('sys.stdout', new_callable=io.StringIO) as output:
            indexing.search(args)
        response = json.loads(output.getvalue())
        self.assertTrue(response['results'])
        self.assertTrue(all(r['kind'] == 'data-change' for r in response['results']))
        self.assertIn('local_file', response['results'][0])
        self.assertIn('location', response['results'][0])

    def test_transport_retries_and_length_validation(self):
        import threading
        class Response(io.BytesIO):
            headers = {'Content-Length': '4'}
        api = API.__new__(API)
        api.site = api.base = 'https://example.invalid'
        api.source = 'jira'
        api.auth = 'Basic synthetic'
        api.mutex = threading.Lock()
        api.blocked_until = 0
        api.stats = dict(requests=0, retries=0, json_bytes=0, downloaded_bytes=0)
        from unittest.mock import Mock
        api.opener = Mock()
        api.opener.open.side_effect = [urllib.error.HTTPError(api.site, 429, 'retry', {'Retry-After': '0'}, None), io.BytesIO(b'{"ok":true}')]
        self.assertEqual(api.request('/test'), {'ok': True})
        self.assertEqual(api.stats['retries'], 1)
        target = self.root / 'binary'
        target.write_bytes(b'old')
        api.opener.open.side_effect = [Response(b'xx')]
        with self.assertRaises(CorpusError):
            api.request('/download', target=target, size=4)
        self.assertEqual(target.read_bytes(), b'old')
        self.assertEqual(list(self.root.glob('*.part-*')), [])

    def test_invalid_json_does_not_replace_previous(self):
        self.sync()
        path = self.root / 'TEST/issues/TEST-1.json'
        original = path.read_bytes()
        self.api.issues[0]['fields']['updated'] = '2025-02-01T00:00:00Z'
        real = self.api.request
        def request(link, *args, **kwargs):
            if link.startswith('/rest/api/3/issue/'):
                raise CorpusError('API returned invalid JSON. Retry.')
            return real(link, *args, **kwargs)
        self.api.request = request
        checkpoint = (self.root / 'TEST/.sync/state.json').read_bytes()
        self.assertEqual(self.sync()[0]['outcome'], 'partial')
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual((self.root / 'TEST/.sync/state.json').read_bytes(), checkpoint)

    def test_unavailable_confluence_binary_keeps_metadata_and_failed_checkpoint(self):
        self.api = FakeAPI('confluence')
        self.args = parser().parse_args(['sync', '--source', 'confluence', '--spaces', 'SPACE'])
        self.api.broken = True
        self.assertEqual(self.sync()[0]['outcome'], 'partial')
        manifest = load(self.root / 'spaces/1/manifest.json')
        self.assertFalse(manifest['records']['12']['complete'])
        self.assertTrue((self.root / 'spaces/1/attachments/12/v1/metadata.json').exists())
        self.assertFalse((self.root / 'spaces/1/.sync/state.json').exists())
        self.api.broken = False
        self.args.mode = 'resume'
        self.assertEqual(self.sync()[0]['fetched'], 1)
        self.assertTrue(load(self.root / 'spaces/1/manifest.json')['records']['12']['complete'])

    def test_key_rename_reuses_binary_and_keeps_one_identity(self):
        self.sync()
        self.api.issues[0]['key'] = 'RENAMED-1'
        self.api.issues[0]['fields']['updated'] = '2025-03-01T00:00:00Z'
        result = self.sync()[0]
        self.assertEqual(result['fetched'], 1)
        self.assertEqual(result['downloaded_bytes'], 0)
        records = load(self.root / 'TEST/manifest.json')['records']
        self.assertEqual(list(records), ['1'])
        self.assertEqual(records['1']['key'], 'RENAMED-1')

    def test_preserved_mtime_damage_requires_explicit_hash_scan(self):
        self.sync()
        path = next((self.root / 'TEST/attachments/TEST-1').iterdir())
        stat = path.stat()
        path.write_bytes(b'x' * stat.st_size)
        os.utime(path, ns=(stat.st_atime_ns, stat.st_mtime_ns))
        self.args.hashes = True
        self.assertEqual(self.sync()[0]['fetched'], 1)
        self.assertEqual(download.verify(self.root, hashes=True), [])

    def test_legacy_query_can_add_attachments_on_resume(self):
        self.args = parser().parse_args(['sync', '--source', 'jira', '--jql', 'project = TEST', '--mode', 'full', '--no-attachments'])
        first = self.sync()[0]
        self.assertEqual(first['downloaded_bytes'], 0)
        self.assertTrue((self.root / 'issues/TEST-1.json').exists())
        self.args.mode = 'resume'
        self.args.attachments = True
        second = self.sync()[0]
        self.assertEqual(second['fetched'], 1)
        self.assertEqual(second['downloaded_bytes'], 36)
        self.assertEqual(self.sync()[0]['fetched'], 0)


if __name__ == '__main__':
    unittest.main()
