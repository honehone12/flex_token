module garage_token::token_objects_holder {
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_framework::object::{Self, Object};

    const E_TOKEN_ALREADY_EXISTS: u64 = 1;
    const E_TOKEN_NOT_EXISTS: u64 = 2;
    const E_HOLDER_NOT_EXISTS: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_STILL_OWNER: u64 = 5;

    struct TokenObjectsHolder<phantom T: key> has key {
        tokens: vector<Object<T>>
    }

    inline fun new<T: key>(): TokenObjectsHolder<T> {
        TokenObjectsHolder{
            tokens: vector::empty<Object<T>>()
        }
    }

    public fun register<T: key>(account: &signer) {
        let address = signer::address_of(account);
        if (!exists<TokenObjectsHolder<T>>(address)) {
            let holder = new<T>();
            move_to(account, holder);
        }
    }

    public fun num_holds<T: key>(owner: address): u64
    acquires TokenObjectsHolder {
        if (!exists<TokenObjectsHolder<T>>(owner)) {
            0
        } else {
            let holder = borrow_global<TokenObjectsHolder<T>>(owner);
            vector::length(&holder.tokens)    
        }
    }

    public fun holds<T: key>(owner: address, object: Object<T>): bool
    acquires TokenObjectsHolder {
        if (!exists<TokenObjectsHolder<T>>(owner)) {
            return false
        } else {
            let holder = borrow_global<TokenObjectsHolder<T>>(owner);
            vector::contains(&holder.tokens, &object)
        }
    }

    public fun add_to_holder<T: key>(owner: address, object: Object<T>)
    acquires TokenObjectsHolder {
        assert!(
            exists<TokenObjectsHolder<T>>(owner),
            error::not_found(E_HOLDER_NOT_EXISTS)
        );
        assert!(
            object::is_owner(object, owner),
            error::permission_denied(E_NOT_OWNER)
        );

        let holder = borrow_global_mut<TokenObjectsHolder<T>>(owner);
        if (vector::length(&holder.tokens) != 0) {
            assert!(
                !vector::contains(&holder.tokens, &object),
                error::already_exists(E_TOKEN_ALREADY_EXISTS)
            );
        };
        vector::push_back(&mut holder.tokens, object);
    }

    public fun remove_from_holder<T: key>(owner: &signer, object: Object<T>)
    acquires TokenObjectsHolder {
        let addr = signer::address_of(owner);
        assert!(
            exists<TokenObjectsHolder<T>>(addr),
            error::not_found(E_HOLDER_NOT_EXISTS)
        );
        assert!(
            !object::is_owner(object, addr),
            error::permission_denied(E_STILL_OWNER)
        );
        
        let holder = borrow_global_mut<TokenObjectsHolder<T>>(addr);
        if (vector::length(&holder.tokens) == 0) {
            return
        };

        let (ok, idx) = vector::index_of(&holder.tokens, &object);
        assert!(
            ok,
            error::not_found(E_TOKEN_NOT_EXISTS)
        );
        vector::swap_remove(&mut holder.tokens, idx);
    }

    public fun update<T: key>(account: &signer)
    acquires TokenObjectsHolder {
        let addr = signer::address_of(account);
        assert!(
            exists<TokenObjectsHolder<T>>(addr),
            error::not_found(E_HOLDER_NOT_EXISTS)
        );
        
        let holder = borrow_global_mut<TokenObjectsHolder<T>>(addr);
        if (vector::length(&holder.tokens) == 0) {
            return
        };

        let new_vec = vector::empty<Object<T>>();
        let iter = vector::length(&holder.tokens);
        let i = 0;
        while (i < iter) {
            let obj = vector::borrow(&holder.tokens, i);
            if (object::is_owner(*obj, addr)) {
                vector::push_back(&mut new_vec, *obj);
            };
            i = i + 1;
        };
        holder.tokens = new_vec;
    }

    #[test_only]
    struct TestToken has key {
    }

    #[test(account = @123)] 
    fun test_holder(account: &signer)
    acquires TokenObjectsHolder {
        register<TestToken>(account);
        let cctor = object::create_named_object(account, b"testobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref(&cctor);
        let addr = signer::address_of(account);
        assert!(
            num_holds<TestToken>(addr) == 0,
            0
        );
        add_to_holder<TestToken>(addr, obj);
        assert!(
            num_holds<TestToken>(addr) == 1 && holds(addr, obj),
            1
        );
        object::transfer(account, obj, @0x234);
        remove_from_holder<TestToken>(account, obj);
        assert!(
            num_holds<TestToken>(addr) == 0 && !holds(addr, obj),
            2
        );
    }

    #[test(account = @123)] 
    #[expected_failure(
        abort_code = 0x80001,
        location = Self
    )]
    fun test_add_twice(account: &signer)
    acquires TokenObjectsHolder {
        register<TestToken>(account);
        let cctor = object::create_named_object(account, b"testobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref(&cctor);
        let addr = signer::address_of(account);
        add_to_holder<TestToken>(addr, obj);
        add_to_holder<TestToken>(addr, obj);
    }

    #[test(account = @123)] 
    #[expected_failure(
        abort_code = 0x60002,
        location = Self
    )]
    fun test_remove_twice(account: &signer)
    acquires TokenObjectsHolder {
        register<TestToken>(account);
        let addr = signer::address_of(account);
        let cctor = object::create_named_object(account, b"staticobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref(&cctor);
        add_to_holder<TestToken>(addr, obj);
        let cctor = object::create_named_object(account, b"testobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref(&cctor);
        add_to_holder<TestToken>(addr, obj);
        object::transfer(account, obj, @0x234);
        remove_from_holder<TestToken>(account, obj);
        remove_from_holder<TestToken>(account, obj);
    }

    #[test(account = @123)]
    fun test_update(account: &signer)
    acquires TokenObjectsHolder {
        register<TestToken>(account);
        let cctor = object::create_named_object(account, b"testobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref(&cctor);
        let addr = signer::address_of(account);
        add_to_holder<TestToken>(addr, obj);

        object::transfer(account, obj, @234);
        assert!(
            num_holds<TestToken>(addr) == 1,
            0
        );
        assert!(
            object::owner(obj) == @234,
            1
        );
        update<TestToken>(account);
        assert!(
            num_holds<TestToken>(addr) == 0,
            0
        );
    }
}
