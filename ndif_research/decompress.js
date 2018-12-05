#!/usr/bin/node

var util = require('util');
var adc = require('apple-data-compression');
var fs = require('fs');

if(process.argv.length != 4)
{
	console.log("incorrect number of arguments: usage: " + process.argv[1] + " <in file> <out file>\n");
	process.exit(1);
}

const resfork = require('./resfork.js');
const macbin = require('./macbin.js');

macbin.unbin(process.argv[2], (err, name, resourceBuffer, dataBuffer) => { 
	var res = resfork.parseResFile(resourceBuffer);
	var bcem = null;
	console.log(util.inspect(res, {showHidden: false, depth: 5}));
	if(res != null && res.resourceMaps != null)
	{
		res.resourceMaps.forEach((resourceMap) => {
			if(resourceMap.resourceTypes != null)
			{
				resourceMap.resourceTypes.forEach((resourceType) => {
					if(resourceType.resourceType != null && resourceType.resourceType == "bcem")
					{
						bcem = resourceType;
					}
				});
			}
		});
	}
	if(bcem != null)
	{
		var reference = bcem.reference;

		if(reference != null)
		{
			var resourceData = reference.resourceData;

			if(resourceData != null)
			{
				if(resourceData.resourceData != null)
				{
					var resData = resourceData.resourceData;

					var idx = 0x0090;
					var one = resData[idx++];
					var two = resData[idx++];
					var three = resData[idx++];
					var four = resData[idx++];
					var dataHeaderLength = (one << 24) | (two << 16) | (three << 8) | four;

					var dataFooterLength = 512; // might also be 511

					var dataHeader = dataBuffer.slice(0, dataHeaderLength);
					var dataBody = dataBuffer.slice(dataHeaderLength, dataBuffer.length - dataFooterLength);
					var dataFooter = dataBuffer.slice(dataBuffer.length - dataFooterLength);
					dataBody = adc.decompress(dataBody);

					console.log(dataHeader);
					console.log(dataBody);
					console.log(dataFooter);

					fs.open(process.argv[3], "w", (err, fd) => {
						if(err)
						{
							throw err;
						}

						fs.write(fd, dataHeader, (err, bytesWritten, buffer) => {
							if(err)
							{
								throw err;
							}

							fs.write(fd, dataBody, (err, bytesWritten, buffer) => {
								if(err)
								{
									throw err;
								}

								fs.write(fd, dataFooter, (err, bytesWritten, buffer) => {
									if(err)
									{
										throw err;
									}

									fs.close(fd, (err) => {
										if(err)
										{
											throw err;
										}
									});
								});
							});
						});
					});
				}
			}
		}
	}
});

/*;

var transform = new adc.Decompressor();

var indata = "";
//fs.createReadStream(process.argv[2]).pipe(transform).on('data', (chunk) => { data += chunk });

fs.readFile(process.argv[2], function(err, data) {
	if(err) throw err;

	//var result = data;

	fs.writeFile(process.argv[3], result, (err2) => {
		if(err2) throw err2;
	});
});*/

