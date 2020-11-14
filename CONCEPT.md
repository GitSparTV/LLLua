# LLLua concept
My view to Lua world
-
Lua is a language simple in syntax and powerful in features. However the more experienced you are the more repetitive and long code you have to write, especially when you are trying to optimize it. The optimization problem is much more acute in LuaJIT, but for me (as micro optimization fan), it's a challenge to optimize Lua VM as much possible (and reasonable).

The main reason why I have such question is Lua itself, but it's fair. Lua developers states:
>*We think that the main reasons for this success lie in our original design decisions: keep the language simple and small; keep the implementation simple, small, fast, portable, and free.*
[\[Source\]](https://www.lua.org/history.html)

Lua has lots of derivatives solving different problems and adding new features. What is more interesting Lua had such features as preprocessor, table initial size allocation syntax, metamethods for `_G`, etc.

None of them solves my problems fully or does what I want.

Let's take a look at some interesting ideas in them.

### Lua 1.0
The first version of Lua has following syntax:
```lua
local tbl = @(2) 
```
This was meant to be used for table pre-allocation or initial size. This syntax supported not just a constant number, it can be any expression, as a regular function argument. It can be imagined as a function with a name `@`. Lua didn't have array part at that time, everything was in the hash part.

This syntax was removed in Lua 2.0 with more simplified syntax we still use.
> *The syntax for table construction has been greatly simplied. The old `@(size)` has been substituted by `{}`.*
[\[Source\]](https://www.lua.org/manual/2.1/subsectionstar3_9_1.html#S0910)

### Lua 3.0
The Third version of Lua has preprocessor features.
```lua
$if 1
	print("test")
$else
	print("nottest")
$end
```
- `$debug` -- enable more descriptive errors
- `$nodebug` -- disable them
- `$if cond` -- if condition is `1`, compile next code
- `$ifnot cond` -- if condition is not `1`, compile next code
- `$end` -- ends `$if`
- `$else` -- alternates `$if`
- `$endinput` -- ends chunk reading, works like `$end` for preprocessor.

The preprocessor (called pragma by Lua devs) originally existed only for `$debug` and `$nodebug` marks. They decide how verbode the errors are. Basically, with `$nodebug` (or without calling `$debug`) the error will have no traceback information.

This code
```lua
nilfunction()
```
or this
```lua
$nodebug
nilfunction()
```
will throw error like this:
```
lua: call expression not a function
```
But this code
```lua
$debug
nilfunction()
```
throws this:
```
lua: call expression not a function
        in statement begining at line 2 of file "test.lua"
```

Preprocessor statements used `1` as `true` and everything else as `false` because booleans were introduced only in Lua 5.0.

Important note here they didn't accept expressions (expect the global variable name), the value must be evaluated at compile time.

Preprocessor facilities were removed in Lua 4.0 beta, debug information is now always printed with errors and made more descriptive.
> *Lua programmers will also welcome the improved error messages and the
presence of full debug information without '$debug' (which paid a speed
penalty in 3.2). Lua programs now run at full speed \*and\* errors are now
reported fully (name of variable or field that caused the error, along with line numbers in the stack traceback).*
[\[Source\]](http://lua-users.org/lists/lua-l/2000-09/msg00068.html)

### Lua 5.4
Lua 5.4 introduced constant values.
```lua
local a <const> = true
```
Constant values throw compile-time error when the value is modified.

Since the check is happening at compilation, `<const>` can't be set on globals (the same for `<close>` variables).

### MetaLua

MetaLua is Lua 5.1 extended with metaprogramming on high-level.

It allows you to modify and modify lexical grammar and parsing stage.

MetaLua allows to add operators, macros, definitions, auto-documentation, code analysis, etc.

Here is the example of C-like ternary operator made with MetaLua.
```lua
-{ mlp.expr.add_postfix_sequence { "?", mlp.expr, ",", mlp.expr,  
functor = |x| +{ function(x) if -{x[1]} then return -{x[2]} else return -{x[3]} end end () } } }  
  
-- test it:  
lang = "en"; print((lang=="fr") ? "Bonjour", "Hello")  
lang = "fr"; print((lang=="fr") ? "Bonjour", "Hello")  
```
[\[Source\]](http://lua-users.org/lists/lua-l/2006-11/msg00212.html)
MetaLua uses its own syntax `+{}` and `-{}`, language additions are transparent in the code (requires no additional definition).

### Typed Lua

Typed Lua is project that adds static typing compile-time checks into Lua, it compiles to normal Lua. Works inside Lua, requires to run its version of `loadfile`.

Example of record typing:
```lua
local interface Person
	firstname:string
	lastname:string
end

local function byebye (person:Person)
return "Goodbye " .. person.firstname .. " " .. person.lastname
end

local user1 = { firstname = "Lou" }
local user2 = { lastname = "Reed", firstname = "Lou" }

print(byebye(user1)) -- compile-time error
print(byebye(user2)) -- Goodbye, Lou Reed
```
[\[Source\]](https://www.lua.org/wshop14/Murbach.pdf)

#### Similar to Typed Lua projects:
- [Ravi](https://ravilang.github.io/) (Compiles to LLVM, JITs the code, has [the same or even better performance](http://www.lua.org/wshop15/Majumdar.pdf), but also can be slower)
- [Sol](https://github.com/emilk/sol) ("*Sol is to Lua as Typescript is to JS.*", static type checker)
- [Teal (tl)](https://github.com/teal-language/tl) (Lua dialect, compiles into lua module with type check facilities)
- [Pallene/Titan](https://github.com/pallene-lang/pallene) (AOT compiler. Compiles in C, uses Lua internals, requires to load pallene core into lua, uses Lua GC)

What do I want
-
None of these projects meet my requirements, the closest project is a Lua-flavored Lua-metaprogramming language that compiles to C ([Nelua](https://nelua.io/)), it has lots of good features, but it doesn't compile to Lua.

MetaLua introduces foreign syntax, which is in my opinion a bad decision. Good thing it compiled into bytecode (Unlike Moonscript).

Typed Lua and all similar projects can't decide how to deal with all variety and dynamics of Lua, so to type a value that can be a table of something or a number results some weird unreadable syntax.

The problem with Lua 5.4 `<const>` values they work only for locals.

Lua 5.3 removed all preprocessor features to because they were introduced just because `$debug` existed, collecting debug information become cheaper and thus was left visible forever.

Lua 1.0, as a first version, didn't know where to go, table allocation feature was gone to make the language simpler with adding `{}` instead of `@{}` and `@[]`, `@(n)` feature was not added back. 

LLLua
-
My first attempt to do alternative Lua coding was LLLua (Low Level Lua). It's a language (or transpiler) that writes into Lua bytecode where the .lllua script consists only of raw bytecode instructions. LLLua is to Lua as assembly is to C.
```lua
KSHORT 0, 40
KSHORT 1, 60
ADDVV 0, 0, 1
RET1 0, 2
```
This .lllua script is equivalent to this .lua script:
```lua
local a = 40
do
	local b = 60
	a = a + b
end
return a
```
One of the first features was C-like chars that replaced single quotes string literals syntax (`'a'` will be an ascii byte).

After first demo I was thinking how to implement other features like GC consts, upvalues, etc. This forced me to made a proper way to implement them, but at the end the idea died as it would be longer to write all of this.

New Language Idea
- 
So I want to make a new language, probably with the same name, since it will compile to bytecode as well. (with a possible option to transpile to lua as well, of course, with more limited features)

Here is the list of features I set to accomplish now.

### Main Rule
Lua is simple language with its own history. I want to preserve the simplicity and the similar syntax. I will learn and research the history of Lua and the language Lua was influenced by.

### 1. Static types
Static typing is a great feature, it might be not friendly for beginners, but for API developers, library developers this frees the code from runtime type checks to compile-time. Static typing should be easy to make for developers and users.
```lua
function factorial(n: number): number
	if n == 0 then
		return 1
	else
		return n * factorial(n - 1)
	end
end
```

### 2. Metaprogrammed Lua with Lua
> MetaLua introduces foreign syntax, which is in my opinion a bad decision.

The best way to make metaprogramming easier is make meta language as Lua as well.

Syntax is taken from Nelua.
```lua
##[[
local function GenerateRandomString()
	local t = {}
	for i = 1, 10 do
		t[i] = string.char(math.random(33, 126))
	end
	return table.concat(t)
end 
]]

print(#[GenerateRandomString()]) -- kbXg(_@fIV
```

### 3. Preprocessor
Since LLLua is mostly an advanced compiler preprocessor is one of my top goal. Most common debug function in Lua is `print`, but leaving them everywhere is not great, so usually when I'm done with debugging I remove all of them, but what if a new bug appeared. Placing them again? What if we can enable something similar to `$debug` here?

Syntax is taken from Lua 3.0.
```lua
$debug
$if debug then
	$define debug_assert(expr, errmsg) $assert(expr, errmsg)
$else
	$define debug_assert()
$end

function CanAccess(user)
	debug_assert(type(user) == "string")
	$print(user)
	
	local res = SomeCAPI(user)
	$print(res)
	
	return res
end
$nodebug
```

At the production time the script will look like this:
```lua
function CanAccess(user)
	local res = SomeCAPI(user)
	return res
end
```
With `$debug` enabled:
```lua
function CanAccess(user)
	assert(type(user) == "string")
	print(user)
	local res = SomeCAPI(user)
	print(res)
	return res
end
```

With static typing LLLua should know about all types and functions available, preprocessor offers C-like headers include:

```lua
$include("gmod.lllua")
```

### 4. Enumerations
Garry's Mod has ridiculous amount of enums, but all are required for the developers, but 99.9% of them are not stored in tables, they are all global like `_G.ENUM_1 = 1 _G.ENUM_2 = 2 _G.ENUM_3 = 3`.

Not only this affects _G iteration and hashing little bit, but also forces you to do global indexing. (ok, with 1 enum you are probably fine, but imagine 10 of them in a loop).

Enumerations would make it easier and faster.

Syntax is taken from Nelua.
```lua
TEXT_ALIGN = @enum({
	LEFT = 0,
	CENTER,
	RIGHT,
	TOP,
	BOTTOM,
}, "_")
```
First enum defaults to 1, to make it 0, assign explicitly.  

Garry's Mod uses these enums in text drawing function in `xAlign`, `yAlign`.

`draw.SimpleText(text, font, x, y, color, xAlign, yAlign)`

To statically type this function we can use enum now.
```lua
function draw.SimpleText(text: string, font: string, x: number, y: number, color: Color, xAlign: TEXT_ALIGN, yAlign: TEXT_ALIGN)

draw.SimpleText("Hello", "DermaDefault", 100, 100, color_white, LEFT, TEXT_ALIGN_CENTER) -- works as global enum ans local.
```

Similar thing when enums would be better is LOVE2D. LOVE2D follows Lua "enums" style: string commands. (Like in f:seek())

```lua
local StencilAction: string = @enum({
	equal,
	notequal,
	less,
	lequal,
	gequal,
	greater,
	never,
	always,
})

love.graphics.stencil( stencilfunction, action: StencilAction, value, keepvalues )
```

### 5. Inline ~~assembly~~ bytecode
Bringing LLLua first prototype idea, I want to add inline bytecode sub-language. Syntax will use LuaJIT DynASM `|` pipe.
```lua
function CheckTable(tbl)
	|	ISTYPE 0, 12 -- Checks if tbl type is table
end
```

### 6. Attributes
LuaJIT bytecode offers some hidden features that can be used in LLLua.

Also with static typing we can allow comptime `<const>` variables (even globals).

Syntax will use Lua 5.4 angles brackets (`<>`)
```lua
function IterateSomething(tbl: table) <nojit>
	local mul: number <const> = GetMul()
	for k,v in pairs(tbl) do
		tbl[k] = v * mul
	end
end
```

### 7. Compile time optimizations
This is the most debatable section for me because I don't know much about LuaJIT optimizations, how optimizing bytecode will affect its own JIT compilation, will it break LuaJIT, what worth doing and what not.

But when I do a research in this field I will decide what can be really implemented.

Current ideas:
- Inlining/anti-inlining
- Folding
- Comptime precalculation
- Manual select for ret var
- Replacing built-in function into bytecode (like select)

### 8. Classes/objects
Classes will give a control over the use of internal and public parts of the object for the developers, providing save interface

This is influenced from C++.
```lua
Panel = @class({
	private:
		x: number,
		y: number,
		w: number,
		h: number
})

function Panel:GetWidth():number <inline>
	return self.w
end
```

### 9. Compile time defaults
Garry's Mod has a `draw` library which is a beginner-friendly library making drawing text and shapes. However it's full of runtime default check statements.

Example:
```lua
function SimpleText( text, font, x, y, colour, xalign, yalign )
text = tostring( text )
font = font or "DermaDefault"
x = x or 0
y = y or 0
xalign = xalign or TEXT_ALIGN_LEFT
yalign = yalign or TEXT_ALIGN_TOP
```
They should be checked at compile time.
```lua
function SimpleText( text: any, font: string or "DermaDefault", x: number or 0, y: number = 0, colour: Color, xalign: TEXT_ALIGN or LEFT, yalign: TEXT_ALIGN or TOP)
##if text.type ~= "string" then 
text = tostring(text)
##end
```

#### 10. Compile time overloads/templates
Sometimes one function does job for several types, instead of using runtime checks a function can be split into templates.
```lua
function IsValid(val: any) <inline>
	## if val.type == "table" then
		return val:IsValid()
	## else
		return val and val:IsValid()
	## end
end
```
This produces 2 function `IsValid_any` and `IsValid_table`.

Why?
-
My idea is to make an advanced compiler for Lua that helps write optimized code faster, less handwritten boilerplates, less function calls, less debug/checks. Bringing the control over the use of functions, fields and API. LLLua also might help learn static typing for people who learned Lua and wanted to move to other languages.

Who will use it?
-
The project is aimed for people is wants to code in Lua differently, probably tired of coding in regular Lua.

As a future idea, LLLua can be embedded as regular compiler for Lua.

LLLua is definitely not a project you force everyone to use because it's a detached compiler, to use in regular lua project will require you to make .lllua headers for its API if you want static typing. Making the whole project with LLLua would be better but not every framework supports bytecode loading (which is why I have a future idea to make it generate regular Lua with limited features).

Can that idea fail?

Yes, I'm not an expert in anything outside Lua, just programming in it as a hobby. I'm sure the stuff I mention above is a subject to change as soon I learn something after posting this article.

Is it possible that only me will use this language?

Yes, and I'm fine with it.

---
Spar
