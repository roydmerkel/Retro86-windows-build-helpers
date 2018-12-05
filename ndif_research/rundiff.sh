#!/bin/bash
find . -type "f" -iname "*.bin" -exec bash -c 'cd "`dirname "{}"`"; frombin `basename "{}"`' \;
find . -type "f" -iname "*.bin.1.data" -exec bash -c 'cd "`dirname "{}"`"; ofname=`basename "{}"`; fname=$(echo `basename "{}"` | sed -e "s/\.1\.data/.data/"); mv $ofname $fname' \;
find . -type "f" -iname "*.bin.1.info" -exec bash -c 'cd "`dirname "{}"`"; ofname=`basename "{}"`; fname=$(echo `basename "{}"` | sed -e "s/\.1\.info/.info/"); mv $ofname $fname' \;
find . -type "f" -iname "*.data" -exec bash -c 'cd "`dirname "{}"`"; hexdump -Cv `basename "{}"` > `basename "{}"`.hex' \;
find . -type "f" -iname "*.rsrc" -exec bash -c 'cd "`dirname "{}"`"; hexdump -Cv `basename "{}"` > `basename "{}"`.hex' \;

export base=`pwd`
gcc rforkdump.c -o rforkdump -O0 -g
find . -type "f" -iname "*.rsrc" -exec bash -c 'cd "`dirname "{}"`"; ${base}/rforkdump `basename "{}"` > `basename "{}"`.hrfork' \;

pushd images/ro/name
echo diff -Naur A.img.rsrc.hrfork B.img.rsrc.hrfork
diff -Naur A.img.rsrc.hrfork B.img.rsrc.hrfork
echo diff -Naur B.img.rsrc.hrfork Bo.img.rsrc.hrfork
diff -Naur B.img.rsrc.hrfork Bo.img.rsrc.hrfork
echo diff -Naur Bo.img.rsrc.hrfork 123456789012345678901234567.img.rsrc.hrfork
diff -Naur Bo.img.rsrc.hrfork 123456789012345678901234567.img.rsrc.hrfork
popd

pushd images/rw/name
echo diff -Naur A.img.rsrc.hrfork B.img.rsrc.hrfork
diff -Naur A.img.rsrc.hrfork B.img.rsrc.hrfork
echo diff -Naur B.img.rsrc.hrfork Bo.img.rsrc.hrfork
diff -Naur B.img.rsrc.hrfork Bo.img.rsrc.hrfork
echo diff -Naur Bo.img.rsrc.hrfork 123454678901234567890123456.img.rsrc.hrfork
diff -Naur Bo.img.rsrc.hrfork 123454678901234567890123456.img.rsrc.hrfork
popd

pushd images/rocomp/name
echo diff -Naur A.img.rsrc.hrfork B.img.rsrc.hrfork
diff -Naur A.img.rsrc.hrfork B.img.rsrc.hrfork
echo diff -Naur B.img.rsrc.hrfork Bo.img.rsrc.hrfork
diff -Naur B.img.rsrc.hrfork Bo.img.rsrc.hrfork
echo diff -Naur Bo.img.rsrc.hrfork 123456789012345678901234567.img.rsrc.hrfork
diff -Naur Bo.img.rsrc.hrfork 123456789012345678901234567.img.rsrc.hrfork
popd

pushd images/rw/time\ created
echo diff -Naur A1.img.rsrc.hrfork A2.img.rsrc.hrfork
diff -Naur A1.img.rsrc.hrfork A2.img.rsrc.hrfork
popd

pushd images/ro/time\ created
echo diff -Naur A1.img.rsrc.hrfork A2.img.rsrc.hrfork
diff -Naur A1.img.rsrc.hrfork A2.img.rsrc.hrfork
popd

pushd images/rocomp/time\ created
echo diff -Naur A1.img.rsrc.hrfork A2.img.rsrc.hrfork
diff -Naur A1.img.rsrc.hrfork A2.img.rsrc.hrfork
popd

pushd images/rw/time\ modified
echo diff -Naur A1.img.rsrc.hrfork A2.img.rsrc.hrfork
diff -Naur A1.img.rsrc.hrfork A2.img.rsrc.hrfork
popd

