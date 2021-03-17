local ffi = require("ffi")
ffi.cdef([[
	void* malloc( size_t size );
	void* realloc( void *ptr, size_t new_size );
	void free( void* ptr );
]])
local util = {}

do
	local NumberConverter = ffi.new("union { uint32_t i[2]; double d; uint64_t ull; int64_t ll; }")

	function util.GetNumberConverter()
		return NumberConverter
	end
end

do
	local bcnames2_1 = "ISLT  ISGE  ISLE  ISGT  ISEQV ISNEV ISEQS ISNES ISEQN ISNEN ISEQP ISNEP ISTC  ISFC  IST   ISF   ISTYPEISNUM MOV   NOT   UNM   LEN   ADDVN SUBVN MULVN DIVVN MODVN ADDNV SUBNV MULNV DIVNV MODNV ADDVV SUBVV MULVV DIVVV MODVV POW   CAT   KSTR  KCDATAKSHORTKNUM  KPRI  KNIL  UGET  USETV USETS USETN USETP UCLO  FNEW  TNEW  TDUP  GGET  GSET  TGETV TGETS TGETB TGETR TSETV TSETS TSETB TSETM TSETR CALLM CALL  CALLMTCALLT ITERC ITERN VARG  ISNEXTRETM  RET   RET0  RET1  FORI  JFORI FORL  IFORL JFORL ITERL IITERLJITERLLOOP  ILOOP JLOOP JMP   FUNCF IFUNCFJFUNCFFUNCV IFUNCVJFUNCVFUNCC FUNCCW"
	local bcnames2_0 = "ISLT  ISGE  ISLE  ISGT  ISEQV ISNEV ISEQS ISNES ISEQN ISNEN ISEQP ISNEP ISTC  ISFC  IST   ISF   MOV   NOT   UNM   LEN   ADDVN SUBVN MULVN DIVVN MODVN ADDNV SUBNV MULNV DIVNV MODNV ADDVV SUBVV MULVV DIVVV MODVV POW   CAT   KSTR  KCDATAKSHORTKNUM  KPRI  KNIL  UGET  USETV USETS USETN USETP UCLO  FNEW  TNEW  TDUP  GGET  GSET  TGETV TGETS TGETB TSETV TSETS TSETB TSETM CALLM CALL  CALLMTCALLT ITERC ITERN VARG  ISNEXTRETM  RET   RET0  RET1  FORI  JFORI FORL  IFORL JFORL ITERL IITERLJITERLLOOP  ILOOP JLOOP JMP   FUNCF IFUNCFJFUNCFFUNCV IFUNCVJFUNCVFUNCC FUNCCW"
	local stringsub, stringfind = string.sub, string.find

	function util.GetOpcodeName(op, version)
		return stringsub(version == 1 and bcnames2_0 or bcnames2_1, op * 6 + 1, op * 6 + 6)
	end

	function util.GetOpcode(inst)
		local s = stringfind(bcnames, inst, 1, true)
		if not s then return false end

		return (s - 1) / 6
	end

	function util.BitflagToString(bitflags, lookup)
		local flags, len = {}, 0

		for flag, str in pairs(lookup) do
			if bit.band(bitflags, flag) ~= 0 then
				len = len + 1
				flags[len] = str
			end
		end

		return table.concat(flags, ", ")
	end

	local BufferM = {}
	BufferM.__index = BufferM

	function util.Buffer(size, cast)
		local buf = setmetatable({
			[1] = size,
			[2] = cast
		}, BufferM)

		local mem = ffi.C.malloc(size)
		assert(mem ~= nil, "Can't allocate memory for the buffer")
		buf[0] = ffi.gc(ffi.cast(cast, mem), function(val) print("BufferGC") ffi.C.free(val) end)

		return buf
	end

	function BufferM:Resize(p, add)
		local hassize = p - self[0] + add

		if hassize <= self[1] then
			print("Bytes left: ", self[1] - hassize)

			return p, self[0]
		end

		ffi.gc(self[0], nil)
		local newbuf = ffi.C.realloc(self[0], hassize)
		assert(newbuf ~= nil, "Can't grow the buffer")
		local offset = p - self[0]
		ffi.gc(self[0], nil)
		self[0] = ffi.gc(ffi.cast(self[2], newbuf), function(val) print("BufferGC") ffi.C.free(val) end)
		print("Realloc. New length: ", hassize, "Was: ", self[1])
		self[1] = hassize

		return self[0] + offset, self[0]
	end

	function BufferM:Size()
		return self[1]
	end

	function BufferM:GetBuffer()
		return self[0]
	end

	function BufferM:Free()
		ffi.C.free(ffi.gc(self[0], nil))
		self[0], self[1], self[2] = nil, nil, nil
	end
end

local IterM = {}
IterM.__index = IterM

function util.ArrayIterator(tbl, i)
	return setmetatable({tbl, i or 0}, IterM)
end

function IterM:__call()
	local value = self[1][self[2]]
	self[2] = self[2] + 1
	self[3] = value
	return value
end

function IterM:Current()
	return self[3]
end
return util