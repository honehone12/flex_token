// simple idea with move object model.
// the idea is that looks like current distributed NFTs
// but each parts can be replaced.

module flex_token::portrait {
    use std::error;
    use std::signer;
    use std::string::{Self, String, utf8};
    use std::option::{Self, Option};
    use aptos_framework::object::{Self, Object, TransferRef};
    use token_objects::collection::{Self, Collection};
    use token_objects::token::{Self, MutabilityConfig};
    use token_objects_holder::token_objects_holder;

    const E_NO_SUCH_PORTRAIT_BASE: u64 = 1;
    const E_NO_SUCH_PARTS: u64 = 2;
    const E_INVALID_PARTS: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_ALREADY_HOLDS: u64 = 5;
    const E_NOT_ADMIN: u64 = 6;
    const E_TOO_LONG_INPUT: u64 = 7;

    const MAX_NAME: u64 = 64;
    const MAX_DESC: u64 = 128;
    const MAX_URL: u64 = 128;

    struct PortraitOnChainConfig has key {
        portrait_collection_name: String,
        portrait_mutability_config: MutabilityConfig,
        portrait_collection_object: Object<Collection>,
        parts_collection_name: String,
        parts_mutability_config: MutabilityConfig,
        parts_collection_object: Object<Collection>
    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct PortraitBase has key {
        face: Option<Object<Parts<Face>>>,
        hair: Option<Object<Parts<Hair>>>,
        eyes: Option<Object<Parts<Eyes>>>,
        mouth: Option<Object<Parts<Mouth>>>
    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct Parts<phantom P> has key {
        attribute: String,
        transfer_config: TransferRef
    }

    struct Face {}
    struct Hair {}
    struct Eyes {}
    struct Mouth {}

    fun init_module(caller: &signer) {
        let portrait_collection_name = utf8(b"flex-token");
        let parts_collection_name = utf8(b"flex-token-parts-collection");
        let portrait_constructor = collection::create_fixed_collection(
            caller,
            utf8(b"user-customizbale-token"),
            10_000,
            collection::create_mutability_config(false, false),
            portrait_collection_name,
            option::none(),
            utf8(b"token-collection-url")
        );
        let parts_constructor = collection::create_aggregable_collection(
            caller,
            utf8(b"parts-collection-for-user-customizable-token"),
            collection::create_mutability_config(false, false),
            parts_collection_name,
            option::none(),
            utf8(b"parts-collection-url")
        );
        move_to(
            caller,
            PortraitOnChainConfig{
                portrait_collection_name,
                portrait_mutability_config: token::create_mutability_config(
                    false, false, false
                ),
                portrait_collection_object: object::object_from_constructor_ref(
                    &portrait_constructor
                ),
                parts_collection_name,
                parts_mutability_config: token::create_mutability_config(
                    false, false, false
                ),
                parts_collection_object: object::object_from_constructor_ref(
                    &parts_constructor
                )
            }
        );
    }

    inline fun register_all(account: &signer) {
        token_objects_holder::register<PortraitBase>(account);
        token_objects_holder::register<Parts<Face>>(account);
        token_objects_holder::register<Parts<Hair>>(account);
        token_objects_holder::register<Parts<Eyes>>(account);
        token_objects_holder::register<Parts<Mouth>>(account);
    }

    inline fun check_admin(addr: address) {
        assert!(
            addr == @admin, 
            error::permission_denied(E_NOT_ADMIN)
        );
    }

    fun crate_portrait_base(
        creator: &signer,
        description: &String,
        name: &String,
        uri: &String
    ): Object<PortraitBase>
    acquires PortraitOnChainConfig {
        assert!(
            string::length(description) <= MAX_DESC &&
            string::length(name) <= MAX_NAME &&
            string::length(uri) <= MAX_URL,
            error::invalid_argument(E_TOO_LONG_INPUT)
        );

        let creator_addr = signer::address_of(creator);
        check_admin(creator_addr);
        let on_chain_config = borrow_global<PortraitOnChainConfig>(creator_addr);
        let constructor = token::create_token(
            creator,
            on_chain_config.portrait_collection_name,
            *description,
            on_chain_config.portrait_mutability_config,
            *name,
            option::none(),
            *uri
        );
        let token_signer = object::generate_signer(&constructor);
        move_to(
            &token_signer,
            PortraitBase{
                face: option::none(),
                hair: option::none(),
                eyes: option::none(),
                mouth: option::none()
            }
        );
        let obj = object::address_to_object(signer::address_of(&token_signer));
        register_all(creator);
        token_objects_holder::add_to_holder(creator_addr, obj);
        obj
    }

    fun create<P>(
        creator: &signer,
        description: &String,
        name: &String,
        attribute: &String,
        uri: &String
    ): Object<Parts<P>>
    acquires PortraitOnChainConfig {
        assert!(
            string::length(description) <= MAX_DESC &&
            string::length(name) <= MAX_NAME &&
            string::length(attribute) <= MAX_NAME &&
            string::length(uri) <= MAX_URL,
            error::invalid_argument(E_TOO_LONG_INPUT)
        );
        
        let creator_addr = signer::address_of(creator);
        check_admin(creator_addr);
        let on_chain_config = borrow_global<PortraitOnChainConfig>(creator_addr);
        let constructor = token::create_token(
            creator,
            on_chain_config.parts_collection_name,
            *description,
            on_chain_config.parts_mutability_config,
            *name,
            option::none(),
            *uri
        );
        let token_signer = object::generate_signer(&constructor);
        let transfer_config = object::generate_transfer_ref(&constructor);
        object::disable_ungated_transfer(&transfer_config);
        move_to(
            &token_signer,
            Parts<P>{
                attribute: *attribute,
                transfer_config,
            }
        );
        let obj = object::address_to_object<Parts<P>>(signer::address_of(&token_signer));
        register_all(creator);
        token_objects_holder::add_to_holder(creator_addr, obj);
        obj
    }

    inline fun put_on_check<P>(
        owner: &signer,
        base: &Object<PortraitBase>,
        parts: &Object<Parts<P>>
    ) {
        let owner_addr = signer::address_of(owner);
        check_existence(base, parts);
        check_ownership(owner_addr, base, parts);
        check_holding(owner_addr, base, parts);
    }

    inline fun check_existence<P>(base: &Object<PortraitBase>, parts: &Object<Parts<P>>) {
        assert!(
            exists<PortraitBase>(object::object_address(base)),
            error::not_found(E_NO_SUCH_PORTRAIT_BASE)
        );
        assert!(
            exists<Parts<P>>(object::object_address(parts)),
            error::not_found(E_NO_SUCH_PARTS)
        );
    }

    inline fun check_ownership<P>(
        owner_addr: address,
        base: &Object<PortraitBase>, 
        parts: &Object<Parts<P>>
    ) {
        assert!(
            object::is_owner(*base, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            object::is_owner(*parts, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
    }

    inline fun check_holding<P>(
        owner_addr: address,
        base: &Object<PortraitBase>, 
        parts: &Object<Parts<P>>
    ) {
        assert!(
            token_objects_holder::holds(owner_addr, *base),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            token_objects_holder::holds(owner_addr, *parts),
            error::permission_denied(E_NOT_OWNER) 
        );
    }

    fun put_on_hair(
        owner: &signer,
        base_obj: &Object<PortraitBase>,
        parts_obj: &Object<Parts<Hair>>
    )
    acquires PortraitBase, Parts {
        put_on_check<Hair>(owner, base_obj, parts_obj);
        let base = borrow_global_mut<PortraitBase>(object::object_address(base_obj));
        option::fill(&mut base.hair, *parts_obj);
        let parts = borrow_global<Parts<Hair>>(object::object_address(parts_obj));
        object::enable_ungated_transfer(&parts.transfer_config);
        object::transfer_to_object(owner, *parts_obj, *base_obj);
        token_objects_holder::remove_from_holder(owner, *parts_obj);
    }

    fun put_on_face(
        owner: &signer,
        base_obj: &Object<PortraitBase>,
        parts_obj: &Object<Parts<Face>>
    )
    acquires PortraitBase, Parts {
        put_on_check<Face>(owner, base_obj, parts_obj);
        let base = borrow_global_mut<PortraitBase>(object::object_address(base_obj));
        option::fill(&mut base.face, *parts_obj);
        let parts = borrow_global<Parts<Face>>(object::object_address(parts_obj));
        object::enable_ungated_transfer(&parts.transfer_config);
        object::transfer_to_object(owner, *parts_obj, *base_obj);
        token_objects_holder::remove_from_holder(owner, *parts_obj);
    }

    fun put_on_eyes(
        owner: &signer,
        base_obj: &Object<PortraitBase>,
        parts_obj: &Object<Parts<Eyes>>
    )
    acquires PortraitBase, Parts {
        put_on_check<Eyes>(owner, base_obj, parts_obj);
        let base = borrow_global_mut<PortraitBase>(object::object_address(base_obj));
        option::fill(&mut base.eyes, *parts_obj);
        let parts = borrow_global<Parts<Eyes>>(object::object_address(parts_obj));
        object::enable_ungated_transfer(&parts.transfer_config);
        object::transfer_to_object(owner, *parts_obj, *base_obj);
        token_objects_holder::remove_from_holder(owner, *parts_obj);
    }

    fun put_on_mouth(
        owner: &signer,
        base_obj: &Object<PortraitBase>,
        parts_obj: &Object<Parts<Mouth>>
    )
    acquires PortraitBase, Parts {
        put_on_check<Mouth>(owner, base_obj, parts_obj);
        let base = borrow_global_mut<PortraitBase>(object::object_address(base_obj));
        option::fill(&mut base.mouth, *parts_obj);
        let parts = borrow_global<Parts<Mouth>>(object::object_address(parts_obj));
        object::enable_ungated_transfer(&parts.transfer_config);
        object::transfer_to_object(owner, *parts_obj, *base_obj);
        token_objects_holder::remove_from_holder(owner, *parts_obj);
    }

    inline fun verify_base(owner_addr: address, base: &Object<PortraitBase>) {
        assert!(
            exists<PortraitBase>(object::object_address(base)),
            error::not_found(E_NO_SUCH_PORTRAIT_BASE)
        );
        assert!(
            object::is_owner(*base, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            token_objects_holder::holds(owner_addr, *base),
            error::permission_denied(E_NOT_OWNER)
        );
    }

    inline fun verify_stored_parts<P>(
        owner_addr: address,
        stored: &Object<Parts<P>>,
        selected: &Object<Parts<P>>,
        base_addr: address
    ) {
        assert!(
            *stored == *selected,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(*stored, base_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            !token_objects_holder::holds(owner_addr, *selected),
            error::invalid_argument(E_ALREADY_HOLDS)
        );
    }

    fun take_off_hair(
        owner: &signer,
        base_obj: &Object<PortraitBase>,
        parts_obj: &Object<Parts<Hair>>
    )
    acquires PortraitBase, Parts {
        let owner_addr = signer::address_of(owner);
        verify_base(owner_addr, base_obj);
        let base_obj_addr = object::object_address(base_obj);
        let base = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base.hair);
        verify_stored_parts(owner_addr, &stored_parts, parts_obj, base_obj_addr);
        object::transfer(owner, stored_parts, owner_addr);
        token_objects_holder::add_to_holder(owner_addr, stored_parts);
        let parts = borrow_global<Parts<Hair>>(object::object_address(parts_obj));
        object::disable_ungated_transfer(&parts.transfer_config);
    }

    fun take_off_face(
        owner: &signer,
        base_obj: &Object<PortraitBase>,
        parts_obj: &Object<Parts<Face>>
    )
    acquires PortraitBase, Parts {
        let owner_addr = signer::address_of(owner);
        verify_base(owner_addr, base_obj);
        let base_obj_addr = object::object_address(base_obj);
        let base = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base.face);
        verify_stored_parts(owner_addr, &stored_parts, parts_obj, base_obj_addr);
        object::transfer(owner, stored_parts, owner_addr);
        token_objects_holder::add_to_holder(owner_addr, stored_parts);
        let parts = borrow_global<Parts<Face>>(object::object_address(parts_obj));
        object::disable_ungated_transfer(&parts.transfer_config);
    }

    fun take_off_eyes(
        owner: &signer,
        base_obj: &Object<PortraitBase>,
        parts_obj: &Object<Parts<Eyes>>
    )
    acquires PortraitBase, Parts {
        let owner_addr = signer::address_of(owner);
        verify_base(owner_addr, base_obj);
        let base_obj_addr = object::object_address(base_obj);
        let base = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base.eyes);
        verify_stored_parts(owner_addr, &stored_parts, parts_obj, base_obj_addr);
        object::transfer(owner, stored_parts, owner_addr);
        token_objects_holder::add_to_holder(owner_addr, stored_parts);
        let parts = borrow_global<Parts<Eyes>>(object::object_address(parts_obj));
        object::disable_ungated_transfer(&parts.transfer_config);
    }

    fun take_off_mouth(
        owner: &signer,
        base_obj: &Object<PortraitBase>,
        parts_obj: &Object<Parts<Mouth>>
    )
    acquires PortraitBase, Parts {
        let owner_addr = signer::address_of(owner);
        verify_base(owner_addr, base_obj);
        let base_obj_addr = object::object_address(base_obj);
        let base = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base.mouth);
        verify_stored_parts(owner_addr, &stored_parts, parts_obj, base_obj_addr);
        object::transfer(owner, stored_parts, owner_addr);
        token_objects_holder::add_to_holder(owner_addr, stored_parts);
        let parts = borrow_global<Parts<Mouth>>(object::object_address(parts_obj));
        object::disable_ungated_transfer(&parts.transfer_config);
    }

    fun managed_transfer(
        owner: &signer, 
        portrait: &Object<PortraitBase>,
        to: address
    ) {
        let owner_addr = signer::address_of(owner);
        verify_base(owner_addr, portrait);
        object::transfer(owner, *portrait, to);
        token_objects_holder::remove_from_holder(owner, *portrait);
        token_objects_holder::add_to_holder(to, *portrait);
    }

    fun manual_update(account: &signer) {
        token_objects_holder::update<PortraitBase>(account);
        token_objects_holder::update<Parts<Hair>>(account);
        token_objects_holder::update<Parts<Face>>(account);
        token_objects_holder::update<Parts<Eyes>>(account);
        token_objects_holder::update<Parts<Mouth>>(account);
    }

    fun recover(account: &signer, portrait_address: address) {
        token_objects_holder::recover<PortraitBase>(account, portrait_address);
    }

    #[test(account = @admin, other = @0xbeef)]
    fun test_transfer(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = crate_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let hair = create<Hair>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00-00"),
            &utf8(b"hair"),
            &utf8(b"parts-00-url")
        );
        let face = create<Face>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-01-00"),
            &utf8(b"face"),
            &utf8(b"parts-00-url")
        );
        let eyes = create<Eyes>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-02-00"),
            &utf8(b"eyes"),
            &utf8(b"parts-00-url")
        );
        let mouth = create<Mouth>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-03-00"),
            &utf8(b"mouth"),
            &utf8(b"parts-00-url")
        );
        put_on_hair(account, &base, &hair);
        put_on_face(account, &base, &face);
        put_on_eyes(account, &base, &eyes);
        put_on_mouth(account, &base, &mouth);
        let to = signer::address_of(other);
        register_all(other);
        managed_transfer(account, &base, to);
        assert!(object::is_owner(base, to), 0);
        assert!(token_objects_holder::holds(to, base), 1);
        assert!(!token_objects_holder::holds(@admin, base), 2);   
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327683, location = aptos_framework::object)]
    fun test_ungated_transfer_fail_hair(account: &signer, other: address)
    acquires PortraitOnChainConfig {
        init_module(account);
        let hair = create<Hair>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"hair"),
            &utf8(b"parts-00-url")
        );
        object::transfer(account, hair, other);
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327683, location = aptos_framework::object)]
    fun test_ungated_transfer_fail_face(account: &signer, other: address)
    acquires PortraitOnChainConfig {
        init_module(account);
        let face = create<Face>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"face"),
            &utf8(b"parts-00-url")
        );
        object::transfer(account, face, other);
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327683, location = aptos_framework::object)]
    fun test_ungated_transfer_fail_eyes(account: &signer, other: address)
    acquires PortraitOnChainConfig {
        init_module(account);
        let eyes = create<Eyes>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"eyes"),
            &utf8(b"parts-00-url")
        );
        object::transfer(account, eyes, other);
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327683, location = aptos_framework::object)]
    fun test_ungated_transfer_fail_mouth(account: &signer, other: address)
    acquires PortraitOnChainConfig {
        init_module(account);
        let mouth = create<Mouth>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"mouth"),
            &utf8(b"parts-00-url")
        );
        object::transfer(account, mouth, other);
    }

    #[test(account = @admin)]
    fun test_put_on_take_off_hair(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let addr = signer::address_of(account);

        let base = crate_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        assert!(object::is_owner(base, addr), 0);
        assert!(token_objects_holder::holds(addr, base), 4);

        let base_obj_addr = object::object_address(&base);
        let parts = create<Hair>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"hair"),
            &utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts, addr), 1);
        assert!(token_objects_holder::holds(addr, parts), 5);

        put_on_hair(account, &base, &parts);
        assert!(object::is_owner(parts, base_obj_addr), 2);
        assert!(!token_objects_holder::holds(addr, parts), 6);

        take_off_hair(account, &base, &parts);
        assert!(object::is_owner(parts, addr), 3);
        assert!(token_objects_holder::holds(addr, parts), 7);
    }

    #[test(account = @admin)]
    fun test_put_on_take_off_face(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let addr = signer::address_of(account);

        let base = crate_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        assert!(object::is_owner(base, addr), 0);
        assert!(token_objects_holder::holds(addr, base), 4);

        let base_obj_addr = object::object_address(&base);
        let parts = create<Face>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"face"),
            &utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts, addr), 1);
        assert!(token_objects_holder::holds(addr, parts), 5);

        put_on_face(account, &base, &parts);
        assert!(object::is_owner(parts, base_obj_addr), 2);
        assert!(!token_objects_holder::holds(addr, parts), 6);

        take_off_face(account, &base, &parts);
        assert!(object::is_owner(parts, addr), 3);
        assert!(token_objects_holder::holds(addr, parts), 7);
    }

    #[test(account = @admin)]
    fun test_put_on_take_off_eyes(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let addr = signer::address_of(account);

        let base = crate_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        assert!(object::is_owner(base, addr), 0);
        assert!(token_objects_holder::holds(addr, base), 4);

        let base_obj_addr = object::object_address(&base);
        let parts = create<Eyes>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"eyes"),
            &utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts, addr), 1);
        assert!(token_objects_holder::holds(addr, parts), 5);

        put_on_eyes(account, &base, &parts);
        assert!(object::is_owner(parts, base_obj_addr), 2);
        assert!(!token_objects_holder::holds(addr, parts), 6);

        take_off_eyes(account, &base, &parts);
        assert!(object::is_owner(parts, addr), 3);
        assert!(token_objects_holder::holds(addr, parts), 7);
    }

    #[test(account = @admin)]
    fun test_put_on_take_off_mouth(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let addr = signer::address_of(account);

        let base = crate_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        assert!(object::is_owner(base, addr), 0);
        assert!(token_objects_holder::holds(addr, base), 4);

        let base_obj_addr = object::object_address(&base);
        let parts = create<Mouth>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"mouth"),
            &utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts, addr), 1);
        assert!(token_objects_holder::holds(addr, parts), 5);

        put_on_mouth(account, &base, &parts);
        assert!(object::is_owner(parts, base_obj_addr), 2);
        assert!(!token_objects_holder::holds(addr, parts), 6);

        take_off_mouth(account, &base, &parts);
        assert!(object::is_owner(parts, addr), 3);
        assert!(token_objects_holder::holds(addr, parts), 7);
    }
}