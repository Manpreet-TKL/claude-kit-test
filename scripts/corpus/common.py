import contextlib
import datetime as dt
import email.utils
import fcntl
import hashlib
import http.client
import json
import os
from pathlib import Path
import random
import re
import shlex
import shutil
import socket
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

SCHEMA = 1
PRINT_LOCK = threading.Lock()


class CorpusError(Exception):
    pass


def log(message):
    with PRINT_LOCK:
        print(message, flush=True)


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def date(value):
    return dt.datetime.fromisoformat(value.replace('Z', '+00:00'))


def load(path, default=None):
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        return default
    except (ValueError, UnicodeError) as exc:
        raise CorpusError(f'Invalid JSON in {path}. Restore the file or move it aside and run delta to repair it.') from exc


def atomic(path, data, binary=False):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.part-' + uuid.uuid4().hex)
    try:
        with temp.open('wb' if binary else 'w') as handle:
            handle.write(data if binary else json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')
            handle.flush()
            os.fsync(handle.fileno())
        temp.replace(path)
    finally:
        temp.unlink(missing_ok=True)


def digest(path):
    with Path(path).open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def safe(root, relative):
    root = Path(root).resolve()
    value = Path(relative)
    path = (root / value).resolve()
    if value.is_absolute() or not path.is_relative_to(root):
        raise CorpusError(f'Unsafe corpus path {relative!r}. Restore a manifest containing only paths inside its root.')
    return path


def identifier(value):
    value = str(value)
    if not value or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.~' for c in value) or value in ('.', '..'):
        raise CorpusError('Invalid remote identifier. The API response cannot safely name a local file.')
    return value


def receipt(root, path, **extra):
    path = safe(root, Path(path).relative_to(root))
    stat = path.stat()
    return dict(path=str(path.relative_to(root)), size=stat.st_size, sha256=digest(path), mtime_ns=stat.st_mtime_ns, **extra)


def intact(root, record, hashes=False):
    path = safe(root, record['path'])
    try:
        stat = path.stat()
    except FileNotFoundError:
        return False
    if stat.st_size != record['size']:
        return False
    if hashes or stat.st_mtime_ns != record.get('mtime_ns'):
        return digest(path) == record['sha256']
    return True


def checked_manifest(path, site=None):
    result = load(path)
    if result is not None:
        if result.get('schema') != SCHEMA:
            raise CorpusError(f'Unsupported manifest schema in {path}. Use a compatible script; do not overwrite the manifest.')
        if site is not None and result.get('site') != site:
            raise CorpusError(f'Site identity mismatch in {path}. Check the credential URL or choose a separate corpus root.')
    return result


@contextlib.contextmanager
def locked(root):
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    with (root / '.corpus.lock').open('a') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise CorpusError(f'Another process is using {root}. Wait for it to finish before retrying.') from exc
        yield


def credentials(path, source):
    env = {}
    for line in Path(path).read_text().splitlines():
        tokens = shlex.split(line, comments=True)
        if tokens and tokens[0] == 'export':
            tokens = tokens[1:]
        if tokens and '=' in tokens[0]:
            key, value = tokens[0].split('=', 1)
            env[key] = value
    prefix = source.upper()
    keys = [prefix + suffix for suffix in ('_URL', '_USERNAME', '_API_TOKEN')]
    if any(not env.get(key) for key in keys):
        raise CorpusError(f'Missing {prefix} URL, username or API token in {path}. Refresh the credential file locally.')
    url, user, token = (env[key] for key in keys)
    return url.rstrip('/'), user, token


class Redirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlsplit(newurl).scheme != 'https':
            raise CorpusError('Refusing an insecure attachment redirect. Check the site configuration.')
        result = super().redirect_request(req, fp, code, msg, headers, newurl)
        if urllib.parse.urlsplit(req.full_url).netloc != urllib.parse.urlsplit(newurl).netloc:
            result.remove_header('Authorization')
        return result


class API:
    def __init__(self, path, source):
        import base64
        url, user, token = credentials(path, source)
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != 'https' or parsed.username or parsed.password:
            raise CorpusError('The credential URL must be an HTTPS site URL without embedded credentials.')
        self.site = f'{parsed.scheme}://{parsed.netloc}'.lower()
        self.source = source
        self.base = self.site + ('/wiki' if source == 'confluence' else '')
        self.auth = 'Basic ' + base64.b64encode(f'{user}:{token}'.encode()).decode()
        self.opener = urllib.request.build_opener(Redirect())
        self.mutex = threading.Lock()
        self.blocked_until = 0
        self.stats = dict(requests=0, retries=0, json_bytes=0, downloaded_bytes=0)
        self.timezone = 'UTC'

    def url(self, link):
        if link.startswith('https://'):
            url = link
        elif link.startswith('/wiki/'):
            url = self.site + link
        elif link.startswith('/'):
            url = self.base + link
        else:
            url = self.base + '/' + link
        if urllib.parse.urlsplit(url).netloc != urllib.parse.urlsplit(self.site).netloc:
            raise CorpusError('API pagination or attachment URL points outside the configured site. Refusing to send credentials.')
        return url

    def request(self, link, params=None, target=None, size=None):
        url = self.url(link)
        if params:
            url += ('&' if '?' in url else '?') + urllib.parse.urlencode(params)
        temp = None
        for attempt in range(6):
            with self.mutex:
                wait = self.blocked_until - time.monotonic()
            if wait > 0:
                time.sleep(wait)
            try:
                req = urllib.request.Request(url, headers={'Authorization': self.auth, 'Accept': '*/*' if target else 'application/json'})
                with self.mutex:
                    self.stats['requests'] += 1
                with self.opener.open(req, timeout=90) as response:
                    if target:
                        target = Path(target)
                        target.parent.mkdir(parents=True, exist_ok=True)
                        temp = target.with_name(target.name + '.part-' + uuid.uuid4().hex)
                        count = 0
                        with temp.open('wb') as output:
                            while chunk := response.read(1024 * 1024):
                                output.write(chunk)
                                count += len(chunk)
                            output.flush()
                            os.fsync(output.fileno())
                        expected = response.headers.get('Content-Length')
                        if (expected is not None and count != int(expected)) or (size is not None and size > 0 and count != size):
                            raise CorpusError('Attachment length does not match the response or remote metadata. Retry to repair the incomplete file.')
                        temp.replace(target)
                        with self.mutex:
                            self.stats['downloaded_bytes'] += count
                        return count
                    raw = response.read()
                    with self.mutex:
                        self.stats['json_bytes'] += len(raw)
                    try:
                        return json.loads(raw)
                    except (ValueError, UnicodeError) as exc:
                        raise CorpusError('API returned invalid JSON. Check proxy/service availability and retry; the previous file is retained.') from exc
            except urllib.error.HTTPError as exc:
                code = exc.code
                if code not in (429, 500, 502, 503, 504):
                    reasons = {400: 'Check the query or pagination cursor; rerun to restart metadata discovery.', 401: 'Refresh the local credential file and run auth.', 403: 'Check account permissions and API token scopes.', 404: 'The record is unavailable or access changed; check it in the site. Local data is retained.'}
                    detail = ''
                    phase = 'attachment transfer' if target else 'metadata request'
                    if target and code == 404 and urllib.parse.urlsplit(exc.url).netloc != urllib.parse.urlsplit(self.site).netloc:
                        detail = 'The site redirected successfully, but remote file storage could not find the binary. Check the original attachment or ask the site administrator to restore it.'
                    if code == 400:
                        try:
                            payload = json.loads(exc.read(8192))
                            detail = payload.get('message') or '; '.join(payload.get('errorMessages', []))
                            detail = re.sub(r'https?://\S+', '[URL omitted]', detail).replace(self.auth, '[credential omitted]')[:500]
                        except (ValueError, TypeError, AttributeError):
                            detail = ''
                    raise CorpusError(f'{phase}: HTTP {code}. {detail} {reasons.get(code, "Check service availability and retry.")}') from None
                retry = exc.headers.get('Retry-After', '')
                try:
                    delay = float(retry)
                except ValueError:
                    try:
                        delay = max(0, email.utils.parsedate_to_datetime(retry).timestamp() - time.time())
                    except (ValueError, TypeError):
                        delay = 2 ** attempt + random.random()
            except (urllib.error.URLError, http.client.IncompleteRead, socket.timeout, TimeoutError, ConnectionError, OSError) as exc:
                if isinstance(exc, OSError) and exc.errno in (13, 28):
                    raise CorpusError('Disk full or permission denied. Free space or fix ownership, then resume; completed files are retained.') from None
                delay = 2 ** attempt + random.random()
            finally:
                if temp:
                    temp.unlink(missing_ok=True)
            if attempt == 5:
                raise CorpusError('Network/service retries exhausted. Check network and site health, then resume; completed files are retained.')
            with self.mutex:
                self.stats['retries'] += 1
                self.blocked_until = max(self.blocked_until, time.monotonic() + delay)
            log(f'{self.source}: transient response; retry {attempt + 1}/5 after {delay:.1f}s (shared rate limit).')

    def auth_check(self):
        identity = self.request('/rest/api/3/myself' if self.source == 'jira' else '/rest/api/user/current')
        if not identity.get('accountId') or identity.get('type') == 'anonymous':
            raise CorpusError(f'{self.source}: anonymous response despite HTTP 200. Refresh the local credential file and run auth; empty search results are not accepted.')
        self.timezone = identity.get('timeZone', 'UTC')
        log(f'{self.source}: authenticated identity verified.')


def estimate(items, binary_bytes, history=None, workers=4):
    basis = 'historical fallback: 909 MB in 221 s; 1.25 s/body serial, with concurrency'
    rate = 909_000_000 / 221
    item_seconds = 1.25 / workers
    if history and history.get('download_seconds', 0) > 0 and history.get('fetched', 0) > 0:
        basis = 'last completed run at this destination (includes request overhead)'
        elapsed = history['download_seconds']
        if history.get('downloaded_bytes', 0) > 1_000_000:
            rate = history['downloaded_bytes'] / elapsed
        item_seconds = elapsed / history['fetched']
        central = max(binary_bytes / rate, items * item_seconds)
    else:
        central = binary_bytes / rate + items * item_seconds
    return dict(items=items, binary_bytes=binary_bytes, seconds_low=round(central * .7, 1), seconds_high=round(central * 1.8 + 10, 1), basis=basis)


def show_estimate(value):
    log(f"Estimate: {value['items']} records, {value['binary_bytes'] / 1e9:.3f} GB binaries; {value['seconds_low'] / 60:.1f}-{value['seconds_high'] / 60:.1f} min. Basis: {value['basis']}. JSON and discovery overhead are additional.")


def check_disk(root, amount):
    free = shutil.disk_usage(root).free
    required = max(amount * 1.15, 100_000_000)
    if free < required:
        raise CorpusError(f'Insufficient disk space: {free / 1e9:.2f} GB free, {required / 1e9:.2f} GB required. Free space or move the corpus, then resume.')
