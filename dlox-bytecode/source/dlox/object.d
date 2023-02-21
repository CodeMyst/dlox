module dlox.object;

import core.stdc.stdio;
import core.stdc.string;

import dlox.value;
import dlox.memory;
import dlox.vm;
import dlox.table;

enum ObjType
{
    STRING
}

struct Obj
{
    ObjType type;
    Obj* next = null;
}

struct ObjString
{
    Obj obj;
    alias obj this;

    int length;
    char* chars;
    uint hash;
}

ObjType objType(Value value)
{
    return asObj(value).type;
}

bool isObjType(Value value, ObjType type)
{
    return isObj(value) && objType(value) == type;
}

bool isString(Value value)
{
    return isObjType(value, ObjType.STRING);
}

ObjString* asString(Value value)
{
    return cast(ObjString*) asObj(value);
}

char* asStringz(Value value)
{
    return asString(value).chars;
}

ObjString* copyString(const char* chars, int length)
{
    uint hash = hashString(chars, length);
    ObjString* interned = vm.strings.findString(chars, length, hash);
    if (interned !is null) return interned;
    char* heapChars = allocate!char(length + 1);
    memcpy(heapChars, chars, length);
    heapChars[length] = '\0';

    return allocateString(heapChars, length, hash);
}

ObjString* takeString(char* chars, int length)
{
    uint hash = hashString(chars, length);
    ObjString* interned = vm.strings.findString(chars, length, hash);

    if (interned !is null)
    {
        freeArray!char(chars, length + 1);
        return interned;
    }

    return allocateString(chars, length, hash);
}

ObjString* allocateString(char* chars, int length, uint hash)
{
    ObjString* string = allocateObject!ObjString(ObjType.STRING);
    string.length = length;
    string.chars = chars;
    string.hash = hash;
    vm.strings.set(string, Value(null));
    return string;
}

uint hashString(const char* key, int length)
{
    uint hash = 2_166_136_261u;

    for (int i = 0; i < length; i++)
    {
        hash ^= cast(uint) key[i];
        hash *= 16_777_619;
    }

    return hash;
}

T* allocateObject(T)(ObjType type)
{
    Obj* object = reallocate!Obj(null, 0, T.sizeof);
    object.type = type;

    object.next = vm.objects;
    vm.objects = object;

    return cast(T*) object;
}

void printObject(Value value)
{
    switch(objType(value))
    {
        case ObjType.STRING:
            printf("%s", asStringz(value));
            break;

        default: assert(0);
    }
}

