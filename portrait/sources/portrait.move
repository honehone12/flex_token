// simple idea with move object model.
// the idea is that looks like current distributed NFTs
// but each parts can be replaced.

module flex_token::portrait {
    use std::error;
    use std::signer;
    use std::vector;
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
    const E_INVALID_OBJECT_ADDRESS: u64 = 8;

    const MAX_NAME: u64 = 64;
    const MAX_DESC: u64 = 128;
    const MAX_URL: u64 = 128;

    struct PortraitOnChainConfig has key {
        base_mutability_config: MutabilityConfig,
        base_collection_object: Object<Collection>,
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
        let base_constructor = collection::create_fixed_collection(
            caller,
            utf8(b"user-customizbale-token"),
            10_000,
            collection::create_mutability_config(false, false),
            utf8(b"flex-token"),
            option::none(),
            utf8(b"token-collection-url")
        );
        let parts_constructor = collection::create_aggregable_collection(
            caller,
            utf8(b"parts-collection-for-user-customizable-token"),
            collection::create_mutability_config(false, false),
            utf8(b"flex-token-parts-collection"),
            option::none(),
            utf8(b"parts-collection-url")
        );
        move_to(
            caller,
            PortraitOnChainConfig{
                base_mutability_config: token::create_mutability_config(
                    false, false, false
                ),
                base_collection_object: object::object_from_constructor_ref(
                    &base_constructor
                ),
                parts_mutability_config: token::create_mutability_config(
                    false, false, false
                ),
                parts_collection_object: object::object_from_constructor_ref(
                    &parts_constructor
                )
            }
        );
    }

    inline fun verify_address<T: key>(obj_address: address): Object<T> {
        assert!(exists<T>(obj_address), error::not_found(E_INVALID_OBJECT_ADDRESS));
        object::address_to_object<T>(obj_address)
    }

    // !!!
    // [0: face, 1: hair, 2: eyes, 3: mouth]
    #[view]
    public fun portrait(object_address: address): vector<Option<address>>
    acquires PortraitBase {
        _ = verify_address<PortraitBase>(object_address);
        let portrait = borrow_global<PortraitBase>(object_address);
        let vec_addr = vector::empty<Option<address>>();
        vector::push_back(
            &mut vec_addr,
            if (option::is_some(&portrait.face)) {
                option::some(object::object_address(option::borrow(&portrait.face)))
            } else {
                option::none()
            }
        );
        vector::push_back(
            &mut vec_addr,
            if (option::is_some(&portrait.hair)) {
                option::some(object::object_address(option::borrow(&portrait.hair)))
            } else {
                option::none()
            }
        );
        vector::push_back(
            &mut vec_addr,
            if (option::is_some(&portrait.eyes)) {
                option::some(object::object_address(option::borrow(&portrait.eyes)))
            } else {
                option::none()
            }
        );
        vector::push_back(
            &mut vec_addr,
            if (option::is_some(&portrait.mouth)) {
                option::some(object::object_address(option::borrow(&portrait.mouth)))
            } else {
                option::none()
            }
        );
        vec_addr
    }

    #[view]
    public fun base_creator(object_address: address): address {
        let obj = verify_address<PortraitBase>(object_address);
        token::creator(obj)
    }

    // !!!
    //[0: collection, 1: description, 2: name, 3: uri]
    #[view]
    public fun base_info(object_address: address): vector<String> {
        let obj = verify_address<PortraitBase>(object_address);
        let infos = vector::empty<String>();
        vector::push_back(&mut infos, token::collection(obj));
        vector::push_back(&mut infos, token::description(obj));
        vector::push_back(&mut infos, token::name(obj));
        vector::push_back(&mut infos, token::uri(obj));
        infos
    }

    #[view]
    public fun face_creator(object_address: address): address {
        parts_creator<Face>(object_address)
    }

    #[view]
    public fun hair_creator(object_address: address): address {
        parts_creator<Hair>(object_address)
    }

    #[view]
    public fun eyes_creator(object_address: address): address {
        parts_creator<Eyes>(object_address)
    }

    #[view]
    public fun mouth_creator(object_address: address): address {
        parts_creator<Mouth>(object_address)
    } 
    
    fun parts_creator<P>(object_address: address): address {
        let obj = verify_address<Parts<P>>(object_address);
        token::creator(obj)
    }

    #[view]
    public fun face_info(object_address: address): vector<String>
    acquires Parts {
        parts_info<Face>(object_address)
    }

    #[view]
    public fun hair_info(object_address: address): vector<String>
    acquires Parts {
        parts_info<Hair>(object_address)
    }

    #[view]
    public fun eyes_info(object_address: address): vector<String>
    acquires Parts {
        parts_info<Eyes>(object_address)
    }

    #[view]
    public fun mouth_info(object_address: address): vector<String>
    acquires Parts {
        parts_info<Mouth>(object_address)
    }

    // !!!
    //[0: collection, 1: description, 2: name, 3: attribute 4: uri]
    fun parts_info<P>(object_address: address): vector<String>
    acquires Parts {
        let obj = verify_address<Parts<P>>(object_address);
        let parts = borrow_global<Parts<P>>(object_address);
        let infos = vector::empty<String>();
        vector::push_back(&mut infos, token::collection(obj));
        vector::push_back(&mut infos, token::description(obj));
        vector::push_back(&mut infos, token::name(obj));
        vector::push_back(&mut infos, parts.attribute);
        vector::push_back(&mut infos, token::uri(obj));
        infos
    }

    #[view]
    public fun base_collection_creator(): address
    acquires PortraitOnChainConfig {
        let config = borrow_global<PortraitOnChainConfig>(@admin);
        collection::creator(config.base_collection_object)
    }

    // !!!
    //[0: description, 1: name, 2: uri]
    #[view]
    public fun base_collection_info(): vector<String>
    acquires PortraitOnChainConfig {
        let config = borrow_global<PortraitOnChainConfig>(@admin);
        let infos = vector::empty<String>();
        vector::push_back(&mut infos, collection::description(config.base_collection_object));
        vector::push_back(&mut infos, collection::name(config.base_collection_object));
        vector::push_back(&mut infos, collection::uri(config.base_collection_object));
        infos
    }

    #[view]
    public fun parts_collection_creator(): address
    acquires PortraitOnChainConfig {
        let config = borrow_global<PortraitOnChainConfig>(@admin);
        collection::creator(config.base_collection_object)
    }

    // !!!
    //[0: description, 1: name, 2: uri]
    #[view]
    public fun parts_collection_info(): vector<String>
    acquires PortraitOnChainConfig {
        let config = borrow_global<PortraitOnChainConfig>(@admin);
        let infos = vector::empty<String>();
        vector::push_back(&mut infos, collection::description(config.parts_collection_object));
        vector::push_back(&mut infos, collection::name(config.parts_collection_object));
        vector::push_back(&mut infos, collection::uri(config.parts_collection_object));
        infos
    }

    inline fun check_admin(addr: address) {
        assert!(
            addr == @admin, 
            error::permission_denied(E_NOT_ADMIN)
        );
    }

    entry fun mint_portrait(
        creator: &signer,
        description: String,
        name: String,
        uri: String
    )
    acquires PortraitOnChainConfig {
        _ = create_portrait_base(
            creator,
            &description,
            &name,
            &uri
        );
    }

    fun create_portrait_base(
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
            collection::name(on_chain_config.base_collection_object),
            *description,
            on_chain_config.base_mutability_config,
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

    entry fun mint_face(
        creator: &signer,
        description: String,
        name: String,
        attribute: String,
        uri: String
    )
    acquires PortraitOnChainConfig {
        _ = create<Face>(
            creator,
            &description,
            &name,
            &attribute,
            &uri
        );
    }

    entry fun mint_hair(
        creator: &signer,
        description: String,
        name: String,
        attribute: String,
        uri: String
    )
    acquires PortraitOnChainConfig {
        _ = create<Hair>(
            creator,
            &description,
            &name,
            &attribute,
            &uri
        );
    }

    entry fun mint_eyes(
        creator: &signer,
        description: String,
        name: String,
        attribute: String,
        uri: String
    )
    acquires PortraitOnChainConfig {
        _ = create<Eyes>(
            creator,
            &description,
            &name,
            &attribute,
            &uri
        );
    }

    entry fun mint_mouth(
        creator: &signer,
        description: String,
        name: String,
        attribute: String,
        uri: String
    )
    acquires PortraitOnChainConfig {
        _ = create<Mouth>(
            creator,
            &description,
            &name,
            &attribute,
            &uri
        );
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
            collection::name(on_chain_config.parts_collection_object),
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

    entry fun set_face(
        owner: &signer,
        base_object: address,
        parts_object: address
    )
    acquires PortraitBase, Parts {
        put_on_face(
            owner,
            &object::address_to_object<PortraitBase>(base_object),
            &object::address_to_object<Parts<Face>>(parts_object)
        );
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

    entry fun set_hair(
        owner: &signer,
        base_object: address,
        parts_object: address
    )
    acquires PortraitBase, Parts {
        put_on_hair(
            owner,
            &object::address_to_object<PortraitBase>(base_object),
            &object::address_to_object<Parts<Hair>>(parts_object)
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

    entry fun set_eyes(
        owner: &signer,
        base_object: address,
        parts_object: address
    )
    acquires PortraitBase, Parts {
        put_on_eyes(
            owner,
            &object::address_to_object<PortraitBase>(base_object),
            &object::address_to_object<Parts<Eyes>>(parts_object)
        );
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

    entry fun set_mouth(
        owner: &signer,
        base_object: address,
        parts_object: address
    )
    acquires PortraitBase, Parts {
        put_on_mouth(
            owner,
            &object::address_to_object<PortraitBase>(base_object),
            &object::address_to_object<Parts<Mouth>>(parts_object)
        );
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

    entry fun remove_face(
        owner: &signer,
        base_object: address,
        parts_object: address
    )
    acquires PortraitBase, Parts {
        take_off_face(
            owner,
            &object::address_to_object<PortraitBase>(base_object),
            &object::address_to_object<Parts<Face>>(parts_object)
        );
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

    entry fun remove_hair(
        owner: &signer,
        base_object: address,
        parts_object: address
    )
    acquires PortraitBase, Parts {
        take_off_hair(
            owner,
            &object::address_to_object<PortraitBase>(base_object),
            &object::address_to_object<Parts<Hair>>(parts_object)
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

    entry fun remove_eyes(
        owner: &signer,
        base_object: address,
        parts_object: address
    )
    acquires PortraitBase, Parts {
        take_off_eyes(
            owner,
            &object::address_to_object<PortraitBase>(base_object),
            &object::address_to_object<Parts<Eyes>>(parts_object)
        );
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

    entry fun remove_mouth(
        owner: &signer,
        base_object: address,
        parts_object: address
    )
    acquires PortraitBase, Parts {
        take_off_mouth(
            owner,
            &object::address_to_object<PortraitBase>(base_object),
            &object::address_to_object<Parts<Mouth>>(parts_object)
        );
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

    public entry fun register(account: &signer) {
        register_all(account);
    }

    fun register_all(account: &signer) {
        token_objects_holder::register<PortraitBase>(account);
        token_objects_holder::register<Parts<Face>>(account);
        token_objects_holder::register<Parts<Hair>>(account);
        token_objects_holder::register<Parts<Eyes>>(account);
        token_objects_holder::register<Parts<Mouth>>(account);
    }

    public entry fun transfer(
        owner: &signer,
        portrait_address: address,
        receiver: address
    ) {
        managed_transfer(
            owner, 
            &object::address_to_object(portrait_address),
            receiver
        );
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

    public entry fun update(account: &signer) {
        manual_update(account);
    }

    fun manual_update(account: &signer) {
        token_objects_holder::update<PortraitBase>(account);
        token_objects_holder::update<Parts<Hair>>(account);
        token_objects_holder::update<Parts<Face>>(account);
        token_objects_holder::update<Parts<Eyes>>(account);
        token_objects_holder::update<Parts<Mouth>>(account);
    }

    public entry fun recover(account: &signer, portrait_address: address) {
        recover_portrait(account, portrait_address);
    }

    fun recover_portrait(account: &signer, portrait_address: address) {
        token_objects_holder::recover<PortraitBase>(account, portrait_address);
    }

    #[test(account = @admin)]
    fun test_portrait(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base_addr = object::object_address(&create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        ));
        let face_addr = object::object_address(&create<Face>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-01-00"),
            &utf8(b"face"),
            &utf8(b"parts-00-url")
        ));
        let hair_addr = object::object_address(&create<Hair>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00-00"),
            &utf8(b"hair"),
            &utf8(b"parts-00-url")
        ));
        let eyes_addr = object::object_address(&create<Eyes>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-02-00"),
            &utf8(b"eyes"),
            &utf8(b"parts-00-url")
        ));
        let mouth_addr = object::object_address(&create<Mouth>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-03-00"),
            &utf8(b"mouth"),
            &utf8(b"parts-00-url")
        ));

        assert!(
            portrait(base_addr) == vector<Option<address>>[
                option::none(),
                option::none(),
                option::none(),
                option::none()
            ], 0
        );
        set_face(account, base_addr, face_addr);
        assert!(
            portrait(base_addr) == vector<Option<address>>[
                option::some(face_addr),
                option::none(),
                option::none(),
                option::none()
            ], 1
        );
        set_hair(account, base_addr, hair_addr);
        assert!(
            portrait(base_addr) == vector<Option<address>>[
                option::some(face_addr),
                option::some(hair_addr),
                option::none(),
                option::none()
            ], 2
        );
        set_eyes(account, base_addr, eyes_addr);
        assert!(
            portrait(base_addr) == vector<Option<address>>[
                option::some(face_addr),
                option::some(hair_addr),
                option::some(eyes_addr),
                option::none()
            ], 3
        );
        set_mouth(account, base_addr, mouth_addr);
        assert!(
            portrait(base_addr) == vector<Option<address>>[
                option::some(face_addr),
                option::some(hair_addr),
                option::some(eyes_addr),
                option::some(mouth_addr)
            ], 4
        );
    }
    
    #[test(account = @admin)]
    fun test_view(account: &signer)
    acquires PortraitOnChainConfig, Parts{
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let face = create<Face>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-01-00"),
            &utf8(b"face"),
            &utf8(b"parts-00-url")
        );
        let hair = create<Hair>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00-00"),
            &utf8(b"hair"),
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

        assert!(base_creator(object::object_address(&base)) == @admin, 0);
        assert!(face_creator(object::object_address(&face)) == @admin, 1);
        assert!(hair_creator(object::object_address(&hair)) == @admin, 2);
        assert!(eyes_creator(object::object_address(&eyes)) == @admin, 3);
        assert!(mouth_creator(object::object_address(&mouth)) == @admin, 4);
        assert!(
            base_info(object::object_address(&base)) == vector<String>[
                utf8(b"flex-token"),
                utf8(b"user-customizable-token-00"),
                utf8(b"portrait-00"),
                utf8(b"portrait-00-url")
            ], 5
        );
        assert!(
            face_info(object::object_address(&face)) == vector<String>[
                utf8(b"flex-token-parts-collection"),
                utf8(b"token-parts-00"),
                utf8(b"parts-01-00"),
                utf8(b"face"),
                utf8(b"parts-00-url")
            ], 6
        );
        assert!(
            hair_info(object::object_address(&hair)) == vector<String>[
                utf8(b"flex-token-parts-collection"),
                utf8(b"token-parts-00"),
                utf8(b"parts-00-00"),
                utf8(b"hair"),
                utf8(b"parts-00-url")
            ], 7
        );
        assert!(
            eyes_info(object::object_address(&eyes)) == vector<String>[
                utf8(b"flex-token-parts-collection"),
                utf8(b"token-parts-00"),
                utf8(b"parts-02-00"),
                utf8(b"eyes"),
                utf8(b"parts-00-url")
            ], 8
        );
        assert!(
            mouth_info(object::object_address(&mouth)) == vector<String>[
                utf8(b"flex-token-parts-collection"),
                utf8(b"token-parts-00"),
                utf8(b"parts-03-00"),
                utf8(b"mouth"),
                utf8(b"parts-00-url")
            ], 9
        );

        assert!(base_collection_creator() == @admin, 10);
        assert!(parts_collection_creator() == @admin, 11);
        assert!(
            base_collection_info() == vector<String>[
                utf8(b"user-customizbale-token"),
                utf8(b"flex-token"),
                utf8(b"token-collection-url")
            ], 12
        );
        assert!(
            parts_collection_info() == vector<String>[
                utf8(b"parts-collection-for-user-customizable-token"),
                utf8(b"flex-token-parts-collection"),
                utf8(b"parts-collection-url")
            ], 13
        );
    }

    #[test(account = @admin, other = @0xbeef)]
    fun test_transfer(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let face = create<Face>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-01-00"),
            &utf8(b"face"),
            &utf8(b"parts-00-url")
        );
        let hair = create<Hair>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00-00"),
            &utf8(b"hair"),
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
        put_on_face(account, &base, &face);
        put_on_hair(account, &base, &hair);
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
    fun test_put_on_take_off_face(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let addr = signer::address_of(account);

        let base = create_portrait_base(
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
    fun test_put_on_take_off_hair(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let addr = signer::address_of(account);

        let base = create_portrait_base(
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
    fun test_put_on_take_off_eyes(account: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let addr = signer::address_of(account);

        let base = create_portrait_base(
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

        let base = create_portrait_base(
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

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_put_invalid_face(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Face>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"face"),
            &utf8(b"parts-00-url")
        );

        register(other);
        transfer(account, object::object_address(&base), @0xbeef);
        set_face(other, object::object_address(&base), object::object_address(&parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_put_face_invalid_base(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Face>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"face"),
            &utf8(b"parts-00-url")
        );

        register(other);
        transfer(account, object::object_address(&base), @0xbeef);
        set_face(account, object::object_address(&base), object::object_address(&parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 65539, location = Self)]
    fun test_failure_remove_invalid_face(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Face>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"face"),
            &utf8(b"parts-00-url")
        );
        let fail_parts = create<Face>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-01"),
            &utf8(b"face"),
            &utf8(b"parts-00-url")
        );

        register(other);
        set_face(account, object::object_address(&base), object::object_address(&parts));
        transfer(account, object::object_address(&base), @0xbeef);
        remove_face(other, object::object_address(&base), object::object_address(&fail_parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_remove_face_invalid_base(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let fail_base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-01"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Face>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"face"),
            &utf8(b"parts-00-url")
        );
        
        register(other);
        set_face(account, object::object_address(&fail_base), object::object_address(&parts));
        transfer(account, object::object_address(&base), @0xbeef);
        remove_face(other, object::object_address(&fail_base), object::object_address(&parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_put_invalid_hair(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Hair>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"fair"),
            &utf8(b"parts-00-url")
        );

        register(other);
        transfer(account, object::object_address(&base), @0xbeef);
        set_hair(other, object::object_address(&base), object::object_address(&parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_put_hair_invalid_base(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Hair>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"hair"),
            &utf8(b"parts-00-url")
        );

        register(other);
        transfer(account, object::object_address(&base), @0xbeef);
        set_hair(account, object::object_address(&base), object::object_address(&parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 65539, location = Self)]
    fun test_failure_remove_invalid_hair(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Hair>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"hair"),
            &utf8(b"parts-00-url")
        );
        let fail_parts = create<Hair>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-01"),
            &utf8(b"hair"),
            &utf8(b"parts-00-url")
        );

        register(other);
        set_hair(account, object::object_address(&base), object::object_address(&parts));
        transfer(account, object::object_address(&base), @0xbeef);
        remove_hair(other, object::object_address(&base), object::object_address(&fail_parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_remove_hair_invalid_base(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let fail_base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-01"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Hair>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"hair"),
            &utf8(b"parts-00-url")
        );
        
        register(other);
        set_hair(account, object::object_address(&fail_base), object::object_address(&parts));
        transfer(account, object::object_address(&base), @0xbeef);
        remove_hair(other, object::object_address(&fail_base), object::object_address(&parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_put_invalid_eyes(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Eyes>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"eyes"),
            &utf8(b"parts-00-url")
        );

        register(other);
        transfer(account, object::object_address(&base), @0xbeef);
        set_eyes(other, object::object_address(&base), object::object_address(&parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_put_eyes_invalid_base(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Eyes>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"eyes"),
            &utf8(b"parts-00-url")
        );

        register(other);
        transfer(account, object::object_address(&base), @0xbeef);
        set_eyes(account, object::object_address(&base), object::object_address(&parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 65539, location = Self)]
    fun test_failure_remove_invalid_eyes(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Eyes>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"eyes"),
            &utf8(b"parts-00-url")
        );
        let fail_parts = create<Eyes>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-01"),
            &utf8(b"eyes"),
            &utf8(b"parts-00-url")
        );

        register(other);
        set_eyes(account, object::object_address(&base), object::object_address(&parts));
        transfer(account, object::object_address(&base), @0xbeef);
        remove_eyes(other, object::object_address(&base), object::object_address(&fail_parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_remove_eyes_invalid_base(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let fail_base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-01"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Eyes>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"eyes"),
            &utf8(b"parts-00-url")
        );
        
        register(other);
        set_eyes(account, object::object_address(&fail_base), object::object_address(&parts));
        transfer(account, object::object_address(&base), @0xbeef);
        remove_eyes(other, object::object_address(&fail_base), object::object_address(&parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_put_invalid_mouth(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Mouth>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"mouth"),
            &utf8(b"parts-00-url")
        );

        register(other);
        transfer(account, object::object_address(&base), @0xbeef);
        set_mouth(other, object::object_address(&base), object::object_address(&parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_put_mouth_invalid_base(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Mouth>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"mouth"),
            &utf8(b"parts-00-url")
        );

        register(other);
        transfer(account, object::object_address(&base), @0xbeef);
        set_mouth(account, object::object_address(&base), object::object_address(&parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 65539, location = Self)]
    fun test_failure_remove_invalid_mouth(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Mouth>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"mouth"),
            &utf8(b"parts-00-url")
        );
        let fail_parts = create<Mouth>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-01"),
            &utf8(b"mouth"),
            &utf8(b"parts-00-url")
        );

        register(other);
        set_mouth(account, object::object_address(&base), object::object_address(&parts));
        transfer(account, object::object_address(&base), @0xbeef);
        remove_mouth(other, object::object_address(&base), object::object_address(&fail_parts));
    }

    #[test(account = @admin, other = @0xbeef)]
    #[expected_failure(abort_code = 327684, location = Self)]
    fun test_failure_remove_mouth_invalid_base(account: &signer, other: &signer)
    acquires PortraitOnChainConfig, PortraitBase, Parts {
        init_module(account);
        let fail_base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-00"),
            &utf8(b"portrait-00-url")
        );
        let base = create_portrait_base(
            account,
            &utf8(b"user-customizable-token-00"),
            &utf8(b"portrait-01"),
            &utf8(b"portrait-00-url")
        );
        let parts = create<Mouth>(
            account,
            &utf8(b"token-parts-00"),
            &utf8(b"parts-00"),
            &utf8(b"mouth"),
            &utf8(b"parts-00-url")
        );
        
        register(other);
        set_mouth(account, object::object_address(&fail_base), object::object_address(&parts));
        transfer(account, object::object_address(&base), @0xbeef);
        remove_mouth(other, object::object_address(&fail_base), object::object_address(&parts));
    }
}