@{
    # Non-secret configuration. Sizes are MiB as accepted by VBoxManage.
    NetworkName = 'ocne19-net'
    NetworkCIDR = '192.168.77.0/24'
    Gateway = '192.168.77.1'
    InstallUser = 'labadmin'
    EnvironmentName = 'homelab'
    ClusterName = 'cluster1'
    # Additional disk, attached after OS installation by script 05.
    NFS = @{
        Server = 'ocne-op'
        DiskMB = 102400
        DiskFile = 'ocne-op-nfs.vdi'
        Controller = 'SATA'
        Port = 2
        ExportPath = '/srv/nfs/share'
        ClientMount = '/mnt/ocne-share'
    }
    # OP/CP RAM is below Oracle's published minimum: user-requested lab exception.
    VMs = @(
        @{ Name='ocne-op'; FQDN='ocne-op.lab.test'; IP='192.168.77.10'; SSHPort=2220; CPU=2; RAM=4096; DiskMB=102400 },
        @{ Name='ocne-cp'; FQDN='ocne-cp.lab.test'; IP='192.168.77.11'; SSHPort=2221; CPU=4; RAM=8192; DiskMB=102400 },
        @{ Name='ocne-w1'; FQDN='ocne-w1.lab.test'; IP='192.168.77.12'; SSHPort=2222; CPU=6; RAM=22528; DiskMB=204800 },
        @{ Name='ocne-w2'; FQDN='ocne-w2.lab.test'; IP='192.168.77.13'; SSHPort=2223; CPU=6; RAM=22528; DiskMB=204800 }
    )
}
