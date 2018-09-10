#!/bin/bash
find . -type "f" -iname "*.bin" -exec bash -c 'cd `dirname "{}"`; frombin `basename "{}"`' \;
find . -type "f" -iname "*.data" -exec bash -c 'cd `dirname "{}"`; hexdump -Cv `basename "{}"` > `basename "{}"`.hex' \;
find . -type "f" -iname "*.rsrc" -exec bash -c 'cd `dirname "{}"`; hexdump -Cv `basename "{}"` > `basename "{}"`.hex' \;

export base=`pwd`
gcc rforkdump.c -o rforkdump -O0 -g
find . -type "f" -iname "*.rsrc" -exec bash -c 'cd `dirname "{}"`; ${base}/rforkdump `basename "{}"` > `basename "{}"`.hrfork' \;

pushd images/ro/name
diff -Naur A.img.rsrc.hrfork B.img.rsrc.hrfork
diff -Naur B.img.rsrc.hrfork Bo.img.rsrc.hrfork
diff -Naur Bo.img.rsrc.hrfork 123456789012345678901234567.img.rsrc.hrfork
popd

pushd images/rw/name
diff -Naur A.img.rsrc.hrfork B.img.rsrc.hrfork
diff -Naur B.img.rsrc.hrfork Bo.img.rsrc.hrfork
diff -Naur Bo.img.rsrc.hrfork 123454678901234567890123456.img.rsrc.hrfork
popd
