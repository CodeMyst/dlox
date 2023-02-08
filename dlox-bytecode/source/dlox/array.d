module dlox.array;

import dlox.memory;

struct Array(T)
{
    int length;
    int capacity;
    T[] data;

    auto opOpAssign(string op : "~")(const T rhs)
    {
        if (capacity < length + 1)
        {
            int oldCapacity = capacity;
            capacity = growCapacity(capacity);
            data = growArray!T(data, oldCapacity, capacity);
        }

        data[length] = rhs;
        length++;

        return this;
    }

    ref auto opIndex(size_t index)
    {
        return data[index];
    }

    size_t opDollar()
    {
        return length;
    }

    int opApply(scope int delegate(ref T) dg)
    {
        int result = 0;
    
        foreach (item; data[0..length])
        {
            result = dg(item);
            if (result) break;
        }
    
        return result;
    }

    void free()
    {
        freeArray(data, capacity);
        length = length.init;
        capacity = capacity.init;
        data = data.init;
    }
}
