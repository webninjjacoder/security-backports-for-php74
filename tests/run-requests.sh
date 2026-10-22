#!/bin/bash
# Fires a fixed set of requests at http://127.0.0.1/t/ and prints normalized results,
# so the output of the stock and patched builds can be diffed line by line.
B=http://127.0.0.1/t
c() { curl -s -m 30 -w ' [HTTP %{http_code}]\n' "$@"; }
python3 -c 'import sys; sys.stdout.buffer.write(bytes((i*7+3)%256 for i in range(300000)))' > /tmp/f1.bin
python3 -c 'import sys; sys.stdout.buffer.write(bytes((i*13+1)%256 for i in range(2000)))' > /tmp/f2.bin

echo "## ini";        c "$B/upload_progress.php"
echo "## ext";        c "$B/ext.php"
echo "## get-nested"; c "$B/dump.php?a=1&b[]=2&b[]=3&c[x][y]=4&d[]=&e[0][1][2]=deep"
echo "## cookie";     c -H 'Cookie: s=1; arr[k]=v; arr[k2]=v2' "$B/dump.php"
echo "## urlenc";     c --data 'x=1&y[]=a&y[]=b&z[q]=r&empty=' "$B/dump.php"
echo "## json-body";  c -H 'Content-Type: application/json' --data '{"a":1}' "$B/dump.php"
echo "## multipart";  c -H 'Expect:' -F 'name=Serial Cables' -F 'opt[]=1' -F 'opt[]=2' -F 'meta[k]=v' \
                         -F 'file1=@/tmp/f1.bin;filename=a.bin' -F 'many[]=@/tmp/f2.bin;filename=b.bin' -F 'many[]=@/tmp/f2.bin;filename=c.bin' "$B/dump.php"
echo "## multipart-dup-headers"
printf -- '--XB\r\nContent-Disposition: form-data; name="a"\r\nContent-Disposition: form-data; name="b"\r\nX-Junk: 1\r\n\r\nval\r\n--XB--\r\n' > /tmp/mp.txt
c -H 'Content-Type: multipart/form-data; boundary=XB' --data-binary @/tmp/mp.txt "$B/dump.php"
echo "## multipart-many-parts (3000 fields)"
python3 - > /tmp/many.txt <<'PY'
import sys
out=[]
for i in range(3000):
    out.append('--XB\r\nContent-Disposition: form-data; name="f%d"\r\n\r\n%d\r\n' % (i, i))
out.append('--XB--\r\n')
sys.stdout.write(''.join(out))
PY
curl -s -m 30 -H 'Content-Type: multipart/form-data; boundary=XB' --data-binary @/tmp/many.txt "$B/dump.php" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print("post_count", len(d["post"]))'
echo "## basic-auth";  c -u 'alice:secret' "$B/dump.php"
echo "## no-auth-after-auth"; c "$B/dump.php" | python3 -c 'import sys,json; l=sys.stdin.read(); print(json.loads(l.rsplit(" [HTTP",1)[0])["auth"], l.rsplit(" ",2)[-2:])'
echo "## session"
rm -f /tmp/cj; for i in 1 2 3; do c -b /tmp/cj -c /tmp/cj "$B/session.php"; done
echo "## oom (memory_limit exceeded)"
curl -s -m 30 -o /tmp/oom.out -w 'http=%{http_code} bytes=%{size_download}\n' "$B/oom.php"; echo "curl_exit=$?"
grep -o 'Allowed memory size[^<]*' /tmp/oom.out | head -1
echo "## after-oom: 20 normal requests"
ok=0; for i in $(seq 1 20); do [ "$(curl -s -o /dev/null -w '%{http_code}' "$B/dump.php?i=$i")" = 200 ] && ok=$((ok+1)); done; echo "ok=$ok/20"
echo "## after-oom: auth/cookie state not leaking"
c "$B/dump.php"
