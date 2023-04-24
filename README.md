### Lua classes for ZIP library

Bindings are found in my luajit-ffi-bindings project.

This is pretty incomplete at the moment.  I'm just using it for reading zip archives.

Example:

``` Lua
local Zip = require 'zip'
local z = Zip'test.zip'
print('number of files in zip = '..#z)	-- shows the # of files in test.zip
for f in z:dir() do
	print('...', f)		-- print a zip-file-path, similar to my ext.file path objects
	print((f:read()))	-- print the zip file contents
end
```
