#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const char * strendswith(const char * str1, const char * str2)
{
	size_t str1len = 0;
	size_t str2len = 0;
	const char * str1cmp;

	if(str1 == NULL || str2 == NULL)
	{
		return NULL;
	}
	str1len = strlen(str1);
	str2len = strlen(str2);

	if(str1len < str2len)
	{
		return NULL;
	}

	str1cmp = &str1[str1len - str2len];

	if(strcmp(str1cmp, str2) == 0)
	{
		return str1cmp;
	}
	else
	{
		return NULL;
	}
}

const char * strstartswith(const char * str1, const char * str2)
{
	size_t str1len = 0;
	size_t str2len = 0;
	const char * str1cmp;

	if(str1 == NULL || str2 == NULL)
	{
		return NULL;
	}
	str1len = strlen(str1);
	str2len = strlen(str2);

	if(str1len < str2len)
	{
		return NULL;
	}

	if(strncmp(str1, str2, str2len) == 0)
	{
		return str1;
	}
	else
	{
		return NULL;
	}
}

int main(int argc, char **argv)
{
	int ret = 0;
	int size = 0;
	int oldsize = 0;
	const char *search[1024];
	int numSearches = 0;
	char *searchIn = NULL;
	char readBuf[1024];
	int numRead = 0;
	int readingOptions = 1;
	int idx;
	int isOption;
	int matchBeginning = 0;
	int matchEnd = 0;
	int matchLiteral = 0;
	int matchRegex = 0;
	int matchCaseInsensitive = 0;
	int matchExactly = 0;
	int findNonMatching = 0;
	int skipLinesWithNonprintable = 0;
	int hasSpecifiedLiteralSearch = 0;
	int error = 0;

	if(argc >= 2)
	{
		for(idx = 1; idx < argc; idx++)
		{
			isOption = 0;
			if(readingOptions)
			{
				if(strncmp(argv[idx], "/b", 3) == 0 || strncmp(argv[idx], "/B", 3) == 0)
				{
					isOption = 1;
					matchBeginning = 1;
				}
				else if(strncmp(argv[idx], "/e", 3) == 0 || strncmp(argv[idx], "/E", 3) == 0)
				{
					isOption = 1;
					matchEnd = 1;
				}
				else if(strncmp(argv[idx], "/l", 3) == 0 || strncmp(argv[idx], "/L", 3) == 0)
				{
					isOption = 1;
					matchLiteral = 1;
				}
				else if(strncmp(argv[idx], "/r", 3) == 0 || strncmp(argv[idx], "/R", 3) == 0)
				{
					isOption = 1;
					matchRegex = 1;
				}
				else if(strncmp(argv[idx], "/i", 3) == 0 || strncmp(argv[idx], "/I", 3) == 0)
				{
					isOption = 1;
					matchCaseInsensitive = 1;
				}
				else if(strncmp(argv[idx], "/x", 3) == 0 || strncmp(argv[idx], "/X", 3) == 0)
				{
					isOption = 1;
					matchExactly = 1;
				}
				else if(strncmp(argv[idx], "/v", 3) == 0 || strncmp(argv[idx], "/V", 3) == 0)
				{
					isOption = 1;
					findNonMatching = 1;
				}
				else if(strncmp(argv[idx], "/p", 3) == 0 || strncmp(argv[idx], "/P", 3) == 0)
				{
					isOption = 1;
					skipLinesWithNonprintable = 1;
				}
				else if(strncmp(argv[idx], "/c:", 3) == 0 || strncmp(argv[idx], "/C:", 3) == 0)
				{
					isOption = 1;
					hasSpecifiedLiteralSearch = 1;
					numSearches++;
					if(argv[idx][3] == '"')
					{
						if(argv[idx][strlen(argv[idx]) - 1] == '"')
						{
							search[numSearches - 1] = &argv[idx][4];
							argv[idx][strlen(argv[idx]) - 1] = '\0';
						}
						else
						{
							error = 1;
							break;
						}
					}
					else
					{
						search[numSearches - 1] = &argv[idx][3];
					}
				}
				else
				{
					isOption = 0;
					readingOptions = 0;
				}
			}

			if(!isOption)
			{
				if(hasSpecifiedLiteralSearch)
				{
					error = 1;
					break;
				}
				else
				{
					numSearches++;
					search[numSearches - 1] = argv[idx];
				}
			}
		}

		if(!matchLiteral && !matchRegex)
		{
			matchLiteral = 1;
		}
		else if(matchLiteral && matchRegex)
		{
			error = 1;
		}

		if((matchBeginning || matchEnd) && matchExactly)
		{
			error = 1;
		}

		// TODO: matchLiteral vs matchRegex
		// TODO: matchCaseInsensitive
		// TODO: skipLinesWithNonprintable

		if(!error)
		{
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

			if(matchBeginning && matchEnd)
			{
				for(idx = 0; idx < numSearches; idx++)
				{
					ret = (strstartswith(searchIn, search[idx]) != NULL && strendswith(searchIn, search[idx]) != NULL);
					if(ret)
					{
						break;
					}
				}
			}
			else if(matchBeginning)
			{
				for(idx = 0; idx < numSearches; idx++)
				{
					ret = (strstartswith(searchIn, search[idx]) != NULL);
					if(ret)
					{
						break;
					}
				}
			}
			else if(matchEnd)
			{
				for(idx = 0; idx < numSearches; idx++)
				{
					ret = (strendswith(searchIn, search[idx]) != NULL);
					if(ret)
					{
						break;
					}
				}
			}
			else if(matchExactly)
			{
				for(idx = 0; idx < numSearches; idx++)
				{
					ret = (strcmp(searchIn, search[idx]) != 0);
					if(ret)
					{
						break;
					}
				}
			}
			else
			{
				for(idx = 0; idx < numSearches; idx++)
				{
					ret = (strstr(searchIn, search[idx]) != 0);
					if(ret)
					{
						break;
					}
				}
			}
			if(findNonMatching)
			{
				ret = !ret;
			}
		}
	}

	exit(!ret);
}
