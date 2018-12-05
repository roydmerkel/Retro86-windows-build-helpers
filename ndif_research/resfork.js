class ResHeader
{
	constructor()
	{
		this.resourceData = 0;
		this.resourceMap = 0;
		this.resourceDataLength = 0;
		this.resourceMapLength = 0;
	}
}

class ResData
{
	constructor()
	{
		this.offset = 0;
		this.resourceDataLength = 0;
		this.resourceData = null;
	}
}

class ResName
{
	constructor()
	{
		this.offset = 0;
		this.length = 0;
		this.name = "";
	}
}

class ResReference
{
	constructor()
	{
		this.referenceLoc = 0;
		this.resourceId = 0;
		this.resourceNameOff = 0;
		this.resourceNameLoc = 0;
		this.resourceName = null;
		//ResName *resourceName;
		this.resourceAttributes = 0;
		this.resourceDataOffset = 0;
		this.resourceDataLoc = 0;
		this.resourceData = null;
		//ResData *resourceData;
		this.resourceHandle = 0;
	}
}

class ResType
{
	constructor()
	{
		this.resourceType = "";
		this.numResources = 0;
		this.referenceListOffset = 0;
		this.referenceListLoc = 0;
		this.reference = null;
		//ResReference * reference;
	}
}

class ResMap
{
	constructor()
	{
		this.resHeader = null;
		//ResHeader * resHeader;
		this.nextResMap = 0;
		this.fileReferenceNumber = 0;
		this.fileAttributes = 0;
		this.typeListOffset = 0;
		this.nameListOffset = 0;
		this.numTypes = 0;
		this.resourceTypes = [];
		//ResType *resourceTypes;
		this.numReferences = 0;
		this.references = [];
		//ResReference *references;
		this.numNames = 0;
		this.names = [];
		//ResName *names;
	}
}

class ResFile
{
	constructor()
	{
		this.fileDataSize = 0;
		this.fileData = null;
		//char *fileData;
		this.header = new ResHeader();
		//resheader header;
		this.numDatas = 0;
		this.resourceDatas = [];
		//ResData *resourceDatas;
		this.numMaps = 0;
		this.resourceMaps = [];
		//ResMap *resourceMaps;
	}
}

class resfork {
	static parseResFile(buffer)
	{
		var mac_roman = "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008\u0009\u000A\u000B\u000C\u000D\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\u001B\u001C\u001D\u001E\u001F\u0020\u0021\u0022\u0023\u0024\u0025\u0026\u0027\u0028\u0029\u002A\u002B\u002C\u002D\u002E\u002F\u0030\u0031\u0032\u0033\u0034\u0035\u0036\u0037\u0038\u0039\u003A\u003B\u003C\u003D\u003E\u003F\u0040\u0041\u0042\u0043\u0044\u0045\u0046\u0047\u0048\u0049\u004A\u004B\u004C\u004D\u004E\u004F\u0050\u0051\u0052\u0053\u0054\u0055\u0056\u0057\u0058\u0059\u005A\u005B\u005C\u005D\u005E\u005F\u0060\u0061\u0062\u0063\u0064\u0065\u0066\u0067\u0068\u0069\u006A\u006B\u006C\u006D\u006E\u006F\u0070\u0071\u0072\u0073\u0074\u0075\u0076\u0077\u0078\u0079\u007A\u007B\u007C\u007D\u007E\u007F\u00C4\u00C5\u00C7\u00C9\u00D1\u00D6\u00DC\u00E1\u00E0\u00E2\u00E4\u00E3\u00E5\u00E7\u00E9\u00E8\u00EA\u00EB\u00ED\u00EC\u00EE\u00EF\u00F1\u00F3\u00F2\u00F4\u00F6\u00F5\u00FA\u00F9\u00FB\u00FC\u2020\u00B0\u00A2\u00A3\u00A7\u2022\u00B6\u00DF\u00AE\u00A9\u2122\u00B4\u00A8\u2260\u00C6\u00D8\u221E\u00B1\u2264\u2265\u00A5\u00B5\u2202\u2211\u220F\u03C0\u222B\u00AA\u00BA\u03A9\u00E6\u00F8\u00BF\u00A1\u00AC\u221A\u0192\u2248\u2206\u00AB\u00BB\u2026\u00A0\u00C0\u00C3\u00D5\u0152\u0153\u2013\u2014\u201C\u201D\u2018\u2019\u00F7\u25CA\u00FF\u0178\u2044\u20AC\u2039\u203A\uFB01\uFB02\u2021\u00B7\u201A\u201E\u2030\u00C2\u00CA\u00C1\u00CB\u00C8\u00CD\u00CE\u00CF\u00CC\u00D3\u00D4\uF8FF\u00D2\u00DA\u00DB\u00D9\u0131\u02C6\u02DC\u00AF\u02D8\u02D9\u02DA\u00B8\u02DD\u02DB\u02C7";
		var idx = 0;
		var out = new ResFile();

		var READ_STRING_N = function(N)
		{
			var DEST = "";
			if(idx + N <= out.fileDataSize)
			{
				var bufIdx;
				for(bufIdx = 0; bufIdx < N; bufIdx++)
				{
					DEST += mac_roman[out.fileData[idx++]];
				}
			}
			else
			{
				throw "Failed to read string(" + N + "): EOF detected.";
			}
			return DEST;
		}

		var READ_CHAR = function()
		{
			var DEST = '\0';
			if(idx + 1 <= out.fileDataSize)
			{
				DEST = mac_roman[out.fileData[idx++]];
			}
			else
			{
				throw "Failed to read char: EOF detected.";
			}

			return DEST;
		}

		var READ_INT_8 = function()
		{
			var DEST = 0;

			if(idx + 1 <= out.fileDataSize)
			{
				var one = out.fileData[idx++] & 0xFF;

				DEST = one;
				DEST = DEST >>> 0;
			}
			else
			{
				throw "Failed to read int 8: EOF detected.";
			}

			return DEST;
		}

		var READ_SINT_8 = function()
		{
			var DEST = 0;

			if(idx + 1 <= out.fileDataSize)
			{
				var one = out.fileData[idx++] & 0xFF;

				DEST = one;
				DEST = DEST >>> 0;

				if(DEST & 0x80)
				{
					// two's complement.
					DEST -= 1;
					DEST = ~DEST;
					DEST &= 0xFF;

					// negate (it's now positive)
					DEST = -DEST;
				}
			}
			else
			{
				throw "Failed to read signed int 8: EOF detected.";
			}

			return DEST;
		}

		var READ_INT_16 = function()
		{
			var DEST = 0;

			if(idx + 2 <= out.fileDataSize)
			{
				var one = (out.fileData[idx++] & 0xFF);
				var two = (out.fileData[idx++] & 0xFF);

				DEST = (one << 8) | two;
				DEST = DEST >>> 0;
			}
			else
			{
				throw "Failed to read int 16 EOF detected.";
			}

			return DEST;
		}

		var READ_SINT_16 = function()
		{
			var DEST = 0;

			if(idx + 2 <= out.fileDataSize)
			{
				var one = (out.fileData[idx++] & 0xFF);
				var two = (out.fileData[idx++] & 0xFF);

				DEST = (one << 8) | two;
				DEST = DEST >>> 0;

				if(DEST & 0x8000)
				{
					// two's complement.
					DEST -= 1;
					DEST = ~DEST;
					DEST &= 0xFFFF;

					// negate (it's now positive)
					DEST = -DEST;
				}
			}
			else
			{
				throw "Failed to read signed int 16 EOF detected.";
			}

			return DEST;
		}

		var READ_INT_24 = function()
		{
			var DEST = 0;

			if(idx + 3 <= out.fileDataSize)
			{
				var one = (out.fileData[idx++] & 0xFF);
				var two = (out.fileData[idx++] & 0xFF);
				var three = (out.fileData[idx++] & 0xFF);

				DEST = (one << 16) | (two << 8) | three;
				DEST = DEST >>> 0;
			}
			else
			{
				throw "Failed to read int 24 EOF detected.";
			}

			return DEST;
		}

		var READ_SINT_24 = function()
		{
			var DEST = 0;

			if(idx + 3 <= out.fileDataSize)
			{
				var one = (out.fileData[idx++] & 0xFF);
				var two = (out.fileData[idx++] & 0xFF);
				var three = (out.fileData[idx++] & 0xFF);

				DEST = (one << 16) | (two << 8) | three;
				DEST = DEST >>> 0;

				if(DEST & 0x800000)
				{
					// two's complement.
					DEST -= 1;
					DEST = ~DEST;
					DEST &= 0xFFFFFF;

					// negate (it's now positive)
					DEST = -DEST;
				}
			}
			else
			{
				throw "Failed to read signed int 24 EOF detected.";
			}

			return DEST;
		}

		var READ_INT_32 = function()
		{
			var DEST = 0;

			if(idx + 4 <= out.fileDataSize)
			{
				var one = (out.fileData[idx++] & 0xFF);
				var two = (out.fileData[idx++] & 0xFF);
				var three = (out.fileData[idx++] & 0xFF);
				var four = (out.fileData[idx++] & 0xFF);

				DEST = (one << 24) | (two << 16) | (three << 8) | four;
				DEST = DEST >>> 0;
			}
			else
			{
				throw "Failed to read int 24 EOF detected.";
			}

			return DEST;
		}

		var READ_SINT_32 = function()
		{
			var DEST = 0;

			if(idx + 4 <= out.fileDataSize)
			{
				var one = (out.fileData[idx++] & 0xFF);
				var two = (out.fileData[idx++] & 0xFF);
				var three = (out.fileData[idx++] & 0xFF);
				var four = (out.fileData[idx++] & 0xFF);

				DEST = (one << 24) | (two << 16) | (three << 8) | four;
				DEST = DEST >>> 0;

				if(DEST & 0x80000000)
				{
					// two's complement.
					DEST -= 1;
					DEST = ~DEST;
					DEST &= 0xFFFFFFFF;

					// negate (it's now positive)
					DEST = -DEST;
				}
			}
			else
			{
				throw "Failed to read signed int 24 EOF detected.";
			}

			return DEST;
		}

		out.fileDataSize = buffer.length;
		out.fileData = buffer;

		out.header.resourceData = READ_INT_32();
		out.header.resourceMap = READ_INT_32();
		out.header.resourceDataLength = READ_INT_32();
		out.header.resourceMapLength = READ_INT_32();

		if(out.header.resourceData + out.header.resourceDataLength != out.header.resourceMap)
		{
			throw "resource mismatch, resource map should begin directly after resource data.";
		}

		if(out.header.resourceMap + out.header.resourceMapLength != out.fileDataSize)
		{
			throw "resource mismatch, resource map should be the final thing in the resource file.";
		}

		idx = out.header.resourceData;

		while(idx < out.header.resourceData + out.header.resourceDataLength)
		{
			var currentRes = new ResData();

			currentRes.offset = idx;

			if(idx + 4 > out.header.resourceData + out.header.resourceDataLength)
			{
				throw "malformed resourceData segment... Length is less then the sum total of all resources (while reading length).";
			}

			currentRes.resourceDataLength = READ_INT_32();

			if(idx + currentRes.resourceDataLength > out.header.resourceData + out.header.resourceDataLength)
			{
				throw "malformed resourceData segment... Length is less then the sum total of all resources (while reading data).";
			}

			currentRes.resourceData = out.fileData.slice(idx, idx + currentRes.resourceDataLength);

			idx += currentRes.resourceDataLength;

			out.numDatas++;
			out.resourceDatas.push(currentRes);
		}

		// Read resource maps.
		while(idx < out.header.resourceMap + out.header.resourceMapLength)
		{
			// read the headers.
			var curTypeId = 0;
			var startIdx = idx;
			var currentResMap = new ResMap();
			var testHeader = new ResHeader();

			testHeader.resourceData = READ_INT_32();
			testHeader.resourceMap = READ_INT_32();
			testHeader.resourceDataLength = READ_INT_32();
			testHeader.resourceMapLength = READ_INT_32();

			// check the header against the header of the resource.
			if(testHeader.resourceData != out.header.resourceData)
			{
				throw "resourceData field of resouce map header field doesn't map resource header.";
			}
			else if(testHeader.resourceMap != out.header.resourceMap)
			{
				throw "resourceMap field of resouce map header field doesn't map resource header.";
			}
			else if(testHeader.resourceDataLength != out.header.resourceDataLength)
			{
				throw "resourceDataLength field of resouce map header field doesn't map resource header.";
			}
			else if(testHeader.resourceMapLength != out.header.resourceMapLength)
			{
				throw "resourceMapLength field of resouce map header field doesn't map resource header.";
			}
			else
			{
				currentResMap.resHeader = out.header;
			}

			// read the rest of the resource map header.
			currentResMap.nextResMap = READ_INT_32();
			currentResMap.fileReferenceNumber = READ_INT_16();
			currentResMap.fileAttributes = READ_INT_16();
			currentResMap.typeListOffset = READ_INT_16();
			currentResMap.nameListOffset = READ_INT_16();
			currentResMap.numTypes = READ_INT_16();

			currentResMap.numTypes++;

			// verify that the type list pointer matches the type list location.
			if(startIdx + currentResMap.typeListOffset + 2 != idx)
			{
				throw "type list offset doesn't match location of type list in resource header.";
			}

			// read the resource types.
			//currentResMap.resourceTypes = (ResType *)calloc(currentResMap.numTypes, sizeof (ResType));
			for(curTypeId = 0; curTypeId < currentResMap.numTypes; curTypeId++)
			{
				var curRes = new ResType();
				//ResType *curRes = &currentResMap.resourceTypes[curTypeId];
		
				curRes.resourceType = READ_STRING_N(4);
				curRes.numResources = READ_INT_16();
				curRes.referenceListOffset = READ_INT_16();

				curRes.numResources++;
				
				curRes.referenceListLoc = startIdx + currentResMap.typeListOffset + curRes.referenceListOffset;

				currentResMap.resourceTypes.push(curRes);
			}

			// read the resource references.
			//currentResMap.references = (ResReference *)calloc(0, sizeof (ResReference));
			while(idx < startIdx + currentResMap.nameListOffset)
			{
				curReference = new ResReference();

				curReference.referenceLoc = idx;
				curReference.resourceId = READ_SINT_16();
				curReference.resourceNameOff = READ_INT_16();

				if(curReference.resourceNameOff == 0xFFFF)
				{
					curReference.resourceNameLoc = 0xFFFFFFFF;
				}
				else
				{
					curReference.resourceNameLoc = startIdx + currentResMap.nameListOffset + curReference.resourceNameOff;
				}
				curReference.resourceAttributes = READ_INT_8();
				curReference.resourceDataOffset = READ_INT_24();
				curReference.resourceHandle = READ_INT_32();
				
				curReference.resourceDataLoc = out.header.resourceData + curReference.resourceDataOffset;

				currentResMap.numReferences++;

				//currentResMap.references = realloc(currentResMap.references, sizeof (ResReference) * currentResMap.numReferences);
				currentResMap.references.push(curReference);
			}

			// read the resource names.
			while(idx < out.fileDataSize - 1)
			{
				var curName = new ResName();
				var charidx = 0;

				curName.offset = idx;
				curName.length = READ_INT_8();
				curName.name = "";
				for(charidx = 0; charidx < curName.length; charidx++)
				{
					curName.name += READ_CHAR();
				}

				currentResMap.numNames++;

				//currentResMap.names = realloc(currentResMap.names, sizeof (ResReference) * currentResMap.numNames);
				currentResMap.names.push(curName);
			}

			// match the resource type reference offsets to pointers and verify that all links are valid.	
			{
				var curTypeId;
				var curRefId;
				var found;

				for(curTypeId = 0; curTypeId < currentResMap.numTypes; curTypeId++)
				{
					var reference = null;
					var curResType = currentResMap.resourceTypes[curTypeId];

					found = false;
					for(curRefId = 0; curRefId < currentResMap.numReferences; curRefId++)
					{
						var curReference = currentResMap.references[curRefId];

						if(curReference.referenceLoc == curResType.referenceListLoc)
						{
							found = true;
							reference = curReference;
							break;
						}
					}

					if(!found)
					{
						throw "resource map id: " + out.numMaps + " reference type id: " + curTypeId + ", doesn't reference any reference in the resource file.";
					}
					else
					{
						curResType.reference = reference;
					}
				}
			}

			// match the reference list name offsets to pointers and verify that all links are valid.	
			{
				var curRefId;
				var curNameId;
				var curDataId;
				var found;

				for(curRefId = 0; curRefId < currentResMap.numReferences; curRefId++)
				{
					var name = null;
					var data = null;
					var curReference = currentResMap.references[curRefId];

					if(curReference.resourceNameLoc == 0xFFFFFFFF)
					{
						curReference.resourceName = null;
					}
					else
					{
						found = false;
						for(curNameId = 0; curNameId < currentResMap.numNames; curNameId++)
						{
							var curName = currentResMap.names[curNameId];

							if(curName.offset == curReference.resourceNameLoc)
							{
								found = true;
								name = curName;
								break;
							}
						}

						if(!found)
						{
							throw "resource map id: " + out.numMaps + " reference id: " + curRefId + ", doesn't reference any reference in the resource file.";
						}
						else
						{
							curReference.resourceName = name;
						}
					}

					found = false;
					for(curDataId = 0; curDataId < out.numDatas; curDataId++)
					{
						var curData = out.resourceDatas[curDataId];
						if(curData.offset == curReference.resourceDataLoc)
						{
							found = true;
							data = curData;
							break;
						}
					}

					if(!found)
					{
						throw "resource map id: " + out.numMaps + " reference id: " + curRefId + ", doesn't reference any data in the resource file.";
					}
					else
					{
						curReference.resourceData = data;
					}
				}
			}

			out.numMaps++;
			//out.resourceMaps = realloc(out.resourceMaps, sizeof (ResMap) * out.numMaps);

			out.resourceMaps.push(currentResMap);
		}

		return out;
	}
}

module.exports = resfork;
