#!/usr/bin/python3
"""gen_patch_metadata.py is a helper script for toolkit maintainers to add metadata for upstream patches.
"""
import argparse
import base64
import getpass
import hashlib
import logging
import os
import re
import shutil
import typing
import urllib
import zipfile

import bs4
import requests

USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36'
SEARCH_FORM = 'https://updates.oracle.com/Orion/SimpleSearch/process_form?search_type=patch&patch_number=%d&plat_lang=226P'
DOWNLOAD_URL = r'https://updates.oracle.com/Orion/Download/process_form[^\"]*'


def get_patch_url(s: requests.models.Request, patchnum: int) -> typing.List[str]:
  """Retrieves a download URL for a given patch number."""
  r = s.get(SEARCH_FORM % patchnum, allow_redirects=False)
  if 'location' in r.headers:
   # Do two separate requests to force auth on second request
    r = s.get(r.headers['Location'])

  assert r.status_code == 200, f'Got HTTP code {r.status_code} retrieving {SEARCH_FORM}'

  url = re.findall(DOWNLOAD_URL, str(r.content))
  assert url, f'Could not get a download URL from the patch form {SEARCH_FORM}; is the patch number correct?'
  return url


def download_patch(s: requests.models.Request, url: str, patch_file: str) -> None:
  """Downloads a given URL to a local file."""
  logging.info('Downloading %s', url)
  with s.get(url, stream=True) as r:
    with open(patch_file, 'wb') as f:
      shutil.copyfileobj(r.raw, f)


def parse_patch(patch_file: str, patchnum: int) -> (str, str, str, str):
  """Parses out the release, base release, and GI/OJVM subdirectories from a patch zip file."""
  with zipfile.ZipFile(patch_file, 'r') as z:
    with z.open('PatchSearch.xml') as f:
      c = bs4.BeautifulSoup(f.read(), 'xml')
      abstract = c.find('abstract').get_text()
      logging.info('Abstract: %s', abstract)
      patch_release = re.findall(r' (\d+\.\d+\.\d+\.\d+\.\d+) ', abstract)[0]
      release = c.find('release')['name']
    for fname in z.namelist():
      m = re.search(fr'^{patchnum}/(\d+)/README.html', fname)
      if m:
        logging.debug('Found readme file: %s', fname)
        with z.open(fname) as f:
          c = bs4.BeautifulSoup(f.read(), 'lxml')
          logging.debug('Found title: %s', c.find('title').get_text())
          if 'JavaVM' in c.find('title').get_text():
            ojvm_subdir = m.group(1)
          elif 'GI ' in c.find('title').get_text() or 'Grid Infrastructure' in c.find('title').get_text():
            gi_subdir = m.group(1)
  return(patch_release, release, ojvm_subdir, gi_subdir)


def main():
  ap = argparse.ArgumentParser()
  ap.add_argument('--patch', type=int, help='GI Combo OJVM patch number', required=True)
  ap.add_argument('--mosuser', type=str, help='MOS username', required=True)
  ap.add_argument('--debug', help='Debug logging', action=argparse.BooleanOptionalAction)
  args = ap.parse_args()
  logging.basicConfig(level=logging.DEBUG if args.debug else logging.INFO)

  patchnum = args.patch
  mosuser = args.mosuser
  mospwd = getpass.getpass(prompt='MOS Password: ')

  s = requests.Session()
  s.headers.update({'User-Agent': USER_AGENT})
  s.auth = (mosuser, mospwd)

  url = get_patch_url(s, patchnum)
  # Yes we ignore multipart patche:ws here.
  logging.debug('Found download URL: %s', url[0])
  patch_file = urllib.parse.parse_qs(urllib.parse.urlparse(url[0]).query)['patch_file'][0]
  logging.debug('url=%s patch_file=%s', url[0], patch_file)
  if os.path.exists(patch_file) and os.path.getsize(patch_file) > 2*1024*1024*1024:
    logging.info('Using local copy of patch file %s', patch_file)
  else:
    download_patch(s, url[0], patch_file)

  size = os.path.getsize(patch_file)
  assert size > 2*1024*1024*1024, f'Output file {patch_file} is only {size} bytes in size;  looks too small'

  md5 = hashlib.md5()
  with open(patch_file, 'rb') as f:
    while chunk := f.read(1024*1024):
      md5.update(chunk)

  md5_digest = base64.b64encode(md5.digest()).decode('ascii')
  logging.debug('Calculated MD5 digest %s', md5_digest)

  (release, patch_release, ojvm_subdir, gi_subdir) = parse_patch(patch_file, patchnum)

  base_release = '19.3.0.0.0' if release == '19.0.0.0.0' else release
  logging.info('Found release = %s base = %s GI subdir = %s OJVM subdir = %s', patch_release, base_release, gi_subdir, ojvm_subdir)

  logging.info('Downloading OPatch')
  op_url = get_patch_url(s, 6880880)

  release = patch_file.split('_')[1]
  if release == '121020':
    release = '121010'
  matches = [k for k in op_url if release in k]
  assert len(matches) == 1, f'Could not find OPatch for release {release}; only got {op_url}'

  op_patch_file = urllib.parse.parse_qs(urllib.parse.urlparse(matches[0]).query)['patch_file'][0]
  download_patch(s, matches[0], op_patch_file)

  size = os.path.getsize(patch_file)
  assert size > 100*1024*1024, f'OPatch output file {patch_file} is only {size} bytes in size;  looks too small'

  if not (base_release.startswith('19') or base_release.startswith('18') or base_release.startswith('12.2')):
    logging.warning('Base release %s has not been tested; the results may be incorrect.', base_release)

  print(f'Please copy the following files to your GCS bucket: {patch_file} {op_patch_file}')
  print(f'''Add the following to the appropriate sections of roles/common/defaults/main.yml:

  gi_patches:
    - {{ category: "RU", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "/{gi_subdir}", prereq_check: FALSE, method: "opatchauto apply", ocm: FALSE, upgrade: FALSE, md5sum: "{md5_digest}" }}

  rdbms_patches:
    - {{ category: "RU_Combo", base: "{base_release}", release:
        "{patch_release}", patchnum: "{patchnum}, patchfile: "{patch_file}", patch_subdir: "/{ojvm_subdir}", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "{md5_digest}" }}
  ''')

if __name__ == '__main__':
  main()
