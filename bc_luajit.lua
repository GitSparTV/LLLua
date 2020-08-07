local ffi = require("ffi")

local util = require("util")

local BCDUMP_KGC_CHILD, BCDUMP_KGC_TAB, BCDUMP_KGC_I64, BCDUMP_KGC_U64, BCDUMP_KGC_COMPLEX, BCDUMP_KGC_STR = 0, 1, 2, 3, 4, 5

local BCDUMP_KGC = {
	[BCDUMP_KGC_CHILD] = "BCDUMP_KGC_CHILD",
	[BCDUMP_KGC_TAB] = "BCDUMP_KGC_TAB",
	[BCDUMP_KGC_I64] = "BCDUMP_KGC_I64",
	[BCDUMP_KGC_U64] = "BCDUMP_KGC_U64",
	[BCDUMP_KGC_COMPLEX] = "BCDUMP_KGC_COMPLEX",
	[BCDUMP_KGC_STR] = "BCDUMP_KGC_STR",
}

local bc = {}

do
	local bitband, bitrshift, bitbor, bitlshift = bit.band, bit.rshift, bit.bor, bit.lshift

	function bc.ReadULEB(p)
		local i = 0
		local v = p[i]
		i = i + 1

		if v >= 0x80 then
			local sh = 7
			v = v - 0x80
			repeat
				local r = p[i]
				v = v + bitlshift(bitband(r, 0x7f), sh)
				sh = sh + 7
				i = i + 1
			until r < 0x80
		end

		return p + i, v
	end

	function bc.WriteULEB(p, v)
		local i = 0

		while v >= 0x80 do
			p[i] = bitbor(v, 0x80)
			i = i + 1
			v = bitrshift(v, 7)
		end

		p[i] = v

		return p + i + 1
	end

	function bc.ReadULEB33(p)
		local i = 0
		local v = p[i]
		i = i + 1
		v = bitrshift(v, 1)

		if v >= 0x40 then
			local sh = 6
			v = v - 0x40
			repeat
				local r = p[i]
				v = v + bitlshift(bitband(r, 0x7f), sh)
				sh = sh + 7
				i = i + 1
			until r < 0x80
		end

		return p + i, v
	end

	function bc.ReadInstruction(p)
		local C = p[2]
		local B = p[3]
		local D = bit.lshift(B, 8) + C

		return p + 4, p[0], p[1], B, C, D
	end

	function bc.WriteInstruction(p, inst)
		p[0], p[1], p[2], p[3] = inst[1], inst[2], inst[4], inst[3]

		return p + 4
	end

	function convertBin(n)
		local t = {}

		for i = 1, 32 do
			n = bit.rol(n, 1)
			table.insert(t, bit.band(n, 1))
		end

		return table.concat(t)
	end

	function bc.ReadProtoUpvalue(p)
		local uv = p[0] + bit.lshift(p[1], 8)

		return p + 2, bit.band(uv, 0x3FFF), bit.band(uv, 0xc000)
	end

	function bc.WriteProtoUpvalue(p, uv)
		local val = uv[1] + uv[2]
		p[0], p[1] = bit.band(val, 0xFF), bit.band(val, 0xFF00)

		return p + 2
	end

	do
		local BCDUMP_KTAB_NIL, BCDUMP_KTAB_FALSE, BCDUMP_KTAB_TRUE, BCDUMP_KTAB_INT, BCDUMP_KTAB_NUM, BCDUMP_KTAB_STR = 0, 1, 2, 3, 4, 5

		local function ReadGCKV(p)
			local type, value
			p, type = bc.ReadULEB(p)

			if type == BCDUMP_KTAB_NIL then
				value = nil
			elseif type == BCDUMP_KTAB_FALSE then
				value = false
			elseif type == BCDUMP_KTAB_TRUE then
				value = true
			elseif type == BCDUMP_KTAB_INT then
				p, value = bc.ReadULEB(p)
			elseif type == BCDUMP_KTAB_NUM then
				local a, b
				p, a = bc.ReadULEB(p)
				p, b = bc.ReadULEB(p)
				local conv = util.GetNumberConverter()
				conv.i[0], conv.i[1] = a, b
				value = conv.d
			elseif type == BCDUMP_KTAB_STR then
				value = ""
			elseif type > BCDUMP_KTAB_STR then
				value = ffi.string(p, type - 5)
				p = p + (type - 5)
			end

			return p, value
		end

		function bc.ReadProtoGC(p, proto)
			p, gctype = bc.ReadULEB(p)
			local value

			if gctype == BCDUMP_KGC_CHILD then
				local chunk = proto.chunk
				value = chunk.protos[chunk.protoslen - 1]
				proto.childrenlen = proto.childrenlen + 1
				proto.children[proto.childrenlen] = value
				value.parent = proto
			elseif gctype == BCDUMP_KGC_TAB then
				value = {}
				local narray, nhash
				p, narray = bc.ReadULEB(p)
				p, nhash = bc.ReadULEB(p)

				for i = 0, narray - 1 do
					local val
					p, val = ReadGCKV(p)
					value[i] = val
				end

				for i = 0, nhash - 1 do
					local k, v
					p, k = ReadGCKV(p)
					p, v = ReadGCKV(p)
					value[k] = v
				end
			elseif gctype == BCDUMP_KGC_I64 then
				local lo, hi
				p, lo = bc.ReadULEB(p)
				p, hi = bc.ReadULEB(p)
				local conv = util.GetNumberConverter()
				conv.i[0] = lo
				conv.i[1] = hi
				value = conv.ll
			elseif gctype == BCDUMP_KGC_U64 then
				local lo, hi
				p, lo = bc.ReadULEB(p)
				p, hi = bc.ReadULEB(p)
				local conv = util.GetNumberConverter()
				conv.i[0] = lo
				conv.i[1] = hi
				value = conv.ull
			elseif gctype == BCDUMP_KGC_COMPLEX then
				local lo, hi
				p, lo = bc.ReadULEB(p)
				p, hi = bc.ReadULEB(p)
				local conv = util.GetNumberConverter()
				conv.i[0] = lo
				conv.i[1] = hi
				local re = conv.d
				p, lo = bc.ReadULEB(p)
				p, hi = bc.ReadULEB(p)
				conv.i[0] = lo
				conv.i[1] = hi
				value = ffi.typeof("complex")(re, conv.d)
			elseif gctype == BCDUMP_KGC_STR then
				value = ""
			elseif gctype > BCDUMP_KGC_STR then
				value = ffi.string(p, gctype - 5)
				p = p + (gctype - 5)
				gctype = BCDUMP_KGC_STR
			end

			return p, value, gctype
		end

		local function WriteGCKV(p, value)
			local tp = type(value)

			if value == nil then
				p = bc.WriteULEB(p, BCDUMP_KTAB_NIL)
			elseif value == false then
				p = bc.WriteULEB(p, BCDUMP_KTAB_FALSE)
			elseif value == true then
				p = bc.WriteULEB(p, BCDUMP_KTAB_TRUE)
			elseif tp == "number" then
				if math.floor(value) == value then
					p = bc.WriteULEB(p, BCDUMP_KTAB_INT)
					p = bc.WriteULEB(p, value)
				else
					p = bc.WriteULEB(p, BCDUMP_KTAB_NUM)
					local conv = util.GetNumberConverter()
					conv.d = value
					p = bc.WriteULEB(p, conv.i[0])
					p = bc.WriteULEB(p, conv.i[1])
				end
			elseif tp == "string" then
				p = bc.WriteULEB(p, BCDUMP_KTAB_STR + #value)

				if #value ~= 0 then
					ffi.copy(p, value, #value)
					p = p + #value
				end
			end

			return p
		end

		function bc.WriteProtoGC(p, kgc, base)
			local gctype = kgc[2]

			p = bc.WriteULEB(p, gctype == BCDUMP_KGC_STR and BCDUMP_KGC_STR + #kgc[1] or gctype)

			if gctype == BCDUMP_KGC_TAB then
				local value = kgc[1]
				local narray, nhash = table.maxn(value), 0

				if value[0] == nil and narray ~= 0 or value[0] ~= nil then
					narray = narray + 1
				end

				local hashvalues = {}

				for k, v in pairs(value) do
					if type(k) ~= "number" or k > narray then
						hashvalues[nhash * 2] = k
						hashvalues[nhash * 2 + 1] = v
						nhash = nhash + 1
					end
				end

				p = bc.WriteULEB(p, narray)
				p = bc.WriteULEB(p, nhash)

				for i = 0, narray - 1 do
					p = WriteGCKV(p, value[i])
				end

				for k = 0, nhash - 1 do
					p = WriteGCKV(p, hashvalues[k * 2])
					p = WriteGCKV(p, hashvalues[k * 2 + 1])
				end
			elseif gctype == BCDUMP_KGC_I64 then
				local conv = util.GetNumberConverter()
				conv.ll = kgc[1]
				p = bc.WriteULEB(p, conv.i[0])
				p = bc.WriteULEB(p, conv.i[1])
			elseif gctype == BCDUMP_KGC_U64 then
				local conv = util.GetNumberConverter()
				conv.ull = kgc[1]
				p = bc.WriteULEB(p, conv.i[0])
				p = bc.WriteULEB(p, conv.i[1])
			elseif gctype == BCDUMP_KGC_COMPLEX then
				local conv = util.GetNumberConverter()
				local re, im = kgc[1].re, kgc[1].im
				conv.d = re
				p = bc.WriteULEB(p, conv.i[0])
				p = bc.WriteULEB(p, conv.i[1])
				conv.d = im
				p = bc.WriteULEB(p, conv.i[0])
				p = bc.WriteULEB(p, conv.i[1])
			elseif gctype == BCDUMP_KGC_STR then
				local str = kgc[1]
				ffi.copy(p, str, #str)
				p = p + #str
			end

			return p
		end
	end

	function bc.ReadConstNum(p)
		local isdouble = bit.band(p[0], 1)
		local a
		p, a = bc.ReadULEB33(p)

		if isdouble == 1 then
			local b
			p, b = bc.ReadULEB(p)
			local conv = util.GetNumberConverter()
			conv.i[0], conv.i[1] = a, b
			a = conv.d
		end

		return p, a
	end

	function bc.WriteConstNum(p, num)
		local isint = math.floor(num) == num
		local k = ffi.cast("int32_t", num)

		if isint or num == tonumber(k) then
			local uk = ffi.cast("uint32_t", k)
			p = bc.WriteULEB(p, bit.bor(2 * uk, bit.band(uk, 0x80000000)))

			if (k < 0) then
				p[-1] = bit.bor(bit.band(p[-1], 7), bit.band(bit.rshift(k, 27), 0x18))
			end

			return p
		else
			local conv = util.GetNumberConverter()
			conv.d = num
			p = bc.WriteULEB(p, 1 + bit.bor(2 * conv.i[0], bit.band(conv.i[0], 0x80000000ULL)))

			if conv.i[0] >= 0x80000000ULL then
				p[-1] = bit.bor(bit.band(p[-1], 7), bit.band(bit.rshift(conv.i[0], 27), 0x18))
			end

			p = bc.WriteULEB(p, conv.i[1])
		end

		return p
	end

	function bc.ReadDebugLine(p, bytes, isle)
		if bytes == 1 then
			return p + 1, p[0]
		elseif bytes == 2 then
			if isle then
				return p + 2, p[0] + bit.lshift(p[1], 8)
			else
				return p + 2, p[1] + bit.lshift(p[0], 8)
			end
		elseif bytes == 4 then
			if isle then
				return p + 4, p[0] + bit.lshift(p[1], 8) + bit.lshift(p[2], 8 * 2) + bit.lshift(p[3], 8 * 3)
			else
				return p + 4, p[3] + bit.lshift(p[2], 8) + bit.lshift(p[1], 8 * 2) + bit.lshift(p[0], 8 * 3)
			end
		end
	end

	function bc.ReadDebugName(p)
		local len, start = 0, p

		while p[0] ~= 0 do
			p = p + 1
			len = len + 1
		end

		if len == 0 then return p + 1, "" end

		return p + 1, ffi.string(start, len)
	end
end

local BCDUMP_F_BE = 0x01
local BCDUMP_F_STRIP = 0x02
local BCDUMP_F_FFI = 0x04
local BCDUMP_F_FR2 = 0x08
local BCDUMP_F_KNOWN = (BCDUMP_F_FR2 * 2 - 1)

local bcdumpflags = {
	[BCDUMP_F_BE] = "BCDUMP_F_BE",
	[BCDUMP_F_STRIP] = "BCDUMP_F_STRIP",
	[BCDUMP_F_FFI] = "BCDUMP_F_FFI",
	[BCDUMP_F_FR2] = "BCDUMP_F_FR2",
}


local PROTO_CHILD = 0x01 -- Has child prototypes.
local PROTO_VARARG = 0x02 -- Vararg function.
local PROTO_FFI = 0x04 -- Uses BC_KCDATA for FFI datatypes.
local PROTO_NOJIT = 0x08 -- JIT disabled for this function.
local PROTO_ILOOP = 0x10 -- Patched bytecode with ILOOP etc.
local PROTO_HAS_RETURN = 0x20 -- Already emitted a return.
local PROTO_FIXUP_RETURN = 0x40 -- Need to fixup emitted returns.

local protoflags = {
	[PROTO_CHILD] = "PROTO_CHILD",
	[PROTO_VARARG] = "PROTO_VARARG",
	[PROTO_FFI] = "PROTO_FFI",
	[PROTO_NOJIT] = "PROTO_NOJIT",
	[PROTO_ILOOP] = "PROTO_ILOOP",
	[PROTO_HAS_RETURN] = "PROTO_HAS_RETURN",
	[PROTO_FIXUP_RETURN] = "PROTO_FIXUP_RETURN",
}

-- local uv
-- function a()
-- 	local LOCAL = uv + uv
-- 	return
-- end
local ProtoM = {}
ProtoM.__index = ProtoM

function ProtoM:__tostring()
	return string.format("Proto: %p", self)
end

function ProtoM:ReadFromBC(p)
	local flags = p[0]
	local numparams = p[1]
	local framesize = p[2]
	local sizeuv = p[3]
	p = p + 4
	local sizekgc, sizekn, sizebc
	p, sizekgc = bc.ReadULEB(p)
	p, sizekn = bc.ReadULEB(p)
	p, sizebc = bc.ReadULEB(p)
	self.flags, self.numparams, self.framesize, self.sizeuv, self.sizekgc, self.sizekn, self.sizebc = flags, numparams, framesize, sizeuv, sizekgc, sizekn, sizebc
	local sizedbg

	if bit.band(self.chunk.flags, BCDUMP_F_STRIP) then
		p, sizedbg = bc.ReadULEB(p)

		if sizedbg ~= 0 then
			p, self.firstline = bc.ReadULEB(p)
			p, self.numline = bc.ReadULEB(p)
		end
	end

	do
		local insts = self.insts

		for line = 0, sizebc - 1 do
			local op, a, b, c, d
			p, op, a, b, c, d = bc.ReadInstruction(p)

			insts[line] = {op, a, b, c, d}
		end
	end

	do
		local uvs = self.uv

		for uvi = 0, sizeuv - 1 do
			local index, flags
			p, index, flags = bc.ReadProtoUpvalue(p)

			uvs[uvi] = {index, flags}
		end
	end

	do
		local kgcs = self.kgc

		for kgc = 0, sizekgc - 1 do
			local val, type
			p, val, type = bc.ReadProtoGC(p, self)

			kgcs[kgc] = {val, type}
		end
	end

	do
		local kns = self.kn

		for kn = 0, sizekn - 1 do
			local num
			p, num = bc.ReadConstNum(p)

			kns[kn] = num
		end
	end

	if sizedbg ~= 0 then
		local bytenum = self.numline < 256 and 1 or (self.numline < 65536) and 2 or 4
		local isle = bit.band(self.chunk.flags, BCDUMP_F_BE) == 0

		do
			local pp = p

			for line = 0, sizebc - 1 do
				p = bc.ReadDebugLine(p, bytenum, isle)
			end

			self.lineinfo = ffi.string(pp, p - pp)
		end

		do
			local pp = p

			for uvi = 0, sizeuv - 1 do
				p = bc.ReadDebugName(p)
				self.uvinfo = ffi.string(pp, p - pp)
			end
		end

		do
			local pp = p

			while p[0] ~= 0 do
				while p[0] ~= 0 do
					p = p + 1
				end

				p = p + 1
				p, s = bc.ReadULEB(p)
				p, e = bc.ReadULEB(p)
			end
			p = p + 1

			self.varinfo = ffi.string(pp, p - pp)
		end
	end
end

function ProtoM:WriteToBC(buf, p)
	if bit.band(self.flags, PROTO_CHILD) ~= 0 then

		local kgcs = self.kgc
		for kgc = 0, self.sizekgc - 1 do
			local k = kgcs[kgc]
			if k[2] == BCDUMP_KGC_CHILD then
				p, base = k[1]:WriteToBC(buf, p)
			end
		end
	end

	local base
	p, base = buf:Resize(p, 5 + 4 + 5 + 5 + 5 + 5 + 5 + 5)
	local prelen = p
	ffi.fill(prelen, 5)
	p = p + 5
	local postlen = p
	p[0], p[1], p[2], p[3], p = self.flags, self.numparams, self.framesize, self.sizeuv, p + 4
	p = bc.WriteULEB(p, self.sizekgc)
	p = bc.WriteULEB(p, self.sizekn)
	p = bc.WriteULEB(p, self.sizebc)
	local sizedbg = 0

	if bit.band(self.chunk.flags, BCDUMP_F_STRIP) then
		sizedbg = #self.lineinfo + #self.uvinfo + #self.varinfo + 1
		p = bc.WriteULEB(p, sizedbg)

		if sizedbg ~= 0 then
			p = bc.WriteULEB(p, self.firstline)
			p = bc.WriteULEB(p, self.numline)
		end
	end

	do
		local insts = self.insts

		for line = 0, self.sizebc - 1 do
			p = bc.WriteInstruction(p, insts[line])
		end
	end

	do
		local uvs = self.uv

		for uvi = 0, self.sizeuv - 1 do
			p = bc.WriteProtoUpvalue(p, uvs[uvi])
		end
	end

	do
		local kgcs = self.kgc

		for kgc = 0, self.sizekgc - 1 do
			p = bc.WriteProtoGC(p, kgcs[kgc], base)
		end
	end

	do
		local kns = self.kn

		for kn = 0, self.sizekn - 1 do
			p = bc.WriteConstNum(p, kns[kn])
		end
	end

	if sizedbg ~= 0 then
		p, base = buf:Resize(p, sizedbg)
		ffi.copy(p, self.lineinfo, #self.lineinfo)
		p = p + #self.lineinfo
		ffi.copy(p, self.uvinfo, #self.uvinfo)
		p = p + #self.uvinfo
		ffi.copy(p, self.varinfo)
		p = p + #self.varinfo + 1
	end

	bc.WriteULEB(prelen, p - postlen)
	prelen[0] = bit.bor(prelen[0], 0x80)
	prelen[1] = bit.bor(prelen[1], 0x80)
	prelen[2] = bit.bor(prelen[2], 0x80)
	prelen[3] = bit.bor(prelen[3], 0x80)
	prelen[4] = bit.band(prelen[4], bit.bnot(0x80))

	return p, base
end

function Proto(chunk)
	return setmetatable({
		insts = {},
		uv = {},
		kgc = {},
		kn = {},
		firstline = 0,
		numline = 0,
		flags = 0,
		numparams = 0,
		framesize = 0,
		sizeuv = 0,
		sizekgc = 0,
		sizekn = 0,
		sizebc = 0,
		children = {},
		childrenlen = 0,
		chunk = chunk,
		lineinfo = "",
		uvinfo = "",
		varinfo = "",
	}, ProtoM)
end

local ChunkM = {}
ChunkM.__index = ChunkM

function ChunkM:__tostring()
	return string.format("Chunk: %p", self)
end

function ChunkM:ReadFromFile(path, strip)
	local stat, err = loadfile(path)
	if not stat then return stat, err end

	return self:ReadFromBC(string.dump(stat, strip))
end

function ChunkM:ReadFromBC(bcode)
	local p = ffi.new("uint8_t[?]", #bcode + 1, bcode)
	if p[0] ~= 27 or p[1] ~= 76 or p[2] ~= 74 then return false, "Signature mismatch" end
	self.version = p[3]
	p = p + 4
	local flags
	p, flags = bc.ReadULEB(p)
	self.flags = flags
	if bit.band(flags, bit.bnot(BCDUMP_F_KNOWN)) ~= 0 then return false, "Unknown flag (" .. bit.tohex(flags) .. ")" end

	if bit.band(flags, BCDUMP_F_STRIP) == 0 then
		local len
		p, len = bc.ReadULEB(p)
		self.chunkname = ffi.string(p, len)
		p = p + len
	end

	local protos = self.protos
	local pi = 0

	while true do
		local protolen
		p, protolen = bc.ReadULEB(p)
		if protolen == 0 then break end
		local pt = Proto(self)
		pt:ReadFromBC(p)
		protos[pi] = pt
		pi = pi + 1
		self.protoslen = pi
		p = p + protolen
	end

	-- print(self, "\n\tSignature: " .. self.signature, "\n\tVersion: " .. self.version, "\n\tFlags: " .. util.BitflagToString(self.flags, bcdumpflags), "\n\tStripped: " .. (self.strip and "true" or "false"), "\n\tChunkname: " .. self.chunkname, "\n\tProtos: " .. self.protoslen)
	-- for i = pi - 1, 0, -1 do
		-- local proto = protos[i]
		-- print(proto, "\n\tBC: " .. proto.sizebc, "\n\tUVs: " .. proto.sizeuv, "\n\tKGC: " .. proto.sizekgc, "\n\tlua_Number: " .. proto.sizekn, "\n\tParameters: " .. proto.numparams, "\n\tChildren: " .. proto.childrenlen, "\n\tParent: " .. (proto.parent ~= nil and "true" or "false"), "\n\tFlags: " .. util.BitflagToString(proto.flags, protoflags), "\n\tFramesize: " .. proto.framesize)
	-- end
end

function ChunkM:WriteToBC()
	local buf = util.Buffer(1024 + #self.chunkname + 5, "uint8_t*")
	local p = buf:GetBuffer()
	local base = p
	ffi.copy(p, self.signature, #self.signature)
	p = p + 3
	p[0] = self.version
	p = p + 1

	p = bc.WriteULEB(p, self.flags)

	if bit.band(self.flags, BCDUMP_F_STRIP) == 0 then
		p = bc.WriteULEB(p, #self.chunkname)
		ffi.copy(p, self.chunkname, #self.chunkname)
		p = p + #self.chunkname
	end

	p, base = self.protos[self.protoslen - 1]:WriteToBC(buf, p)

	p, base = buf:Resize(p, 1)
	p[0] = 0
	p = p + 1

	return ffi.string(base, p - base)
end

function Chunk()
	return setmetatable({
		signature = "\27LJ",
		version = 2,
		flags = BCDUMP_F_STRIP,
		chunkname = "LLLua",
		protos = {},
		protoslen = 0,
	}, ChunkM)
end

return {Chunk, Proto}