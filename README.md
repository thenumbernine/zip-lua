### Lua classes for ZIP library

Bindings are found in my luajit-ffi-bindings project.

This is pretty incomplete at the moment.  I'm just using it for reading zip archives.

Example:

``` Lua
local Zip = require 'zip'

local z = Zip'file.zip'
print(#z)	-- shows the # of files in file.zip
for f in z:dir() do
	print(f)	-- print a zip-file-path, similar to my ext.file path objects
	print(f:readstr())	-- print the zip file contents
end
```
