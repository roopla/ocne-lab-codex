from pathlib import Path, PurePosixPath
from zipfile import ZipFile
for path in (Path('ISO/oracle-gridhome-19.32.zip'),Path('ISO/oracle-dbhome-19.32.zip')):
    with ZipFile(path) as archive:
        for item in archive.infolist():
            name=item.filename.replace('\\','/')
            member=PurePosixPath(name)
            assert not member.is_absolute() and '..' not in member.parts and ':' not in name, name
        assert archive.testzip() is None, 'CRC failure'
        required = 'gridSetup.sh' if 'gridhome' in path.name else 'runInstaller'
        assert required in archive.namelist(), 'Missing home-root installer: '+required
        print(path.name, len(archive.infolist()), 'members, CRC/path checks passed')
