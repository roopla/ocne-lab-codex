"""Read-only ZIP integrity and SHA256 inventory for local Oracle RAC installation media.
Does not extract or execute archive contents. Writes only the specified local report.
"""
from pathlib import Path
from zipfile import ZipFile
import hashlib,json,argparse,datetime
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report",type=Path,default=ROOT/"logs/rac-media-inventory.json")
    args=parser.parse_args()
    report=args.report.resolve()
    if not report.is_relative_to((ROOT/"logs").resolve()):
        raise SystemExit("Report must remain under project logs/.")
    archives=sorted((ROOT/"ISO").glob("*.zip"))
    if not archives: raise SystemExit("No ZIP archives found under ISO/.")
    results=[]
    for path in archives:
        before=path.stat()
        print("Checking "+path.name,flush=True)
        digest=hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(8*1024*1024),b""):
                digest.update(block)
        with ZipFile(path) as archive:
            entries=archive.infolist()
            damaged=archive.testzip()
            if damaged: raise SystemExit("CRC failure in "+path.name+": "+damaged)
        after=path.stat()
        if (before.st_size,before.st_mtime_ns)!=(after.st_size,after.st_mtime_ns):
            raise SystemExit("Archive changed during inspection: "+path.name)
        row={"file":path.name,"bytes":after.st_size,"sha256":digest.hexdigest(),
             "entries":len(entries),"uncompressed_bytes":sum(i.file_size for i in entries),
             "zip_crc":"passed"}
        results.append(row)
        print(json.dumps(row),flush=True)
    output={"checked_at":datetime.datetime.now().astimezone().isoformat(),
            "scope":"Local SHA256 fingerprints and ZIP CRC checks; vendor checksum comparison not performed.",
            "archives":results}
    report.write_text(json.dumps(output,indent=2)+"\n",encoding="utf-8")
    print("Verified "+str(len(results))+" archives; report "+str(report),flush=True)
if __name__=="__main__":main()
