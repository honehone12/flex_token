// simple idea with move object model.
// the idea is that looks like current distributed NFTs
// but each parts can be replaced.

module garage_token::portrait {
    use std::error;
    use std::signer;
    use std::string::{String, utf8};
    use std::option::{Self, Option};
    use aptos_framework::object::{Self, ObjectId};
    use token_objects::collection;
    use token_objects::token::{Self, MutabilityConfig};

    const E_NO_SUCH_PORTRAIT_BASE: u64 = 1;
    const E_NO_SUCH_PARTS: u64 = 2;
    const E_INVALID_PARTS: u64 = 3;
    const E_NOT_OWNER: u64 = 4;

    struct PortraitOnChainConfig has key {
        portrait_collection_name: String,
        portrait_mutability_config: MutabilityConfig,
        parts_collection_name: String,
        parts_mutability_config: MutabilityConfig
    }

    struct TypedObjectId<phantom P> has store, copy, drop {
        id: ObjectId
    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct PortraitBase has key {
        face: Option<TypedObjectId<Face>>,
        hair: Option<TypedObjectId<Hair>>,
        ear: Option<TypedObjectId<Ear>>,
        nose: Option<TypedObjectId<Nose>>,
        eyes: Option<TypedObjectId<Eyes>>,
        mouth: Option<TypedObjectId<Mouth>>
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

    public fun exists_base(base: &TypedObjectId<PortraitBase>): bool {
        exists<PortraitBase>(object::object_id_address(&base.id))
    }

    public fun exists_parts<P>(parts: &TypedObjectId<P>): bool {
        exists<Parts<P>>(object::object_id_address(&parts.id))
    }

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
    ): TypedObjectId<PortraitBase>
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
        TypedObjectId<PortraitBase>{
            id: object::address_to_object_id(
                signer::address_of(&token_signer)
            )
        }
    }

    fun create<P>(
        creator: &signer,
        description: String,
        name: String,
        attribute: String,
        uri: String
    ): TypedObjectId<P>
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
        TypedObjectId<P>{
            id: object::address_to_object_id(
                signer::address_of(&token_signer)
            )
        }
    }

    fun put_on_check<P>(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<P>
    ) {
        assert!(
            exists_base(&base),
            error::not_found(E_NO_SUCH_PORTRAIT_BASE)
        );
        assert!(
            exists_parts<P>(&parts),
            error::not_found(E_NO_SUCH_PARTS)
        );
        let owner_addr = signer::address_of(owner);
        assert!(
            object::is_owner(base.id, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            object::is_owner(parts.id, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
    }

    fun put_on_hair(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Hair>
    )
    acquires PortraitBase {
        put_on_check<Hair>(
            owner,
            base,
            parts
        );
        let base_obj = borrow_global_mut<PortraitBase>(
            object::object_id_address(&base.id)
        );
        option::fill(&mut base_obj.hair, parts);
        object::transfer_to_object(
            owner,
            parts.id,
            base.id
        );
    }

    fun put_on_face(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Face>
    )
    acquires PortraitBase {
        put_on_check<Face>(
            owner,
            base,
            parts
        );
        let base_obj = borrow_global_mut<PortraitBase>(
            object::object_id_address(&base.id)
        );
        option::fill(&mut base_obj.face, parts);
        object::transfer_to_object(
            owner,
            parts.id,
            base.id
        );
    }

    fun put_on_ear(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Ear>
    )
    acquires PortraitBase {
        put_on_check<Ear>(
            owner,
            base,
            parts
        );
        let base_obj = borrow_global_mut<PortraitBase>(
            object::object_id_address(&base.id)
        );
        option::fill(&mut base_obj.ear, parts);
        object::transfer_to_object(
            owner,
            parts.id,
            base.id
        );
    }

    fun put_on_nose(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Nose>
    )
    acquires PortraitBase {
        put_on_check<Nose>(
            owner,
            base,
            parts
        );
        let base_obj = borrow_global_mut<PortraitBase>(
            object::object_id_address(&base.id)
        );
        option::fill(&mut base_obj.nose, parts);
        object::transfer_to_object(
            owner,
            parts.id,
            base.id
        );
    }

    fun put_on_eyes(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Eyes>
    )
    acquires PortraitBase {
        put_on_check<Eyes>(
            owner,
            base,
            parts
        );
        let base_obj = borrow_global_mut<PortraitBase>(
            object::object_id_address(&base.id)
        );
        option::fill(&mut base_obj.eyes, parts);
        object::transfer_to_object(
            owner,
            parts.id,
            base.id
        );
    }

    fun put_on_mouth(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Mouth>
    )
    acquires PortraitBase {
        put_on_check<Mouth>(
            owner,
            base,
            parts
        );
        let base_obj = borrow_global_mut<PortraitBase>(
            object::object_id_address(&base.id)
        );
        option::fill(&mut base_obj.mouth, parts);
        object::transfer_to_object(
            owner,
            parts.id,
            base.id
        );
    }

    fun take_off_hair(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Hair>
    )
    acquires PortraitBase {
        assert!(
            exists_base(&base),
            error::not_found(E_NO_SUCH_PORTRAIT_BASE)
        );
        let owner_addr = signer::address_of(owner);
        assert!(
            object::is_owner(base.id, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );

        let base_obj_addr = object::object_id_address(&base.id);
        let base_obj = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base_obj.hair);
        assert!(
            stored_parts == parts,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts.id, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts.id,
            owner_addr
        );
    }

    fun take_off_face(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Face>
    )
    acquires PortraitBase {
        assert!(
            exists_base(&base),
            error::not_found(E_NO_SUCH_PORTRAIT_BASE)
        );
        let owner_addr = signer::address_of(owner);
        assert!(
            object::is_owner(base.id, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );

        let base_obj_addr = object::object_id_address(&base.id);
        let base_obj = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base_obj.face);
        assert!(
            stored_parts == parts,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts.id, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts.id,
            owner_addr
        );
    }

    fun take_off_ear(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Ear>
    )
    acquires PortraitBase {
        assert!(
            exists_base(&base),
            error::not_found(E_NO_SUCH_PORTRAIT_BASE)
        );
        let owner_addr = signer::address_of(owner);
        assert!(
            object::is_owner(base.id, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );

        let base_obj_addr = object::object_id_address(&base.id);
        let base_obj = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base_obj.ear);
        assert!(
            stored_parts == parts,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts.id, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts.id,
            owner_addr
        );
    }

    fun take_off_nose(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Nose>
    )
    acquires PortraitBase {
        assert!(
            exists_base(&base),
            error::not_found(E_NO_SUCH_PORTRAIT_BASE)
        );
        let owner_addr = signer::address_of(owner);
        assert!(
            object::is_owner(base.id, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );

        let base_obj_addr = object::object_id_address(&base.id);
        let base_obj = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base_obj.nose);
        assert!(
            stored_parts == parts,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts.id, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts.id,
            owner_addr
        );
    }

    fun take_off_eyes(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Eyes>
    )
    acquires PortraitBase {
        assert!(
            exists_base(&base),
            error::not_found(E_NO_SUCH_PORTRAIT_BASE)
        );
        let owner_addr = signer::address_of(owner);
        assert!(
            object::is_owner(base.id, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );

        let base_obj_addr = object::object_id_address(&base.id);
        let base_obj = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base_obj.eyes);
        assert!(
            stored_parts == parts,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts.id, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts.id,
            owner_addr
        );
    }

    fun take_off_mouth(
        owner: &signer,
        base: TypedObjectId<PortraitBase>,
        parts: TypedObjectId<Mouth>
    )
    acquires PortraitBase {
        assert!(
            exists_base(&base),
            error::not_found(E_NO_SUCH_PORTRAIT_BASE)
        );
        let owner_addr = signer::address_of(owner);
        assert!(
            object::is_owner(base.id, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );

        let base_obj_addr = object::object_id_address(&base.id);
        let base_obj = borrow_global_mut<PortraitBase>(base_obj_addr);
        let stored_parts = option::extract(&mut base_obj.mouth);
        assert!(
            stored_parts == parts,
            error::invalid_argument(E_INVALID_PARTS)
        );
        assert!(
            object::is_owner(parts.id, base_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            parts.id,
            owner_addr
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
        assert!(object::is_owner(base.id, addr), 0);
        let base_obj_addr = object::object_id_address(&base.id);

        let parts = create<Hair>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"hair"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts.id, addr), 1);
        put_on_hair(account, base, parts);
        assert!(object::is_owner(parts.id, base_obj_addr), 2);

        take_off_hair(account, base, parts);
        assert!(object::is_owner(parts.id, addr), 2);
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
        assert!(object::is_owner(base.id, addr), 0);
        let base_obj_addr = object::object_id_address(&base.id);

        let parts = create<Face>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"face"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts.id, addr), 1);
        put_on_face(account, base, parts);
        assert!(object::is_owner(parts.id, base_obj_addr), 2);

        take_off_face(account, base, parts);
        assert!(object::is_owner(parts.id, addr), 2);
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
        assert!(object::is_owner(base.id, addr), 0);
        let base_obj_addr = object::object_id_address(&base.id);

        let parts = create<Ear>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"ear"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts.id, addr), 1);
        put_on_ear(account, base, parts);
        assert!(object::is_owner(parts.id, base_obj_addr), 2);

        take_off_ear(account, base, parts);
        assert!(object::is_owner(parts.id, addr), 2);
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
        assert!(object::is_owner(base.id, addr), 0);
        let base_obj_addr = object::object_id_address(&base.id);

        let parts = create<Ear>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"nose"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts.id, addr), 1);
        put_on_ear(account, base, parts);
        assert!(object::is_owner(parts.id, base_obj_addr), 2);

        take_off_ear(account, base, parts);
        assert!(object::is_owner(parts.id, addr), 2);
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
        assert!(object::is_owner(base.id, addr), 0);
        let base_obj_addr = object::object_id_address(&base.id);

        let parts = create<Eyes>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"eyes"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts.id, addr), 1);
        put_on_eyes(account, base, parts);
        assert!(object::is_owner(parts.id, base_obj_addr), 2);

        take_off_eyes(account, base, parts);
        assert!(object::is_owner(parts.id, addr), 2);
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
        assert!(object::is_owner(base.id, addr), 0);
        let base_obj_addr = object::object_id_address(&base.id);

        let parts = create<Mouth>(
            account,
            utf8(b"token-parts-00"),
            utf8(b"parts-00"),
            utf8(b"mouth"),
            utf8(b"parts-00-url")
        );
        assert!(object::is_owner(parts.id, addr), 1);
        put_on_mouth(account, base, parts);
        assert!(object::is_owner(parts.id, base_obj_addr), 2);

        take_off_mouth(account, base, parts);
        assert!(object::is_owner(parts.id, addr), 2);
    }
}