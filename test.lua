#!/usr/bin/env luajit
local Zip = require 'zip'
local z = Zip'test.zip'
print('number of files in zip = '..#z)	-- shows the # of files in test.zip
for f in z:dir() do
	print('...', f)	-- print a zip-file-path, similar to my ext.file path objects
	print((f:read()))	-- print the zip file contents
end
