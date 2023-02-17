module dlox.object;

import core.stdc.stdio;
import core.stdc.string;

import dlox.value;
import dlox.memory;
import dlox.vm;

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
    char* heapChars = allocate!char(length + 1).ptr;
    memcpy(heapChars, chars, length);
    heapChars[length] = '\0';

    return allocateString(heapChars, length);
}

ObjString* takeString(char* chars, int length)
{
    return allocateString(chars, length);
}

ObjString* allocateString(char* chars, int length)
{
    ObjString* string = allocateObject!ObjString(ObjType.STRING);
    string.length = length;
    string.chars = chars;
    return string;
}

T* allocateObject(T)(ObjType type)
{
    Obj* object = reallocate!Obj(null, 1, T.sizeof).ptr;
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

