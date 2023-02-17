module dlox.memory;

import core.stdc.stdlib;

import dlox.object;
import dlox.vm;

int growCapacity(int capacity)
{
    return capacity < 8 ? 8 : capacity * 2;
}

T[] growArray(T)(T[] arr, int oldCount, int newCount)
{
    return reallocate!T(arr, T.sizeof * oldCount, T.sizeof * newCount);
}

void freeArray(T)(T[] arr, int oldCount)
{
    reallocate(arr, T.sizeof * oldCount, 0);
}

T[] reallocate(T)(T[] arr, size_t oldSize, size_t newSize)
{
    // TODO: maybe try and implement this without malloc and free :)

    if (newSize == 0)
    {
        free(arr.ptr);
        return null;
    }

    void* res = realloc(arr.ptr, newSize);
    if (res is null) exit(137);

    return cast(T[]) res[0..newSize];
}

T[] allocate(T)(size_t count)
{
    return reallocate!T(null, 0, T.sizeof * count);
}

void freeObjects()
{
    Obj* object = vm.objects;
    while (object !is null)
    {
        Obj* next = object.next;
        freeObject(object);
        object = next;
    }
}

void freeObject(Obj* object)
{
    switch (object.type)
    {
        case ObjType.STRING: {
            ObjString* string = cast(ObjString*) object;
            freeArray!char(string.chars[0..string.length], string.length + 1);
            reallocate!ObjString(string[0..ObjString.sizeof - 1], ObjString.sizeof, 0);
        } break;

        default: assert(0);
    }
}

