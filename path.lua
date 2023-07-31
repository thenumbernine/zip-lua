local ffi = require 'ffi'
local class = require 'ext.class'
local zip = require 'ffi.req' 'zip'

local ZipPath = class()

function ZipPath:init(archive, index)
	self.zip = assert(archive)
	self.index = index	-- index, or nil for dead references
	-- for ext.path compat, allow bad refs to init, but don't let them do anything
	--assert(self.index or self.filename)
end

function ZipPath:exists()
	return not not self.index
end

function ZipPath:name(flags)
	if not self.index then error("ZipPath:name() failed: invalid zipfile") end
	flags = flags or zip.ZIP_FL_ENC_GUESS
	local name = zip.zip_get_name(self.zip.handle, self.index, flags)
	if name == nil then
		self.zip:error()
	end
	return ffi.string(name)
end

function ZipPath:__tostring()
	return self.zip..(self:exists() and (' #'..self.index..':'..self:name()) or '')
end

function ZipPath.__concat(a,b)
	return tostring(a)..tostring(b)
end

ZipPath.attrKeyMap = {
	name = zip.ZIP_STAT_NAME,
	index = zip.ZIP_STAT_INDEX,
	size = zip.ZIP_STAT_SIZE,
	comp_size = zip.ZIP_STAT_COMP_SIZE,
	mtime = zip.ZIP_STAT_MTIME,
	crc = zip.ZIP_STAT_CRC,
	comp_method = zip.ZIP_STAT_COMP_METHOD,
	encryption_method = zip.ZIP_STAT_ENCRYPTION_METHOD,
	flags = zip.ZIP_STAT_FLAGS,
}
function ZipPath:attr(flags)
	if not self.index then error("ZipPath:attr() failed: invalid zipfile") end
	flags = flags or 0
	local st = ffi.new'zip_stat_t[1]'
	zip.zip_stat_init(st)
	if self.index then
		if zip.zip_stat_index(self.zip.handle, self.index, flags, st) == -1 then
			self.zip:error()
		end
	elseif self.filename then
		if zip.zip_stat(self.zip.handle, self.filename, flags, st) == -1 then
			self.zip:error()
		end
	else
		error("ZipPath:attr(): expected .index or .filename to be provided")
	end
	local res = {}
	for k,v in pairs(self.attrKeyMap) do
		if bit.band(st[0].valid, v) ~= 0 then
			res[k] = st[0][k]
		end
	end
	if res.name then res.name = ffi.string(res.name) end
	return res
end

-- TODO ZipPath:open() that returns a ZipFile for :read and :write and close operations ...
-- then this could double as path:read / os.readfile
function ZipPath:readbuf(flags)
	if not self.index then error("ZipPath:attr() failed: invalid zipfile") end
	flags = flags or 0
	local attr = self:attr()
	local size = attr.size
	local buffer = ffi.new('uint8_t[?]', size)
	-- TODO ZipFile class with :read(), :write(), :close()
	local f
	if self.index then
		f = zip.zip_fopen_index(self.zip.handle, self.index, flags)
	elseif self.filename then
		f = zip.zip_fopen(self.zip.handle, self.filename, flags)
	else
		error("ZipPath:readbuf(): expected .index or .filename to be provided")
	end
	if f == nil then
		error(self.zip.filename..": failed to open "..self.index.."'th file: "..self.zip:errorstr())
	end
	if zip.zip_fread(f, buffer, size) == -1 then
		-- docs don't say, but in this case is it a zip_error_t?  from this file?  from the archive?
		error("zip_fread() failed")
	end
	local res = zip.zip_fclose(f)
	if res ~= 0 then
		-- docs say upon failure the error code is returned
		-- so it doesn't use the ol' zip_error_t method?
		error("zip_fclose() failed")
	end
	-- now in the name of ext.path compat I could return a string, but meh
	-- path is for vanilla lua anyways, this is only for luajit
	-- but what's a buffer without its size? so ...
	return buffer, attr
end

-- returns a string, just like ext.path:read()
function ZipPath:read(flags)
	local buf, attr = self:readbuf(flags)
	return ffi.string(buf, attr.size), attr
end

return ZipPath
