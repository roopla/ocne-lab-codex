"""Preserve two explicitly pinned public registry images without changing their manifests.
Writes only to the approved E: rebuild kit. Tokens stay in memory and are never logged.
Registry V2 format: https://distribution.github.io/distribution/spec/api/
"""
from pathlib import Path
import urllib.request as req, urllib.error, urllib.parse as url, json, hashlib, re, time
ROOT=Path(r'E:\OCNE19-Rebuild-Backup\kit-20261016\images\pinned-registry')
IMAGES=[('rac-slim','registry-1.docker.io','roopla/oracle-rac','d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d'),('database-operator','container-registry.oracle.com','database/operator','f378d66fd0b47b6089f01caf4ca86f90f3b3593cdca75292ff6491955c451cc0')]
ACCEPT=','.join(['application/vnd.docker.distribution.manifest.v2+json','application/vnd.oci.image.manifest.v1+json','application/vnd.docker.distribution.manifest.list.v2+json','application/vnd.oci.image.index.v1+json'])
class SafeRedirect(req.HTTPRedirectHandler):
 def redirect_request(self,r,fp,code,msg,headers,newurl):
  if url.urlsplit(newurl).scheme!='https':raise RuntimeError('Non-HTTPS redirect refused')
  result=super().redirect_request(r,fp,code,msg,headers,newurl)
  if url.urlsplit(newurl).netloc!=url.urlsplit(r.full_url).netloc:result.remove_header('Authorization')
  return result
opener=req.build_opener(SafeRedirect())
def digest_file(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(4*1024*1024),b''):h.update(b)
 return h.hexdigest()
for label,host,repo,digest in IMAGES:
 dest=ROOT/label;dest.mkdir(parents=True,exist_ok=True);token=None
 def fetch(path):
  global token
  headers={'Accept':ACCEPT,'User-Agent':'OCNE-Rebuild-Archive/1.0'}
  if token:headers['Authorization']='Bearer '+token
  request=req.Request('https://'+host+'/v2/'+repo+'/'+path,headers=headers)
  try:return opener.open(request,timeout=90)
  except urllib.error.HTTPError as e:
   if e.code!=401:raise RuntimeError('Registry HTTP '+str(e.code)) from None
   challenge=e.headers.get('WWW-Authenticate','')
   if not challenge.lower().startswith('bearer '):raise RuntimeError('Registry requires credentials; no automatic login attempted')
   args=dict(re.findall(r'(\w+)="([^"]*)"',challenge))
   realm=args.pop('realm');assert url.urlsplit(realm).scheme=='https'
   token_result=json.load(opener.open(realm+'?'+url.urlencode(args),timeout=90))
   token=token_result.get('token') or token_result.get('access_token');assert token
   headers['Authorization']='Bearer '+token
   return opener.open(req.Request(request.full_url,headers=headers),timeout=90)
 with fetch('manifests/sha256:'+digest) as r: raw=r.read()
 assert hashlib.sha256(raw).hexdigest()==digest,label
 manifest=json.loads(raw)
 if 'manifests' in manifest:raise RuntimeError('Multi-platform index needs explicit complete export; refusing partial archive')
 (dest/'manifest.json').write_bytes(raw)
 for item in [manifest['config'],*manifest['layers']]:
  algo,blob=item['digest'].split(':');assert algo=='sha256' and re.fullmatch('[0-9a-f]{64}',blob)
  target=dest/blob
  if target.exists() and target.stat().st_size==item['size'] and digest_file(target)==blob:continue
  tmp=dest/(blob+'.partial')
  for attempt in range(3):
   try:
    with fetch('blobs/sha256:'+blob) as response,tmp.open('wb') as out:
     while True:
      data=response.read(4*1024*1024)
      if not data:break
      out.write(data)
    assert tmp.stat().st_size==item['size'] and digest_file(tmp)==blob
    tmp.replace(target);break
   except Exception:
    if attempt==2:raise
    time.sleep(2)
  print(label,'verified blob',blob[:12],item['size'],flush=True)
 (dest/'version').write_text('Directory Transport Version: 1.1\n')
 (dest/'source.json').write_text(json.dumps({'registry':host,'repository':repo,'digest':'sha256:'+digest,'config':manifest['config']['digest'],'format':'docker-dir','verified':True},indent=2))
 print('PINNED IMAGE COMPLETE',label,'sha256:'+digest,flush=True)
