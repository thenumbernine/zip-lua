--[[
I could make a separate 'tar' project
but it's probably a better idea to just put this all in an 'archive' project
and abstract the interface for various formats
--]]
require 'ext.gc'	-- __gc for luajit
local ffi = require 'ffi'
local class = require 'ext.class'
local archive = require 'ffi.req' 'archive'

local TarArchive = class()

function TarArchive:free()
	archive.archive_read_free(self.handle)
end

local function archiveAssert(fname, handle, ...)
	local ret = archive[fname](handle, ...)
	if ret == archive.ARCHIVE_EOF 
	or ret == archive.ARCHIVE_OK
	then
	elseif ret == archive.ARCHIVE_WARN then
		-- does ARCHIVE_WARN set archive_error_string() ? can't find this in the docs ... 
		io.stderr:write(fname..' warning: '..ffi.string(archive.archive_error_string(handle))..'\n')
	else--if ret == archive.ARCHIVE_RETRY
		-- are there unlisted error codess? example codes hint at this , using < instead of == for ok vs warn vs fatal
		error(fname..' failed with '..ffi.string(archive.archive_error_string(handle)))
	end
	return ret
end

function TarArchive:init(fn)
	self.archive = archive.archive_read_new()
	if self.archive == nil then error'archive_read_new failed' end

	archiveAssert('archive_read_support_format_all', self.handle)
	archiveAssert('archive_read_open_filename', self.handle, filename, 10240)
end

function TarArchive:dir()
	local entry = ffi.new'struct archive_entry[1]'
	while true do
		local ret = archive.archive_read_next_header(self.handle, entry)
		if ret == archive.ARCHIVE_EOF then 
			break 
		end
		--local size = archive.archive_entry_size(entry)
		
		-- coroutine.yield(TarPath(self, entry))
	end
	
	archive.archive_read_close(self.handle)
end

function TarArchive:file(fn)
	error'TODO'
end

return TarArchive 
