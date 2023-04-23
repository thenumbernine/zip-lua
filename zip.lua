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
local zip = require 'ffi.zip'


local ZipPath = class()

function ZipPath:init(archive, index)
	self.zip = archive
	self.index = index
end

function ZipPath:name(flags)
	flags = flags or zip.ZIP_FL_ENC_GUESS
	local name = zip.zip_get_name(self.zip.handle, self.index, flags)
	if name == nil then
		self.zip:error()
	end
	return ffi.string(name)
end

function ZipPath:__tostring()
	return self.zip..':'..self:name()
end

function ZipPath.__concat(a,b)
	return tostring(a)..tostring(b)
end

function ZipPath:attr(flags)
	flags = flags or 0
	local st = ffi.new'zip_stat_t[1]'
	zip.zip_stat_init(st)
	if -1 == zip.zip_stat_index(self.zip.handle, self.index, flags, st) then
		self.zip:error()
	end
	local res = {}
	for k,v in pairs{
		name = zip.ZIP_STAT_NAME,
		index = zip.ZIP_STAT_INDEX,
		size = zip.ZIP_STAT_SIZE,
		comp_size = zip.ZIP_STAT_COMP_SIZE,
		mtime = zip.ZIP_STAT_MTIME,
		crc = zip.ZIP_STAT_CRC,
		comp_method = zip.ZIP_STAT_COMP_METHOD,
		encryption_method = zip.ZIP_STAT_ENCRYPTION_METHOD,
		flags = zip.ZIP_STAT_FLAGS,
	} do
		if bit.band(st[0].valid, v) ~= 0 then
			res[k] = st[0][k]
		end
	end
	if res.name then res.name = ffi.string(res.name) end
	return res
end

-- TODO ZipPath:open() that returns a ZipFile for :read and :write and close operations ...
-- then this could double as file:read / os.readfile
function ZipPath:read(flags)
	local attr = self:attr()
	local size = attr.size
	local buffer = ffi.new('uint8_t[?]', size)
	local f = zip.zip_fopen_index(self.zip.handle, self.index, flags or 0)
	assert(f ~= nil, "failed to open "..self.index.."'th file")
	zip.zip_fread(f, buffer, size)
	zip.zip_fclose(f)
	-- now in the name of ext.file compat I could return a string, but meh
	-- file is for vanilla lua anyways, this is only for luajit
	-- but what's a buffer without its size? so ...
	return buffer, attr
end

function ZipPath:readstr(flags)
	local buf, attr = self:read(flags)
	return ffi.string(buf, attr.size), attr
end

local ZipArchive = class()

function ZipArchive:init(fn)
	-- TODO what about creating zips?
	assert(fn, "expected filename")
	self.filename = fn
	
	-- TODO common behavior as other apis like cl and gl and posix ... consolidate?
	local err = ffi.new('int[1]', 0)
	self.handle = zip.zip_open(fn, 0, err)
	assert(err[0] == 0)
end

function ZipArchive:__gc()
	if self.handle then
		zip.zip_close(self.handle)
	end
end

function ZipArchive:numFiles(flags)
	return zip.zip_get_num_entries(self.handle, flags or 0)
end

function ZipArchive:__len()
	return tonumber(self:numFiles())
end

function ZipArchive:dir()
	return coroutine.wrap(function()
		for i=0,#self-1 do
			return ZipPath(self, i)
		end
	end)
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
