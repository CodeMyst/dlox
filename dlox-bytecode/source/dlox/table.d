module dlox.table;

import dlox.value;
import dlox.object;
import dlox.memory;

enum TABLE_MAX_LOAD = 0.75;

struct Table
{
    int count;
    int capacity;
    Entry* entries;

    void free()
    {
        freeArray!Entry(entries, capacity);
        count = 0;
        capacity = 0;
        entries = null;
    }

    bool set(ObjString* key, Value value)
    {
        if (count + 1 > capacity * TABLE_MAX_LOAD)
        {
            int newCapacity = growCapacity(capacity);
            adjustCapacity(&this, newCapacity);
        }

        Entry* entry = findEntry(entries, capacity, key);
        bool isNewKey = entry.key is null;
        if (isNewKey && isNil(entry.value)) count++;

        entry.key = key;
        entry.value = value;

        return isNewKey;
    }

    bool get(ObjString* key, Value* value)
    {
        if (count == 0) return false;

        Entry* entry = findEntry(entries, capacity, key);
        if (entry.key is null) return false;

        *value = entry.value;
        return true;
    }

    ObjString* findString(const char* chars, int length, uint hash)
    {
        import core.stdc.string : memcmp;

        if (count == 0) return null;

        uint index = hash % capacity;
        while (true)
        {
            Entry* entry = &entries[index];
            if (entry.key is null)
            {
                if (isNil(entry.value)) return null;
            }
            else if (entry.key.length == length &&
                     entry.key.hash == hash &&
                     memcmp(entry.key.chars, chars, length) == 0)
            {
                return entry.key;
            }

            index = (index + 1) % capacity;
        }
    }

    bool remove(ObjString* key)
    {
        if (count == 0) return false;

        Entry* entry = findEntry(entries, capacity, key);
        if (entry.key is null) return false;

        entry.key = null;
        entry.value = Value(true);

        return true;
    }
}

Entry* findEntry(Entry* entries, int capacity, ObjString* key)
{
    uint index = key.hash % capacity;
    Entry* tombstone = null;
    while (true)
    {
        Entry* entry = &entries[index];
        if (entry.key is null)
        {
            if (isNil(entry.value))
            {
                return tombstone !is null ? tombstone : entry;
            }
            else
            {
                if (tombstone is null) tombstone = entry;
            }
        }
        else if (entry.key == key)
        {
            return entry;
        }

        index = (index + 1) % capacity;
    }
}

void adjustCapacity(Table* table, int capacity)
{
    Entry* entries = allocate!Entry(capacity);
    for (int i = 0; i < capacity; i++)
    {
        entries[i].key = null;
        entries[i].value = Value(null);
    }

    for (int i = 0; i < table.capacity; i++)
    {
        Entry* entry = &table.entries[i];
        if (entry.key is null) continue;

        Entry* dest = findEntry(entries, capacity, entry.key);
        dest.key = entry.key;
        dest.value = entry.value;
        table.count++;
    }

    freeArray!Entry(table.entries, table.capacity);
    table.entries = entries;
    table.capacity = capacity;
}

void tableAddAll(Table* from, Table* to)
{
    for (int i = 0; i < from.capacity; i++)
    {
        Entry* entry = &from.entries[i];
        if (entry.key !is null)
        {
            to.set(entry.key, entry.value);
        }
    }
}

struct Entry
{
    ObjString* key;
    Value value;
}
