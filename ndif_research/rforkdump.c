#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <arpa/inet.h>
#include <ctype.h>

typedef struct ResHeader
{
	uint32_t resourceData;
	uint32_t resourceMap;
	uint32_t resourceDataLength;
	uint32_t resourceMapLength;
} ResHeader;

typedef struct ResData
{
	uint32_t offset;
	uint32_t resourceDataLength;
	char *resourceData;
} ResData;

typedef struct ResName
{
	uint32_t offset;
	uint8_t length;
	char *name;
} ResName;

typedef struct ResReference
{
	uint32_t referenceLoc;
	int16_t resourceId;
	uint16_t resourceNameOff;
	uint32_t resourceNameLoc;
	ResName *resourceName;
	uint8_t resourceAttributes;
	uint32_t resourceDataOffset;
	uint32_t resourceDataLoc;
	ResData *resourceData;
	uint32_t resourceHandle;
} ResReference;

typedef struct ResType
{
	char resourceType[5];
	uint16_t numResources;
	uint16_t referenceListOffset;
	uint32_t referenceListLoc;
	ResReference * reference;
} ResType;

typedef struct ResMap
{
	ResHeader * resHeader;
	uint32_t nextResMap;
	uint16_t fileReferenceNumber;
	uint16_t fileAttributes;
	uint16_t typeListOffset;
	uint16_t nameListOffset;
	uint16_t numTypes;
	ResType *resourceTypes;
	uint16_t numReferences;
	ResReference *references;
	uint16_t numNames;
	ResName *names;
} ResMap;

typedef struct ResFile
{
	size_t fileDataSize;
	char *fileData;
	ResHeader header;
	int numDatas;
	ResData *resourceDatas;
	int numMaps;
	ResMap *resourceMaps;
} ResFile;

#define READ_STRING_N(DEST, N) \
if(idx + N < out->fileDataSize) { \
	char buf[N + 1]; \
	int bufIdx = 0; \
	while(bufIdx < N) \
	{ \
		DEST[bufIdx++] = out->fileData[idx++]; \
	} \
	DEST[bufIdx++] = '\0'; \
} else { \
	fprintf(stderr, "Failed to read " #DEST " EOF detected.\n"); \
	exit(1); \
}

#define READ_CHAR(DEST) \
if(idx + 1 < out->fileDataSize) { \
	DEST = *(char *)(&out->fileData[idx++]); \
} else { \
	fprintf(stderr, "Failed to read " #DEST " EOF detected.\n"); \
	exit(1); \
}

#define READ_INT_8(DEST) \
if(idx + 1 < out->fileDataSize) { \
	DEST = *(uint8_t *)(&out->fileData[idx++]); \
} else { \
	fprintf(stderr, "Failed to read " #DEST " EOF detected.\n"); \
	exit(1); \
}

#define READ_INT_16(DEST) \
if(idx + 2 < out->fileDataSize) { \
	char buf[2]; \
	int bufIdx = 0; \
	buf[bufIdx++] = out->fileData[idx++]; \
	buf[bufIdx++] = out->fileData[idx++]; \
	DEST = *(uint16_t *)buf; \
	DEST = ntohs(DEST); \
} else { \
	fprintf(stderr, "Failed to read " #DEST " EOF detected.\n"); \
	exit(1); \
}

#define READ_SINT_16(DEST) \
if(idx + 2 < out->fileDataSize) { \
	char buf[2]; \
	int bufIdx = 0; \
	buf[bufIdx++] = out->fileData[idx++]; \
	buf[bufIdx++] = out->fileData[idx++]; \
	DEST = *(int16_t *)buf; \
	DEST = ntohs(DEST); \
} else { \
	fprintf(stderr, "Failed to read " #DEST " EOF detected.\n"); \
	exit(1); \
}

#define READ_INT_24(DEST) \
if(idx + 3 < out->fileDataSize) { \
	char buf[4]; \
	int bufIdx = 0; \
	buf[bufIdx++] = 0; \
	buf[bufIdx++] = out->fileData[idx++]; \
	buf[bufIdx++] = out->fileData[idx++]; \
	buf[bufIdx++] = out->fileData[idx++]; \
	DEST = *(uint32_t *)buf; \
	DEST = ntohl(DEST); \
} else { \
	fprintf(stderr, "Failed to read " #DEST " EOF detected.\n"); \
	exit(1); \
}

#define READ_INT_32(DEST) \
if(idx + 4 < out->fileDataSize) { \
	char buf[4]; \
	int bufIdx = 0; \
	buf[bufIdx++] = out->fileData[idx++]; \
	buf[bufIdx++] = out->fileData[idx++]; \
	buf[bufIdx++] = out->fileData[idx++]; \
	buf[bufIdx++] = out->fileData[idx++]; \
	DEST = *(uint32_t *)buf; \
	DEST = ntohl(DEST); \
} else { \
	fprintf(stderr, "Failed to read " #DEST " EOF detected.\n"); \
	exit(1); \
}

ResFile * parseResFile(FILE *fp)
{
	char buffer[1024] = {0};
	int idx = 0;
	ResFile *out = (ResFile *)malloc(sizeof (ResFile));

	if(out == NULL)
	{
		fprintf(stderr, "failed to allocate file data\n");
		exit(1);
	}

	out->fileDataSize = 1;
	out->fileData = (char *)malloc(out->fileDataSize);
	out->numDatas = 0;
	out->resourceDatas = (ResData *)malloc(0);

	memset(&out->header, '\0', sizeof out->header);

	if(out->fileData == NULL)
	{
		fprintf(stderr, "failed to allocate file data\n");
		exit(1);
	}

	out->fileData[0] = '\0';

	while(!feof(fp) && !ferror(fp))
	{
		int read = fread(buffer, sizeof (char), sizeof buffer / sizeof (char), fp);

		if(read > 0)
		{
			int oldIdx = out->fileDataSize - 1;
			int idx = 0;
			out->fileDataSize += read;

			out->fileData = realloc(out->fileData, sizeof (char) * out->fileDataSize);

			for(; idx < read;)
			{
				out->fileData[oldIdx++] = buffer[idx++];
			}

			out->fileData[out->fileDataSize - 1] = '\0';
		}
	}

	READ_INT_32(out->header.resourceData);
	READ_INT_32(out->header.resourceMap);
	READ_INT_32(out->header.resourceDataLength);
	READ_INT_32(out->header.resourceMapLength);

	if(out->header.resourceData + out->header.resourceDataLength != out->header.resourceMap)
	{
		fprintf(stderr, "resource mismatch, resource map should begin directly after resource data.\n");
		exit(1);
	}

	if(out->header.resourceMap + out->header.resourceMapLength != out->fileDataSize - 1)
	{
		fprintf(stderr, "resource mismatch, resource map should be the final thing in the resource file.\n");
		exit(1);
	}

	idx = out->header.resourceData;

	while(idx < out->header.resourceData + out->header.resourceDataLength)
	{
		ResData currentRes;

		memset(&currentRes, '\0', sizeof currentRes);

		currentRes.offset = idx;

		if(idx + 4 > out->header.resourceData + out->header.resourceDataLength)
		{
			fprintf(stderr, "malformed resourceData segment... Length is less then the sum total of all resources (while reading length).\n");
			exit(1);
		}
		READ_INT_32(currentRes.resourceDataLength);

		if(idx + currentRes.resourceDataLength > out->header.resourceData + out->header.resourceDataLength)
		{
			fprintf(stderr, "malformed resourceData segment... Length is less then the sum total of all resources (while reading data).\n");
			exit(1);
		}

		currentRes.resourceData = &out->fileData[idx];

		idx += currentRes.resourceDataLength;

		out->numDatas++;
		out->resourceDatas = realloc(out->resourceDatas, sizeof (ResData) * out->numDatas);

		out->resourceDatas[out->numDatas - 1] = currentRes;
	}

	// Read resource maps.
	out->numMaps = 0;
	out->resourceMaps = (ResMap *)calloc(out->numMaps, sizeof (ResMap));
	while(idx < out->header.resourceMap + out->header.resourceMapLength)
	{
		// read the headers.
		int curTypeId = 0;
		int startIdx = idx;
		ResMap currentResMap;
		ResHeader testHeader;

		memset(&currentResMap, '\0', sizeof currentResMap);
		memset(&testHeader, '\0', sizeof testHeader);

		READ_INT_32(testHeader.resourceData);
		READ_INT_32(testHeader.resourceMap);
		READ_INT_32(testHeader.resourceDataLength);
		READ_INT_32(testHeader.resourceMapLength);

		// check the header against the header of the resource.
		if(testHeader.resourceData != out->header.resourceData)
		{
			fprintf(stderr, "resourceData field of resouce map header field doesn't map resource header.\n");
			exit(1);
		}
		else if(testHeader.resourceMap != out->header.resourceMap)
		{
			fprintf(stderr, "resourceMap field of resouce map header field doesn't map resource header.\n");
			exit(1);
		}
		else if(testHeader.resourceDataLength != out->header.resourceDataLength)
		{
			fprintf(stderr, "resourceDataLength field of resouce map header field doesn't map resource header.\n");
			exit(1);
		}
		else if(testHeader.resourceMapLength != out->header.resourceMapLength)
		{
			fprintf(stderr, "resourceMapLength field of resouce map header field doesn't map resource header.\n");
			exit(1);
		}
		else
		{
			currentResMap.resHeader = &(out->header);
		}

		// read the rest of the resource map header.
		READ_INT_32(currentResMap.nextResMap);
		READ_INT_16(currentResMap.fileReferenceNumber);
		READ_INT_16(currentResMap.fileAttributes);
		READ_INT_16(currentResMap.typeListOffset);
		READ_INT_16(currentResMap.nameListOffset);
		READ_INT_16(currentResMap.numTypes);

		currentResMap.numTypes++;

		// verify that the type list pointer matches the type list location.
		if(startIdx + currentResMap.typeListOffset + 2 != idx)
		{
			fprintf(stderr, "type list offset doesn't match location of type list in resource header.\n");
			exit(1);
		}

		// read the resource types.
		currentResMap.resourceTypes = (ResType *)calloc(currentResMap.numTypes, sizeof (ResType));
		for(curTypeId = 0; curTypeId < currentResMap.numTypes; curTypeId++)
		{
			ResType *curRes = &currentResMap.resourceTypes[curTypeId];
	
			memset(curRes, '\0', sizeof (ResType));	
			READ_STRING_N(curRes->resourceType, 4);
			READ_INT_16(curRes->numResources);
			READ_INT_16(curRes->referenceListOffset);

			curRes->numResources++;
			
			curRes->referenceListLoc = startIdx + currentResMap.typeListOffset + curRes->referenceListOffset;
		}

		// read the resource references.
		currentResMap.references = (ResReference *)calloc(0, sizeof (ResReference));
		while(idx < startIdx + currentResMap.nameListOffset)
		{
			ResReference curReference;

			memset(&curReference, '\0', sizeof curReference);
			
			curReference.referenceLoc = idx;
			READ_SINT_16(curReference.resourceId);
			READ_INT_16(curReference.resourceNameOff);

			if(curReference.resourceNameOff == 0xFFFF)
			{
				curReference.resourceNameLoc = 0xFFFFFFFF;
			}
			else
			{
				curReference.resourceNameLoc = startIdx + currentResMap.nameListOffset + curReference.resourceNameOff;
			}
			READ_INT_8(curReference.resourceAttributes);
			READ_INT_24(curReference.resourceDataOffset);
			READ_INT_32(curReference.resourceHandle);
			
			curReference.resourceDataLoc = out->header.resourceData + curReference.resourceDataOffset;

			currentResMap.numReferences++;
			currentResMap.references = realloc(currentResMap.references, sizeof (ResReference) * currentResMap.numReferences);

			currentResMap.references[currentResMap.numReferences - 1] = curReference;
		}

		// read the resource names.
		while(idx < out->fileDataSize - 1)
		{
			ResName curName;
			int charidx = 0;

			memset(&curName, '\0', sizeof (ResName));
			curName.offset = idx;
			READ_INT_8(curName.length);
			curName.name = (char *)calloc(curName.length + 1, sizeof (char));
			memset(curName.name, '\0', (curName.length + 1) * sizeof (char));
			for(charidx = 0; charidx < curName.length; charidx++)
			{
				READ_CHAR(curName.name[charidx]);
			}

			currentResMap.numNames++;

			currentResMap.names = realloc(currentResMap.names, sizeof (ResReference) * currentResMap.numNames);

			currentResMap.names[currentResMap.numNames - 1] = curName;
		}

		// match the resource type reference offsets to pointers and verify that all links are valid.	
		{
			int curTypeId;
			int curRefId;
			int found;

			for(curTypeId = 0; curTypeId < currentResMap.numTypes; curTypeId++)
			{
				ResReference * reference = NULL;
				ResType * curResType = &currentResMap.resourceTypes[curTypeId];

				found = 0;
				for(curRefId = 0; curRefId < currentResMap.numReferences; curRefId++)
				{
					ResReference *curReference = &currentResMap.references[curRefId];

					if(curReference->referenceLoc == curResType->referenceListLoc)
					{
						found = 1;
						reference = curReference;
						break;
					}
				}

				if(!found)
				{
					fprintf(stderr, "resource map id: %d reference type id: %d, doesn't reference any reference in the resource file.\n", out->numMaps, curTypeId);
					exit(1);
				}
				else
				{
					curResType->reference = reference;
				}
			}
		}

		// match the reference list name offsets to pointers and verify that all links are valid.	
		{
			int curRefId;
			int curNameId;
			int curDataId;
			int found;

			for(curRefId = 0; curRefId < currentResMap.numReferences; curRefId++)
			{
				ResName *name = NULL;
				ResData *data = NULL;
				ResReference *curReference = &currentResMap.references[curRefId];

				if(curReference->resourceNameLoc == 0xFFFFFFFF)
				{
					curReference->resourceName = NULL;
				}
				else
				{
					found = 0;
					for(curNameId = 0; curNameId < currentResMap.numNames; curNameId++)
					{
						ResName *curName = &currentResMap.names[curNameId];

						if(curName->offset == curReference->resourceNameLoc)
						{
							found = 1;
							name = curName;
							break;
						}
					}

					if(!found)
					{
						fprintf(stderr, "resource map id: %d reference id: %d, doesn't reference any reference in the resource file.\n", out->numMaps, curRefId);
						exit(1);
					}
					else
					{
						curReference->resourceName = name;
					}
				}

				found = 0;
				for(curDataId = 0; curDataId < out->numDatas; curDataId++)
				{
					ResData *curData = &out->resourceDatas[curDataId];
					if(curData->offset == curReference->resourceDataLoc)
					{
						found = 1;
						data = curData;
						break;
					}
				}

				if(!found)
				{
					fprintf(stderr, "resource map id: %d reference id: %d, doesn't reference any data in the resource file.\n", out->numMaps, curRefId);
					exit(1);
				}
				else
				{
					curReference->resourceData = data;
				}
			}
		}

		out->numMaps++;
		out->resourceMaps = realloc(out->resourceMaps, sizeof (ResMap) * out->numMaps);

		out->resourceMaps[out->numMaps - 1] = currentResMap;
	}

	return out;
}

void freeResFile(ResFile **res)
{
	int i, j;

	if((*res) != NULL)
	{
		if((*res)->resourceDatas != NULL)
		{
			free((*res)->resourceDatas);
			(*res)->resourceDatas = NULL;
		}
		(*res)->numDatas = 0;

		if((*res)->resourceMaps != NULL)
		{
			for(i = 0; i < (*res)->numMaps; i++)
			{
				ResMap * curResMap = &(*res)->resourceMaps[i];

				if(curResMap->resourceTypes != NULL)
				{
					free(curResMap->resourceTypes);
					curResMap->resourceTypes = NULL;
				}
				curResMap->numTypes = 0;

				if(curResMap->references != NULL)
				{
					free(curResMap->references);
					curResMap->references = NULL;
				}
				curResMap->numReferences = 0;


				if(curResMap->names != NULL)
				{
					for(j = 0; j < curResMap->numNames; j++)
					{
						if(curResMap->names[j].name != NULL)
						{
							free(curResMap->names[j].name);
							curResMap->names[j].name = NULL;
						}
						curResMap->names[j].length = 0;
					}

					free(curResMap->names);
					curResMap->names = NULL;
				}
				curResMap->numNames = 0;
			}
			free((*res)->resourceMaps);
			(*res)->resourceMaps = NULL;
		}
		(*res)->numMaps = 0;

		if((*res)->fileData != NULL)
		{
			free((*res)->fileData);
			(*res)->fileData = NULL;
		}
		(*res)->fileDataSize = 0;

		free((*res));
		(*res) = NULL;
	}

	return;
}

void dumpRes(ResFile *res, FILE *outFile)
{
	fprintf(outFile, "resource data: %08x\n", res->header.resourceData);
	fprintf(outFile, "resource map: %08x\n", res->header.resourceMap);
	fprintf(outFile, "resource data length: %08x\n", res->header.resourceDataLength);
	fprintf(outFile, "resource map length: %08x\n", res->header.resourceMapLength);

	{
		int idx;
		int hexidx;
		char hexData[44];
		char hexChar[18];
		char curHex[4];

		for(idx = 0; idx < res->numDatas; idx++)
		{
			memset(hexData, '\0', sizeof hexData);
			memset(hexChar, '\0', sizeof hexChar);
			fprintf(outFile, "resData[%d]\n", idx);
			fprintf(outFile, "\toffset = %04x\n", res->resourceDatas[idx].offset);
			fprintf(outFile, "\tlength = %04x\n", res->resourceDatas[idx].resourceDataLength);
			for(hexidx = 0; hexidx < res->resourceDatas[idx].resourceDataLength; hexidx++)
			{
				if(hexidx % 16 == 0)
				{
					fprintf(outFile, "\t%08x  ", hexidx);
				}

				sprintf(curHex, "%02x ", (res->resourceDatas[idx].resourceData[hexidx] & 0xFF));
				strcat(hexData, curHex);

				if(hexidx % 16 == 7)
				{
					strcat(hexData, " ");
				}

				if(isspace(res->resourceDatas[idx].resourceData[hexidx]))
				{
					hexChar[hexidx % 16] = ' ';
				}
				else if(isprint(res->resourceDatas[idx].resourceData[hexidx]))
				{
					hexChar[hexidx % 16] = res->resourceDatas[idx].resourceData[hexidx];
				}
				else
				{
					hexChar[hexidx % 16] = '.';
				}

				if(hexidx % 16 == 15)
				{
					fprintf(outFile, "%-49s |%-16s|\n", hexData, hexChar);
					memset(hexData, '\0', sizeof hexData);
					memset(hexChar, '\0', sizeof hexChar);
				}

			}
			if(hexidx > 0 && hexidx % 16 != 0)
			{
				fprintf(outFile, "%-49s |%-16s|\n", hexData, hexChar);
			}
		}
	}

	{
		int idx;
		int inidx;

		for(idx = 0; idx < res->numMaps; idx++)
		{
			fprintf(outFile, "resMaps[%d]\n", idx);

			fprintf(outFile, "\tresource data: %08x\n", res->resourceMaps[idx].resHeader->resourceData);
			fprintf(outFile, "\tresource map: %08x\n", res->resourceMaps[idx].resHeader->resourceMap);
			fprintf(outFile, "\tresource data length: %08x\n", res->resourceMaps[idx].resHeader->resourceDataLength);
			fprintf(outFile, "\tresource map length: %08x\n", res->resourceMaps[idx].resHeader->resourceMapLength);
			fprintf(outFile, "\tnext res map: %08x\n", res->resourceMaps[idx].nextResMap);
			fprintf(outFile, "\tnext ref number: %04x\n", res->resourceMaps[idx].fileReferenceNumber);
			fprintf(outFile, "\tfile attributes: %04x\n", res->resourceMaps[idx].fileAttributes);
			fprintf(outFile, "\ttype list offset: %04x\n", res->resourceMaps[idx].typeListOffset);
			fprintf(outFile, "\tname list offset: %04x\n", res->resourceMaps[idx].nameListOffset);
			fprintf(outFile, "\tnum types: %04x\n", res->resourceMaps[idx].numTypes);

			for(inidx = 0; inidx < res->resourceMaps[idx].numTypes; inidx++)
			{
				ResType * curResType = &res->resourceMaps[idx].resourceTypes[inidx];

				fprintf(outFile, "\tresMaps[%d].resourceTypes[%d]\n", idx, inidx);
				fprintf(outFile, "\t\tresource type: %s\n", curResType->resourceType);
				fprintf(outFile, "\t\tnum resources: %04x\n", curResType->numResources);
				fprintf(outFile, "\t\treference List Offset: %04x\n", curResType->referenceListOffset);
				fprintf(outFile, "\t\treference List Loc: %08x\n", curResType->referenceListLoc);
			}

			fprintf(outFile, "\tnum references: %04x\n", res->resourceMaps[idx].numReferences);
			for(inidx = 0; inidx < res->resourceMaps[idx].numReferences; inidx++)
			{
				ResReference *curReference = &res->resourceMaps[idx].references[inidx];
				fprintf(outFile, "\tresMaps[%d].references[%d]\n", idx, inidx);

				fprintf(outFile, "\t\treference loc: %08x\n", curReference->referenceLoc);
				fprintf(outFile, "\t\tresource id: %d\n", curReference->resourceId);
				fprintf(outFile, "\t\tresource name off: %02x\n", curReference->resourceNameOff);
				fprintf(outFile, "\t\tresource name loc: %04x\n", curReference->resourceNameLoc);
				fprintf(outFile, "\t\tresource attributes: %02x\n", (curReference->resourceAttributes & 0xFF));
				fprintf(outFile, "\t\tresource data offset: %06x\n", curReference->resourceDataOffset);
				fprintf(outFile, "\t\tresource data loc: %08x\n", curReference->resourceDataLoc);
				fprintf(outFile, "\t\treference handle: %08x\n", curReference->resourceHandle);
			}

			fprintf(outFile, "\tnum names: %04x\n", res->resourceMaps[idx].numNames);
			for(inidx = 0; inidx < res->resourceMaps[idx].numNames; inidx++)
			{
				ResName *curName = &res->resourceMaps[idx].names[inidx];
				fprintf(outFile, "\tresMaps[%d].names[%d]\n", idx, inidx);

				fprintf(outFile, "\t\tlength: %02x\n", (curName->length & 0xFF));
				fprintf(outFile, "\t\tname: %s\n", curName->name);
			}
		}
	}

	return;
}

void dumpResDiffData(ResFile *res, FILE *outFile)
{
	{
		int idx;
		int inidx;

		for(idx = 0; idx < res->numMaps; idx++)
		{
			fprintf(outFile, "resMaps[%d]\n", idx);
			for(inidx = 0; inidx < res->resourceMaps[idx].numTypes; inidx++)
			{
				ResType * curResType = &res->resourceMaps[idx].resourceTypes[inidx];

				fprintf(outFile, "\tresType[%d]\n", inidx);
				fprintf(outFile, "\t\tresource type: \"%s\"\n", curResType->resourceType);
				fprintf(outFile, "\t\tnumber of resources of this in map: %04hx\n", curResType->numResources);

				if(curResType->reference)
				{
					ResReference *curReference = curResType->reference;

					fprintf(outFile, "\t\tresource ID: %04hx\n", curReference->resourceId);
					fprintf(outFile, "\t\tresource attributes: %02hhx\n", curReference->resourceAttributes);

					if(curReference->resourceName && curReference->resourceName->name)
					{
						fprintf(outFile, "\t\tname: \"%s\"\n", curReference->resourceName->name);
					}

					if(curReference->resourceData)
					{
						ResData *curData = curReference->resourceData;
						int hexidx;
						char hexData[44];
						char hexChar[18];
						char curHex[4];

						memset(hexData, '\0', sizeof hexData);
						memset(hexChar, '\0', sizeof hexChar);
						for(hexidx = 0; hexidx < curData->resourceDataLength; hexidx++)
						{
							if(hexidx % 16 == 0)
							{
								fprintf(outFile, "\t\t%08x  ", hexidx);
							}

							sprintf(curHex, "%02x ", (curData->resourceData[hexidx] & 0xFF));
							strcat(hexData, curHex);

							if(hexidx % 16 == 7)
							{
								strcat(hexData, " ");
							}

							if(isspace(curData->resourceData[hexidx]))
							{
								hexChar[hexidx % 16] = ' ';
							}
							else if(isprint(curData->resourceData[hexidx]))
							{
								hexChar[hexidx % 16] = curData->resourceData[hexidx];
							}
							else
							{
								hexChar[hexidx % 16] = '.';
							}

							if(hexidx % 16 == 15)
							{
								fprintf(outFile, "%-49s |%-16s|\n", hexData, hexChar);
								memset(hexData, '\0', sizeof hexData);
								memset(hexChar, '\0', sizeof hexChar);
							}

						}
						if(hexidx > 0 && hexidx % 16 != 0)
						{
							fprintf(outFile, "%-49s |%-16s|\n", hexData, hexChar);
						}
					}

					fprintf(outFile, "\t\thandle to resource: %08x\n", curReference->resourceHandle);
				}
			}
		}
	}
	/*{
		int idx;
		int hexidx;
		char hexData[44];
		char hexChar[18];
		char curHex[4];

		for(idx = 0; idx < res->numDatas; idx++)
		{
			memset(hexData, '\0', sizeof hexData);
			memset(hexChar, '\0', sizeof hexChar);
			fprintf(outFile, "resData[%d]\n", idx);
			fprintf(outFile, "\toffset = %04x\n", res->resourceDatas[idx].offset);
			fprintf(outFile, "\tlength = %04x\n", res->resourceDatas[idx].resourceDataLength);
			for(hexidx = 0; hexidx < res->resourceDatas[idx].resourceDataLength; hexidx++)
			{
				if(hexidx % 16 == 0)
				{
					fprintf(outFile, "\t%08x  ", hexidx);
				}

				sprintf(curHex, "%02x ", (res->resourceDatas[idx].resourceData[hexidx] & 0xFF));
				strcat(hexData, curHex);

				if(hexidx % 16 == 7)
				{
					strcat(hexData, " ");
				}

				if(isspace(res->resourceDatas[idx].resourceData[hexidx]))
				{
					hexChar[hexidx % 16] = ' ';
				}
				else if(isprint(res->resourceDatas[idx].resourceData[hexidx]))
				{
					hexChar[hexidx % 16] = res->resourceDatas[idx].resourceData[hexidx];
				}
				else
				{
					hexChar[hexidx % 16] = '.';
				}

				if(hexidx % 16 == 15)
				{
					fprintf(outFile, "%-49s |%-16s|\n", hexData, hexChar);
					memset(hexData, '\0', sizeof hexData);
					memset(hexChar, '\0', sizeof hexChar);
				}

			}
			if(hexidx > 0 && hexidx % 16 != 0)
			{
				fprintf(outFile, "%-49s |%-16s|\n", hexData, hexChar);
			}
		}
	}*/

	return;
}

int main(int argc, char **argv)
{
	ResFile *res = NULL;
	FILE *fp = NULL;

	if(argc != 2)
	{
		fprintf(stderr, "invalid number of args (expecting 1).\n");
		return 1;
	}

	if(strcmp(argv[1], "-") == 0)
	{
		fp = stdin;
	}
	else
	{
		fp = fopen(argv[1], "rb");
	}

	if(fp == NULL)
	{
		fprintf(stderr, "failed to open %s.\n", argv[1]);
		return 0;
	}

	res = parseResFile(fp);

	dumpResDiffData(res, stdout);

	freeResFile(&res);

	if(strcmp(argv[1], "-") != 0)
	{
		fclose(fp);
		fp = NULL;
	}

	return 1;
}
