--[[
I'm going to try to write this to be as compatible with ext.file as possible...
Eventually...
Until then:

zip = Zip(filename)
zip:dir() = directory of zipped-file references
zip(path) = zipped-file reference

zip:read(fn) = read
--]]
local ffi = require 'ffi'
local class = require 'ext.class'
local zip = require 'ffi.req' 'zip'
local ZipPath = require 'zip.path'
local GCWrapper = require 'ffi.gcwrapper.gcwrapper'


local ZipArchive = class(GCWrapper{
	gctype = 'autorelease_zip_t',
	ctype = 'zip_t*',
	release = function(ptr)
		if ptr[0] ~= nil then
			zip.zip_close(ptr[0])
			ptr[0] = nil
		end
	end,
})

function ZipArchive:init(fn)
	ZipArchive.super.init(self)
	-- TODO what about creating zips?
	assert(fn, "expected filename")
	self.filename = fn

	-- TODO common behavior as other apis like cl and gl and posix ... consolidate?
	local err = ffi.new('int[1]', 0)
	self.handle = zip.zip_open(fn, 0, err)
	self.gc.ptr[0] = self.handle
	if err[0] ~= 0 then
		-- TODO can I convert this to zip_error_t , and then to zip_error_strerror?
		-- ... is it already a zip_error_t?
		error("zip_open("..tostring(fn)..") failed with error "..tostring(err[0]))
	end
end

--[[ not getting called ... so I'll use my ffi.gcwrapper.gcwrapper
function ZipArchive:__gc()
print('function ZipArchive:__gc()')
	if self.handle then
print('freeing zip',self.filename)
		zip.zip_close(self.handle)
	end
end
--]]

function ZipArchive:numFiles(flags)
	return zip.zip_get_num_entries(self.handle, flags or 0)
end

function ZipArchive:__len()
	return tonumber(self:numFiles())
end

function ZipArchive:dir()
	return coroutine.wrap(function()
		for i=0,#self-1 do
			coroutine.yield(ZipPath(self, i))
		end
	end)
end

function ZipArchive:index(fn, flags)
	local index = zip.zip_name_locate(self.handle, fn, flags or 0)
	-- maybe a bad idea?  lua compat vs scope of use
	index = tonumber(index)
	-- TODO how to detect errors?
	-- docs say it can produce ZIP_ER_INVAL, MEMORY, NOENT
	-- but how?
	-- when to check zip_error_code_system, zip_get_error, or zip_error_code_zip ?
	if index == -1 then return nil, "unable to locate file" end
	return index
end

function ZipArchive:file(fn)
	return ZipPath(self, (self:index(fn)))
end

function ZipArchive:exists(fn)
	-- I could do the typical fopen/fclose for normal files
	-- but this works as well:
	return not not self:index(fn)
end

function ZipArchive:__tostring()
	return 'zip('..self.filename..')'
end

function ZipArchive.__concat(a,b)
	return tostring(a)..tostring(b)
end

-- generate a Lua error based on the error information stored in this zip_t
function ZipArchive:error()
	local err = zip.zip_get_error(self.handle)
	if err == nil then
		return "no error"	-- can zip_error_strerror handle null zip_error_t's
	end
	local p = zip.zip_error_strerror(err)
	if p == nil then
		return "no strerror for error "..tostring(err)	-- will zip_error_strerror ever return nil?
	end
	return ffi.string(p)
end

function ZipArchive:error()
	error(self:strerror())
end

return ZipArchive
