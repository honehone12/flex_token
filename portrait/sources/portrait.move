// simple idea with move object model.
// the idea is that looks like current distributed NFTs
// but each parts can be replaced.

module flex_token::portrait {
    use std::error;
    use std::signer;
    use std::string::{String, utf8};
    use std::option::{Self, Option};
    use aptos_framework::object::{Self, Object};
    use token_objects::collection;
    use token_objects::token::{Self, MutabilityConfig};

    const E_NO_SUCH_PORTRAIT_BASE: u64 = 1;
    const E_NO_SUCH_PARTS: u64 = 2;
    const E_INVALID_PARTS: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_INVALID_PARTS_ID: u64 = 5;

    struct PortraitOnChainConfig has key {
        portrait_collection_name: String,
        portrait_mutability_config: MutabilityConfig,
        parts_collection_name: String,
        parts_mutability_config: MutabilityConfig
    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct PortraitBase has key {
        face: Option<Object<Parts<Face>>>,
        hair: Option<Object<Parts<Hair>>>,
        ear: Option<Object<Parts<Ear>>>,
        nose: Option<Object<Parts<Nose>>>,
        eyes: Option<Object<Parts<Eyes>>>,
        mouth: Option<Object<Parts<Mouth>>>
    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct Parts<phantom P> has key {
        attribute: String
    }

    struct Face {}
    struct Hair {}
    struct Ear {}
    struct Nose {}
    struct Eyes {}
    struct Mouth {}

    fun init_module(caller: &signer) {
        let portrait_collection_name = utf8(b"garage-token");
        let parts_collection_name = utf8(b"garage-token-parts-collection");
        _ = collection::create_fixed_collection(
            caller,
            utf8(b"user-customizbale-token"),
            10_000,
            collection::create_mutability_config(false, false),
            portrait_collection_name,
            option::none(),
            utf8(b"token-collection-url")
        );
        _ = collection::create_aggregable_collection(
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
                parts_collection_name,
                parts_mutability_config: token::create_mutability_config(
                    false, false, false
                ) 
            }
        );
    }

    fun crate_portrait_base(
        creator: &signer,
        description: String,
        name: String,
        uri: String
    ): Object<PortraitBase>
    acquires PortraitOnChainConfig {
        let on_chain_config = borrow_global<PortraitOnChainConfig>(
            signer::address_of(creator)
        );
        let creator_ref = token::create_token(
            creator,
            on_chain_config.portrait_collection_name,
            description,
            on_chain_config.portrait_mutability_config,
            name,
            option::none(),
            uri
        );
        let token_signer = object::generate_signer(&creator_ref);
        move_to(
            &token_signer,
            PortraitBase{
                face: option::none(),
                hair: option::none(),
                ear: option::none(),
                nose: option::none(),
                eyes: option::none(),
                mouth: option::none()
            }
        );
        object::address_to_object(signer::address_of(&token_signer))
    }

    fun create<P>(
        creator: &signer,
        description: String,
        name: String,
        attribute: String,
        uri: String
    ): Object<Parts<P>>
    acquires PortraitOnChainConfig {
        let on_chain_config = borrow_global<PortraitOnChainConfig>(
            signer::address_of(creator)
        );
        let creator_ref = token::create_token(
            creator,
            on_chain_config.parts_collection_name,
            description,
            on_chain_config.parts_mutability_config,
            name,
            option::none(),
            uri
        );
        let token_signer = object::generate_signer(&creator_ref);
        move_to(
            &token_signer,
            Parts<P>{
                attribute
            }
        );
        object::address_to_object<Parts<P>>(signer::address_of(&token_signer))
    }

    inline fun put_on_check<P>(
        owner: &signer,
        base: Object<PortraitBase>,
        parts: Object<Parts<P>>
    ) {
        assert!(
            exists<PortraitBase>(object::object_address(&base)),
            error::not_found(E_NO_SUCH_PORTRAIT_BASE)
        );
        assert!(
            exists<Parts<P>>(object::object_address(&parts)),
            error::not_found(E_NO_SUCH_PARTS)
        );
        let owner_addr = signer::address_of(owner);
        assert!(
            object::is_owner(base, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            object::is_owner(parts, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
    }

    fun put_on_hair(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Hair>>
    )
    acquires PortraitBase {
        put_on_check<Hair>(
            owner,
            base_obj,
            parts_obj
        );
        let base = borrow_global_mut<PortraitBase>(
            object::object_address(&base_obj)
        );
        option::fill(&mut base.hair, parts_obj);
        object::transfer_to_object(
            owner,
            parts_obj,
            base_obj
        );
    }

    fun put_on_face(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Face>>
    )
    acquires PortraitBase {
        put_on_check<Face>(
            owner,
            base_obj,
            parts_obj
        );
        let base = borrow_global_mut<PortraitBase>(
            object::object_address(&base_obj)
        );
        option::fill(&mut base.face, parts_obj);
        object::transfer_to_object(
            owner,
            parts_obj,
            base_obj
        );
    }

    fun put_on_ear(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Ear>>
    )
    acquires PortraitBase {
        put_on_check<Ear>(
            owner,
            base_obj,
            parts_obj
        );
        let base = borrow_global_mut<PortraitBase>(
            object::object_address(&base_obj)
        );
        option::fill(&mut base.ear, parts_obj);
        object::transfer_to_object(
            owner,
            parts_obj,
            base_obj
        );
    }

    fun put_on_nose(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Nose>>
    )
    acquires PortraitBase {
        put_on_check<Nose>(
            owner,
            base_obj,
            parts_obj
        );
        let base = borrow_global_mut<PortraitBase>(
            object::object_address(&base_obj)
        );
        option::fill(&mut base.nose, parts_obj);
        object::transfer_to_object(
            owner,
            parts_obj,
            base_obj
        );
    }

    fun put_on_eyes(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Eyes>>
    )
    acquires PortraitBase {
        put_on_check<Eyes>(
            owner,
            base_obj,
            parts_obj
        );
        let base = borrow_global_mut<PortraitBase>(
            object::object_address(&base_obj)
        );
        option::fill(&mut base.eyes, parts_obj);
        object::transfer_to_object(
            owner,
            parts_obj,
            base_obj
        );
    }

    fun put_on_mouth(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Mouth>>
    )
    acquires PortraitBase {
        put_on_check<Mouth>(
            owner,
            base_obj,
            parts_obj
        );
        let base = borrow_global_mut<PortraitBase>(
            object::object_address(&base_obj)
        );
        option::fill(&mut base.mouth, parts_obj);
        object::transfer_to_object(
            owner,
            parts_obj,
            base_obj
        );
    }

    inline fun take_off_check(
        owner: &signer,
        base: Object<PortraitBase>
    ) {
        assert!(
            exists<PortraitBase>(object::object_address(&base)),
            error::not_found(E_NO_SUCH_PORTRAIT_BASE)
        );
        assert!(
            object::is_owner(base, signer::address_of(owner)),
            error::permission_denied(E_NOT_OWNER)
        );
    }

    fun take_off_hair(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Hair>>
    )
    acquires PortraitBase {
        take_off_check(owner, base_obj);
        let base_obj_addr = object::object_address(&base_obj);
        let base = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base.hair);
        assert!(
            stored_parts == parts_obj,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts_obj, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts_obj,
            signer::address_of(owner)
        );
    }

    fun take_off_face(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Face>>
    )
    acquires PortraitBase {
        take_off_check(owner, base_obj);
        let base_obj_addr = object::object_address(&base_obj);
        let base = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base.face);
        assert!(
            stored_parts == parts_obj,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts_obj, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts_obj,
            signer::address_of(owner)
        );
    }

    fun take_off_ear(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Ear>>
    )
    acquires PortraitBase {
        take_off_check(owner, base_obj);
        let base_obj_addr = object::object_address(&base_obj);
        let base = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base.ear);
        assert!(
            stored_parts == parts_obj,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts_obj, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts_obj,
            signer::address_of(owner)
        );
    }

    fun take_off_nose(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Nose>>
    )
    acquires PortraitBase {
        take_off_check(owner, base_obj);
        let base_obj_addr = object::object_address(&base_obj);
        let base = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base.nose);
        assert!(
            stored_parts == parts_obj,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts_obj, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts_obj,
            signer::address_of(owner)
        );
    }

    fun take_off_eyes(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Eyes>>
    )
    acquires PortraitBase {
        take_off_check(owner, base_obj);
        let base_obj_addr = object::object_address(&base_obj);
        let base = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base.eyes);
        assert!(
            stored_parts == parts_obj,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts_obj, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts_obj,
            signer::address_of(owner)
        );
    }

    fun take_off_mouth(
        owner: &signer,
        base_obj: Object<PortraitBase>,
        parts_obj: Object<Parts<Mouth>>
    )
    acquires PortraitBase {
        take_off_check(owner, base_obj);
        let base_obj_addr = object::object_address(&base_obj);
        let base = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base.mouth);
        assert!(
            stored_parts == parts_obj,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts_obj, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts_obj,
            signer::address_of(owner)
        );
    }

    #[test(account = @123)]
    fun test_put_on_take_off_hair(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase {
        init_module(account);
        let addr = signer::address_of(account);

        let base = crate_portrait_base(
            account,
            utf8(b"user-customizable-token-00"),
            utf8(b"portrait-00"),
            utf8(b"portrait-00-url")
        );
        assert!(object::is_owner(base, addr), 0);
        let base_obj_addr = object::object_address(&base);

        let parts = create<Hair>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"hair"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts, addr), 1);
        put_on_hair(account, base, parts);
        assert!(object::is_owner(parts, base_obj_addr), 2);

        take_off_hair(account, base, parts);
        assert!(object::is_owner(parts, addr), 3);
    }

    #[test(account = @123)]
    fun test_put_on_take_off_face(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase {
        init_module(account);
        let addr = signer::address_of(account);

        let base = crate_portrait_base(
            account,
            utf8(b"user-customizable-token-00"),
            utf8(b"portrait-00"),
            utf8(b"portrait-00-url")
        );
        assert!(object::is_owner(base, addr), 0);
        let base_obj_addr = object::object_address(&base);

        let parts = create<Face>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"face"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts, addr), 1);
        put_on_face(account, base, parts);
        assert!(object::is_owner(parts, base_obj_addr), 2);

        take_off_face(account, base, parts);
        assert!(object::is_owner(parts, addr), 3);
    }

    #[test(account = @123)]
    fun test_put_on_take_off_ear(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase {
        init_module(account);
        let addr = signer::address_of(account);

        let base = crate_portrait_base(
            account,
            utf8(b"user-customizable-token-00"),
            utf8(b"portrait-00"),
            utf8(b"portrait-00-url")
        );
        assert!(object::is_owner(base, addr), 0);
        let base_obj_addr = object::object_address(&base);

        let parts = create<Ear>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"ear"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts, addr), 1);
        put_on_ear(account, base, parts);
        assert!(object::is_owner(parts, base_obj_addr), 2);

        take_off_ear(account, base, parts);
        assert!(object::is_owner(parts, addr), 3);
    }

    #[test(account = @123)]
    fun test_put_on_take_off_nose(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase {
        init_module(account);
        let addr = signer::address_of(account);

        let base = crate_portrait_base(
            account,
            utf8(b"user-customizable-token-00"),
            utf8(b"portrait-00"),
            utf8(b"portrait-00-url")
        );
        assert!(object::is_owner(base, addr), 0);
        let base_obj_addr = object::object_address(&base);

        let parts = create<Ear>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"nose"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts, addr), 1);
        put_on_ear(account, base, parts);
        assert!(object::is_owner(parts, base_obj_addr), 2);

        take_off_ear(account, base, parts);
        assert!(object::is_owner(parts, addr), 3);
    }

    #[test(account = @123)]
    fun test_put_on_take_off_eyes(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase {
        init_module(account);
        let addr = signer::address_of(account);

        let base = crate_portrait_base(
            account,
            utf8(b"user-customizable-token-00"),
            utf8(b"portrait-00"),
            utf8(b"portrait-00-url")
        );
        assert!(object::is_owner(base, addr), 0);
        let base_obj_addr = object::object_address(&base);

        let parts = create<Eyes>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"eyes"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts, addr), 1);
        put_on_eyes(account, base, parts);
        assert!(object::is_owner(parts, base_obj_addr), 2);

        take_off_eyes(account, base, parts);
        assert!(object::is_owner(parts, addr), 3);
    }

    #[test(account = @123)]
    fun test_put_on_take_off_mouth(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase {
        init_module(account);
        let addr = signer::address_of(account);

        let base = crate_portrait_base(
            account,
            utf8(b"user-customizable-token-00"),
            utf8(b"portrait-00"),
            utf8(b"portrait-00-url")
        );
        assert!(object::is_owner(base, addr), 0);
        let base_obj_addr = object::object_address(&base);

        let parts = create<Mouth>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"mouth"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts, addr), 1);
        put_on_mouth(account, base, parts);
        assert!(object::is_owner(parts, base_obj_addr), 2);

        take_off_mouth(account, base, parts);
        assert!(object::is_owner(parts, addr), 3);
    }
}