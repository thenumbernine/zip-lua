### Lua classes for ZIP library

Bindings are found in my luajit-ffi-bindings project.

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
