module garage_token::token_objects_holder {
    use std::vector;
    use aptos_framework::object::{Self, Object};

    struct TokenObjectsHolder<phantom T: key> has store {
        tokens: vector<Object<T>>
    }

    public fun new<T: key>(): TokenObjectsHolder<T> {
        TokenObjectsHolder{
            tokens: vector::empty<Object<T>>()
        }
    }

    public fun fetch<T: key>(owner_addr: address, holder: &mut TokenObjectsHolder<T>) {
        let new_vec = vector::empty<Object<T>>();
        let iter = vector::length(&holder.tokens);
        let i = 0;
        while (i < iter) {
            let obj = vector::borrow(&holder.tokens, i);
            if (object::is_owner(*obj, owner_addr)) {
                vector::push_back(&mut new_vec, *obj);
            };
            i = i + 1;
        };
        holder.tokens = new_vec;
    }
}