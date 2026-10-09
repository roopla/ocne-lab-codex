set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u labadmin) == 1001 ]]
install -d -m 0700 -o labadmin -g labadmin /home/labadmin/.ssh
key='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDFsXuFsGYeNdkOHr2LXltHrhv4eSs/a95fMKKGLTNZlBLrjQ9BIBdDyDIUfkxcsE8GU1sywMfSRPKn8vlE753RlRrJMvutxNkQyfi5KtW9Bz+5E7Y3hb+JB2LBh+yzxLBUrssuVDDYR00eRoGwGh+KKfc31Ri3O+sdvo4XYSF2+wWpsXdvdLfwMmZuxe3/MQZmUde2FDIG1vqVeE0KtazEt0PTY/tlm2V+a2Jx6XRkkYzCzV5qSjC8RdfCgXv/WodslUjzUXO6LLepzT2rU5OAE9PiCFtw9HSykPz9ei51p9gAJNuf9coKX2jpILOHzZ6Qs1ojcRth4Pd2oX+BwmUdJBKwV+ddAaOjBietC7N4kxtOmXJhYwUzSYK3YCCj+6tvg285987kiYUCD5R7h0EvNL7WNIXHxJEm7g5mxWUOIPk5sjqZ9y5biuTMw6QXvIiNqCRGNcGUVSaHQtwVKOVlp3GcS3bJFLrdIXENwLeu8cNpgr70EdYsOy8PMkDfp2c= labadmin@ocne-op.lab.test'
auth=/home/labadmin/.ssh/authorized_keys
touch "$auth"
grep -qxF "$key" "$auth" || printf '%s\n' "$key" >> "$auth"
chown labadmin:labadmin "$auth"
chmod 0600 "$auth"
restorecon -RF /home/labadmin/.ssh
ssh-keygen -lf "$auth"