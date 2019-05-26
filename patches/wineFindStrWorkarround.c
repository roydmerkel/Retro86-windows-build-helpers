#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
	int ret = 1;
	int size = 0;
	int oldsize = 0;
	const char *search;
	char *searchIn = NULL;
	char readBuf[1024];
	int numRead = 0;

	if(argc == 2)
	{
		search = argv[1];

		while((numRead = fread(readBuf, sizeof(char), sizeof readBuf / sizeof (char), stdin)))
		{
			if(searchIn == NULL)
			{
				size = (numRead + 1);
				searchIn = (char *)malloc(sizeof(char) * size);
				memcpy(searchIn, readBuf, sizeof(char) * (numRead));
				searchIn[numRead] = '\0';
			}
			else
			{
				oldsize = size;
				size += numRead;
				searchIn = (char *)realloc(searchIn, sizeof(char) * size);
				memcpy(&searchIn[oldsize - 1], readBuf, sizeof(char) * (numRead));
				searchIn[size] = '\0';
			}
		}

		ret = (strstr(searchIn, search) == NULL);
	}

	exit(ret);
}
