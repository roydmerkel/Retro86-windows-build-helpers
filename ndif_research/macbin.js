const fs = require('fs');

class macbin {
	static unbin(filepath, callback) {
		var mac_roman = "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008\u0009\u000A\u000B\u000C\u000D\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\u001B\u001C\u001D\u001E\u001F\u0020\u0021\u0022\u0023\u0024\u0025\u0026\u0027\u0028\u0029\u002A\u002B\u002C\u002D\u002E\u002F\u0030\u0031\u0032\u0033\u0034\u0035\u0036\u0037\u0038\u0039\u003A\u003B\u003C\u003D\u003E\u003F\u0040\u0041\u0042\u0043\u0044\u0045\u0046\u0047\u0048\u0049\u004A\u004B\u004C\u004D\u004E\u004F\u0050\u0051\u0052\u0053\u0054\u0055\u0056\u0057\u0058\u0059\u005A\u005B\u005C\u005D\u005E\u005F\u0060\u0061\u0062\u0063\u0064\u0065\u0066\u0067\u0068\u0069\u006A\u006B\u006C\u006D\u006E\u006F\u0070\u0071\u0072\u0073\u0074\u0075\u0076\u0077\u0078\u0079\u007A\u007B\u007C\u007D\u007E\u007F\u00C4\u00C5\u00C7\u00C9\u00D1\u00D6\u00DC\u00E1\u00E0\u00E2\u00E4\u00E3\u00E5\u00E7\u00E9\u00E8\u00EA\u00EB\u00ED\u00EC\u00EE\u00EF\u00F1\u00F3\u00F2\u00F4\u00F6\u00F5\u00FA\u00F9\u00FB\u00FC\u2020\u00B0\u00A2\u00A3\u00A7\u2022\u00B6\u00DF\u00AE\u00A9\u2122\u00B4\u00A8\u2260\u00C6\u00D8\u221E\u00B1\u2264\u2265\u00A5\u00B5\u2202\u2211\u220F\u03C0\u222B\u00AA\u00BA\u03A9\u00E6\u00F8\u00BF\u00A1\u00AC\u221A\u0192\u2248\u2206\u00AB\u00BB\u2026\u00A0\u00C0\u00C3\u00D5\u0152\u0153\u2013\u2014\u201C\u201D\u2018\u2019\u00F7\u25CA\u00FF\u0178\u2044\u20AC\u2039\u203A\uFB01\uFB02\u2021\u00B7\u201A\u201E\u2030\u00C2\u00CA\u00C1\u00CB\u00C8\u00CD\u00CE\u00CF\u00CC\u00D3\u00D4\uF8FF\u00D2\u00DA\u00DB\u00D9\u0131\u02C6\u02DC\u00AF\u02D8\u02D9\u02DA\u00B8\u02DD\u02DB\u02C7";
		var readGuarenteed = function(fd, buffer, offset, size, callback) {
			fs.read(fd, buffer, offset, size, null, (err, bytesRead, inBuf) => {
				if(err)
				{
					callback(err);
				}
				else if(offset + bytesRead < size)
				{
					readGuarenteed(fd, inBuf, offset + bytesRead, size - offset, callback);
				}
				else
				{
					callback();
				}
			});
		};
		var close = function(fd, err, callback) {
			if(err)
			{
				fs.close(fd, (e) => {
					callback(err);
				});
			}
			else
			{
				fs.close(fd, (err) => {
					callback(err);
				});
			}
		};
		var readSkipAndData = function(fd, dataLength, resourceLength, callback)
		{
			var resourceBuffer = new Buffer(resourceLength);
			var skipForward = ((dataLength+127)&~127) - dataLength;

			if(skipForward > 0)
			{
				var skipBuf = new Buffer(skipForward);

				readGuarenteed(fd, skipBuf, 0, skipForward, (err) => {
					if(err)
					{
						close(fd, err, callback);
					}
					else
					{
						readGuarenteed(fd, resourceBuffer, 0, resourceLength, (err) => {
							if(err)
							{
								close(fd, err, callback);
							}
							else
							{
								callback(null, resourceBuffer);
							}
						});
					}
				});
			}
			else
			{
				readGuarenteed(fd, resourceBuffer, 0, resourceLength, (err) => {
					if(err)
					{
						close(fd, err, callback);
					}
					else
					{
						callback(null, resourceBuffer);
					}
				});
			}
		};
		var readResourceAndData = function(fd, dataLength, resourceLength, callback)
		{
			var dataBuffer = new Buffer(dataLength);
			readGuarenteed(fd, dataBuffer, 0, dataLength, (err) => {
				if(err)
				{
					close(fd, err, callback);
				}
				else
				{
					readSkipAndData(fd, dataLength, resourceLength, (err, resourceBuffer) => {
						if(err)
						{
							callback(err);
						}
						else
						{
							callback(null, resourceBuffer, dataBuffer);
						}
					})
				}
			});
		};
		var readHeaderResourceAndData = function(fd, callback)
		{
			var headerSize = 128;
			var headerBuffer = new Buffer(headerSize);

			readGuarenteed(fd, headerBuffer, 0, headerSize, (err) => {
				if(err)
				{
					close(fd, err, callback);
				}
				else
				{
					if (headerBuffer[0] != 0 || headerBuffer[74] != 0 || headerBuffer[82] != 0 || headerBuffer[1] <= 0 || headerBuffer[1] > 33 || headerBuffer[63] != 0 || headerBuffer[2+headerBuffer[1]] != 0 )
					{
						var err = filepath + " does not look like a macbinary file";
						close(fd, err, callback);
					}
					else
					{
						var name = "";
						var nameLen = headerBuffer[1];
						for(var i = 0; i < nameLen; i++)
						{
							name += mac_roman[headerBuffer[2 + i]];
						}

						var dataLength = ((headerBuffer[0x53] << 24) | (headerBuffer[0x54] << 16) | (headerBuffer[0x55] << 8) | headerBuffer[0x56]);
						var resourceLength = ((headerBuffer[0x57] << 24) | (headerBuffer[0x58] << 16) | (headerBuffer[0x59] << 8) | headerBuffer[0x5a]);

						readResourceAndData(fd, dataLength, resourceLength, (err, resourceBuffer, dataBuffer) => {
							if(err)
							{
								callback(err);
							}
							else
							{
								callback(null, name, resourceBuffer, dataBuffer);
							}
						});
					}
				}
			});
		};
		fs.open(filepath, "r", (err, fd) => {
			if(err)
			{
				callback(err);
			}
			else
			{
				readHeaderResourceAndData(fd, callback);
			}
		});
	}
}

module.exports = macbin;
