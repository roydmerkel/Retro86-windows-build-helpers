#!/bin/bash
find . -type "f" -iname "*.bin" -exec bash -c 'cd `dirname "{}"`; frombin `basename "{}"`' \;
find . -type "f" -iname "*.data" -exec bash -c 'cd `dirname "{}"`; hexdump -Cv `basename "{}"` > `basename "{}"`.hex' \;
find . -type "f" -iname "*.rsrc" -exec bash -c 'cd `dirname "{}"`; hexdump -Cv `basename "{}"` > `basename "{}"`.hex' \;

export base=`pwd`
gcc rforkdump.c -o rforkdump -O0 -g
find . -type "f" -iname "*.rsrc" -exec bash -c 'cd `dirname "{}"`; ${base}/rforkdump `basename "{}"` > `basename "{}"`.hrfork' \;

