// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Modified by Bucket Protocol
// Similar to `sui::linked_table` but allowing insert element in the middle
module bucket_framework::linked_table {
    use std::option::{Self, Option};
    use sui::object::{Self, UID};
    use sui::dynamic_field as field;
    use sui::tx_context::TxContext;

    // Attempted to destroy a non-empty table
    const ETableNotEmpty: u64 = 0;
    // Attempted to remove the front or back of an empty table
    const ETableIsEmpty: u64 = 1;

    struct LinkedTable<K: copy + drop + store, phantom V: store> has key, store {
        /// the ID of this table
        id: UID,
        /// the number of key-value pairs in the table
        size: u64,
        /// the front of the table, i.e. the key of the first entry
        head: Option<K>,
        /// the back of the table, i.e. the key of the last entry
        tail: Option<K>,
    }

    struct Node<K: copy + drop + store, V: store> has store {
        /// the previous key
        prev: Option<K>,
        /// the next key
        next: Option<K>,
        /// the value being stored
        value: V
    }

    /// Creates a new, empty table
    public fun new<K: copy + drop + store, V: store>(ctx: &mut TxContext): LinkedTable<K, V> {
        LinkedTable {
            id: object::new(ctx),
            size: 0,
            head: option::none(),
            tail: option::none(),
        }
    }

    /// Returns the key for the first element in the table, or None if the table is empty
    public fun front<K: copy + drop + store, V: store>(table: &LinkedTable<K, V>): &Option<K> {
        &table.head
    }

    /// Returns the key for the last element in the table, or None if the table is empty
    public fun back<K: copy + drop + store, V: store>(table: &LinkedTable<K, V>): &Option<K> {
        &table.tail
    }

    /// Inserts a key-value pair at the front of the table, i.e. the newly inserted pair will be
    /// the first element in the table
    /// Aborts with `sui::dynamic_field::EFieldAlreadyExists` if the table already has an entry with
    /// that key `k: K`.
    public fun push_front<K: copy + drop + store, V: store>(
        table: &mut LinkedTable<K, V>,
        k: K,
        value: V,
    ) {
        let old_head = option::swap_or_fill(&mut table.head, k);
        if (option::is_none(&table.tail)) option::fill(&mut table.tail, k);
        let prev = option::none();
        let next = if (option::is_some(&old_head)) {
            let old_head_k = option::destroy_some(old_head);
            field::borrow_mut<K, Node<K, V>>(&mut table.id, old_head_k).prev = option::some(k);
            option::some(old_head_k)
        } else {
            option::none()
        };
        field::add(&mut table.id, k, Node { prev, next, value });
        table.size = table.size + 1;
    }

    /// Inserts a key-value pair at the back of the table, i.e. the newly inserted pair will be
    /// the last element in the table
    /// Aborts with `sui::dynamic_field::EFieldAlreadyExists` if the table already has an entry with
    /// that key `k: K`.
    public fun push_back<K: copy + drop + store, V: store>(
        table: &mut LinkedTable<K, V>,
        k: K,
        value: V,
    ) {
        if (option::is_none(&table.head)) option::fill(&mut table.head, k);
        let old_tail = option::swap_or_fill(&mut table.tail, k);
        let prev = if (option::is_some(&old_tail)) {
            let old_tail_k = option::destroy_some(old_tail);
            field::borrow_mut<K, Node<K, V>>(&mut table.id, old_tail_k).next = option::some(k);
            option::some(old_tail_k)
        } else {
            option::none()
        };
        let next = option::none();
        field::add(&mut table.id, k, Node { prev, next, value });
        table.size = table.size + 1;
    }

    /// Immutable borrows the value associated with the key in the table `table: &LinkedTable<K, V>`.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the table does not have an entry with
    /// that key `k: K`.
    public fun borrow<K: copy + drop + store, V: store>(table: &LinkedTable<K, V>, k: K): &V {
        &field::borrow<K, Node<K, V>>(&table.id, k).value
    }

    /// Mutably borrows the value associated with the key in the table `table: &mut LinkedTable<K, V>`.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the table does not have an entry with
    /// that key `k: K`.
    public fun borrow_mut<K: copy + drop + store, V: store>(
        table: &mut LinkedTable<K, V>,
        k: K,
    ): &mut V {
        &mut field::borrow_mut<K, Node<K, V>>(&mut table.id, k).value
    }

    /// Borrows the key for the previous entry of the specified key `k: K` in the table
    /// `table: &LinkedTable<K, V>`. Returns None if the entry does not have a predecessor.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the table does not have an entry with
    /// that key `k: K`
    public fun prev<K: copy + drop + store, V: store>(table: &LinkedTable<K, V>, k: K): &Option<K> {
        &field::borrow<K, Node<K, V>>(&table.id, k).prev
    }

    /// Borrows the key for the next entry of the specified key `k: K` in the table
    /// `table: &LinkedTable<K, V>`. Returns None if the entry does not have a predecessor.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the table does not have an entry with
    /// that key `k: K`
    public fun next<K: copy + drop + store, V: store>(table: &LinkedTable<K, V>, k: K): &Option<K> {
        &field::borrow<K, Node<K, V>>(&table.id, k).next
    }

    /// Removes the key-value pair in the table `table: &mut LinkedTable<K, V>` and returns the value.
    /// This splices the element out of the ordering.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the table does not have an entry with
    /// that key `k: K`. Note: this is also what happens when the table is empty.
    public fun remove<K: copy + drop + store, V: store>(table: &mut LinkedTable<K, V>, k: K): V {
        let Node<K, V> { prev, next, value } = field::remove(&mut table.id, k);
        table.size = table.size - 1;
        if (option::is_some(&prev)) {
            field::borrow_mut<K, Node<K, V>>(&mut table.id, *option::borrow(&prev)).next = next
        };
        if (option::is_some(&next)) {
            field::borrow_mut<K, Node<K, V>>(&mut table.id, *option::borrow(&next)).prev = prev
        };
        if (option::borrow(&table.head) == &k) table.head = next;
        if (option::borrow(&table.tail) == &k) table.tail = prev;
        value
    }

    /// Removes the front of the table `table: &mut LinkedTable<K, V>` and returns the value.
    /// Aborts with `ETableIsEmpty` if the table is empty
    public fun pop_front<K: copy + drop + store, V: store>(table: &mut LinkedTable<K, V>): (K, V) {
        assert!(option::is_some(&table.head), ETableIsEmpty);
        let head = *option::borrow(&table.head);
        (head, remove(table, head))
    }

    /// Removes the back of the table `table: &mut LinkedTable<K, V>` and returns the value.
    /// Aborts with `ETableIsEmpty` if the table is empty
    public fun pop_back<K: copy + drop + store, V: store>(table: &mut LinkedTable<K, V>): (K, V) {
        assert!(option::is_some(&table.tail), ETableIsEmpty);
        let tail = *option::borrow(&table.tail);
        (tail, remove(table, tail))
    }

    /// Returns true iff there is a value associated with the key `k: K` in table
    /// `table: &LinkedTable<K, V>`
    public fun contains<K: copy + drop + store, V: store>(table: &LinkedTable<K, V>, k: K): bool {
        field::exists_with_type<K, Node<K, V>>(&table.id, k)
    }

    /// Returns the size of the table, the number of key-value pairs
    public fun length<K: copy + drop + store, V: store>(table: &LinkedTable<K, V>): u64 {
        table.size
    }

    /// Returns true iff the table is empty (if `length` returns `0`)
    public fun is_empty<K: copy + drop + store, V: store>(table: &LinkedTable<K, V>): bool {
        table.size == 0
    }

    /// Destroys an empty table
    /// Aborts with `ETableNotEmpty` if the table still contains values
    public fun destroy_empty<K: copy + drop + store, V: store>(table: LinkedTable<K, V>) {
        let LinkedTable { id, size, head: _, tail: _ } = table;
        assert!(size == 0, ETableNotEmpty);
        object::delete(id)
    }

    /// Drop a possibly non-empty table.
    /// Usable only if the value type `V` has the `drop` ability
    public fun drop<K: copy + drop + store, V: drop + store>(table: LinkedTable<K, V>) {
        let LinkedTable { id, size: _, head: _, tail: _ } = table;
        object::delete(id)
    }

    /// Insert a key-value pair in front of the given key
    /// If the given key is none, then set the key-value pair as back
    public fun insert_front<K: copy + drop + store, V: store>(table: &mut LinkedTable<K, V>, next_k: Option<K>, k: K, value: V) {
        if (option::is_none(&next_k)) {
            push_back(table, k, value);
        } else {
            let next_k = option::destroy_some(next_k);
            let prev_k = *prev(table, next_k);
            if (option::is_none(&prev_k)) {
                push_front(table, k, value);
            } else {
                let prev_k = option::destroy_some(prev_k);
                field::borrow_mut<K, Node<K, V>>(&mut table.id, next_k).prev = option::some(k);
                field::borrow_mut<K, Node<K, V>>(&mut table.id, prev_k).next = option::some(k);
                let prev = option::some(prev_k);
                let next = option::some(next_k);
                field::add(&mut table.id, k, Node { prev, next, value });
                table.size = table.size + 1;
            }
        }
    }

    /// Insert a key-value pair behind the given key
    /// If the given key is none, then set the key-value pair as front
    public fun insert_back<K: copy + drop + store, V: store>(table: &mut LinkedTable<K, V>, prev_k: Option<K>, k: K, value: V) {
        if (option::is_none(&prev_k)) {
            push_front(table, k, value);
        } else {
            let prev_k = option::destroy_some(prev_k);
            let next_k = *next(table, prev_k);
            if (option::is_none(&next_k)) {
                push_back(table, k, value);
            } else {
                let next_k = option::destroy_some(next_k);
                field::borrow_mut<K, Node<K, V>>(&mut table.id, next_k).prev = option::some(k);
                field::borrow_mut<K, Node<K, V>>(&mut table.id, prev_k).next = option::some(k);
                let prev = option::some(prev_k);
                let next = option::some(next_k);
                field::add(&mut table.id, k, Node { prev, next, value });
                table.size = table.size + 1;
            };
        };
    }

    #[test]
    fun test_insert_linked_table(): LinkedTable<address,u64> {
        use sui::test_scenario;
        use sui::test_utils;
        use std::debug;

        let dev = @0xde1;
        let scenario_val = test_scenario::begin(dev);
        let scenario = &mut scenario_val;

        let table = new<address, u64>(test_scenario::ctx(scenario));
        insert_back(&mut table, option::none(), @0x1, 111);
        insert_back(&mut table, option::some(@0x1), @0x3, 333);
        insert_front(&mut table, option::some(@0x3), @0x2, 222);
        insert_back(&mut table, option::some(@0x3), @0x5, 555);
        insert_front(&mut table, option::some(@0x5), @0x4, 444);

        let curr_k = *front(&table);
        while(option::is_some(&curr_k)) {
            let key = option::borrow(&curr_k);
            debug::print(&curr_k);
            debug::print(borrow(&table, *key));
            curr_k = *next(&table, *key);
        };

        test_utils::assert_ref_eq(front(&table), &option::some(@0x1));
        test_utils::assert_ref_eq(next(&table,@0x1), &option::some(@0x2));
        test_utils::assert_ref_eq(next(&table,@0x2), &option::some(@0x3));
        test_utils::assert_ref_eq(next(&table,@0x3), &option::some(@0x4));
        test_utils::assert_ref_eq(next(&table,@0x4), &option::some(@0x5));
        test_utils::assert_ref_eq(back(&table), &option::some(@0x5));

        test_scenario::end(scenario_val);
        table
    }
}

