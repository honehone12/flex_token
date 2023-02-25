// currently everyone can mint design
// only admin can mint coin
// design can be transfered only when composed
// coin is sttill transferable with 3rd party

// soon:
// make code upgradable - need onother contact ??
// take fee on mint - 

// future:
// supply info
// royality info
// mutator

module flex_token::coins {
    use std::signer;
    use std::error;
    use std::option::{Self, Option};
    use std::string::{Self, String, utf8};
    use aptos_framework::object::{Self, Object, TransferRef};
    use aptos_framework::resource_account;
    use aptos_framework::account::SignerCapability;
    use token_objects::collection::{Self, Collection};
    use token_objects::token::{Self, MutabilityConfig};
    use token_objects_holder::token_objects_holder;

    const E_NO_SUCH_COINS: u64 = 1;
    const E_NO_SUCH_DESIGN: u64 = 2;
    const E_INVALID_DESIGN: u64 = 3;
    const E_NOT_OWNER: u64 = 4; 
    const E_TOO_LONG_INPUT: u64 = 5;
    const E_INVALID_OBJECT_ADDRESS: u64 = 6;
    const E_NOT_ADMIN: u64 = 7;

    const MAX_NAME: u64 = 64;
    const MAX_DESC: u64 = 128;
    const MAX_URL: u64 = 128;

    struct CoinsOnChainConfig has key {
        signer_capability: SignerCapability,
        coin_collection_name: String,
        coin_mutability_config: MutabilityConfig,
        coin_collection_object: Object<Collection>,
        design_collection_name: String,
        design_mutability_config: MutabilityConfig,
        design_collection_object: Object<Collection> 
    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct Coin has key {
        design: Option<Object<Design>> 
    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct Design has key {
        attribute: String,
        transfer_config: TransferRef
    }

    fun init_module(resource_signer: &signer) {
        let signer_capability = resource_account::retrieve_resource_account_cap(
            resource_signer,
            @admin
        );

        let coin_collection_name = utf8(b"flex-coin");
        let design_collection_name = utf8(b"flex-coin-design-collection");
        let coin_collection_cctor = collection::create_fixed_collection(
            resource_signer,
            utf8(b"user-customizable-coin"),
            1000_000,
            collection::create_mutability_config(false, false),
            coin_collection_name,
            option::none(),
            utf8(b"coin-collection-url")
        );
        let design_collection_cctor = collection::create_aggregable_collection(
            resource_signer,
            utf8(b"design-collection-for-user-customizable-coin"),
            collection::create_mutability_config(false, false),
            design_collection_name,
            option::none(),
            utf8(b"design-collection-url")
        );
        move_to(
            resource_signer, 
            CoinsOnChainConfig {
                signer_capability,
                coin_collection_name,
                coin_mutability_config: token::create_mutability_config(
                    false, false, false
                ),
                coin_collection_object: object::object_from_constructor_ref<Collection>(
                    &coin_collection_cctor
                ), 
                design_collection_name,
                design_mutability_config: token::create_mutability_config(
                    false, false, false
                ),
                design_collection_object: object::object_from_constructor_ref<Collection>(
                    &design_collection_cctor
                )
            }
        );
    }

    inline fun verify_coin_address(obj_addr: address): Object<Coin> {
        assert!(
            exists<Coin>(obj_addr),
            error::not_found(E_INVALID_OBJECT_ADDRESS)
        );
        object::address_to_object<Coin>(obj_addr)
    }

    inline fun verify_design_address(obj_addr: address): Object<Design> {
        assert!(
            exists<Design>(obj_addr),
            error::not_found(E_INVALID_OBJECT_ADDRESS)
        );
        object::address_to_object<Design>(obj_addr)
    }

    // anyone can view
    #[view]
    public fun coin_design(object_address: address): Option<address>
    acquires Coin {
        let obj = verify_coin_address(object_address);
        let coin = borrow_global<Coin>(object::object_address(&obj));
        let addr = if (option::is_some(&coin.design)) {
            option::some(
                object::object_address(option::borrow(&coin.design))
            )
        } else {
            option::none()
        };
        addr
    }

    #[view]
    public fun coin_creator(object_address: address): address {
        let obj = verify_coin_address(object_address);
        token::creator(obj)
    }

    #[view]
    public fun coin_info(object_address: address): String {
        let obj = verify_coin_address(object_address);
        let info = token::collection(obj);
        let separator = utf8(b",");
        string::append(&mut info, separator);
        string::append(&mut info, token::description(obj));
        string::append(&mut info, separator);
        string::append(&mut info, token::name(obj));
        string::append(&mut info, separator);
        string::append(&mut info, token::uri(obj));
        info
    }

    #[view]
    public fun design_creator(object_address: address): address {
        let obj = verify_design_address(object_address);
        token::creator(obj)
    }

    #[view]
    public fun design_info(object_address: address): String
    acquires Design {
        let obj = verify_design_address(object_address);
        let design = borrow_global<Design>(object_address);
        let info = token::collection(obj);
        let separator = utf8(b",");
        string::append(&mut info, separator);
        string::append(&mut info, token::description(obj));
        string::append(&mut info, separator);
        string::append(&mut info, token::name(obj));
        string::append(&mut info, separator);
        string::append(&mut info, design.attribute);
        string::append(&mut info, separator);
        string::append(&mut info, token::uri(obj));
        info
    }

    #[view]
    public fun coin_collection_creator(): address
    acquires CoinsOnChainConfig {
        let on_chain_config = borrow_global<CoinsOnChainConfig>(
            @flex_token
        );
        collection::creator(on_chain_config.coin_collection_object)
    }

    #[view]
    public fun coin_collection_info(): String
    acquires CoinsOnChainConfig {
        let on_chain_config = borrow_global<CoinsOnChainConfig>(
            @flex_token
        );
        let info = collection::description(on_chain_config.coin_collection_object);
        let separator = utf8(b",");
        string::append(&mut info, separator);
        string::append(
            &mut info,
            collection::name(on_chain_config.coin_collection_object) 
        );
        string::append(&mut info, separator);
        string::append(
            &mut info,
            collection::uri(on_chain_config.coin_collection_object)
        );
        info
    }

    #[view]
    public fun design_collection_creator(): address
    acquires CoinsOnChainConfig {
        let on_chain_config = borrow_global<CoinsOnChainConfig>(
            @flex_token
        );
        collection::creator(on_chain_config.design_collection_object)
    }

    #[view]
    public fun design_collection_info(): String
    acquires CoinsOnChainConfig {
        let on_chain_config = borrow_global<CoinsOnChainConfig>(
            @flex_token
        );
        let info = collection::description(on_chain_config.design_collection_object);
        let separator = utf8(b",");
        string::append(&mut info, separator);
        string::append(
            &mut info,
            collection::name(on_chain_config.design_collection_object) 
        );
        string::append(&mut info, separator);
        string::append(
            &mut info,
            collection::uri(on_chain_config.design_collection_object)
        );
        info
    }

    public entry fun register(account: &signer) {
        register_all(account);
    }

    inline fun register_all(account: &signer) {
        token_objects_holder::register<Coin>(account);
        token_objects_holder::register<Design>(account);
    }

    // this should be called after 3rd party transfer
    public entry fun update_resource(account: &signer) {
        manual_update(account);
    }

    inline fun manual_update(account: &signer) {
        token_objects_holder::update<Coin>(account);
        token_objects_holder::update<Design>(account);
    }

    public entry fun mint_coin(
        creator: &signer,
        description: String,
        name: String,
        uri: String,
    )
    acquires CoinsOnChainConfig {
        _ = create_coin(
            creator,
            &description,
            &name,
            &uri
        );
    } 

    fun create_coin(
        creator: &signer,
        description: &String,
        name: &String,
        uri: &String
    ): Object<Coin>
    acquires CoinsOnChainConfig {
        let creator_addr = signer::address_of(creator); 
        assert!(
            creator_addr == @admin,
            error::permission_denied(E_NOT_ADMIN)
        );
        
        assert!(
            string::length(description) <= MAX_DESC &&
            string::length(name) <= MAX_NAME &&
            string::length(uri) <= MAX_URL,
            error::invalid_argument(E_TOO_LONG_INPUT)
        );

        let on_chain_config = borrow_global<CoinsOnChainConfig>(
            @flex_token
        );
        let cctor_ref = token::create_token(
            creator,
            on_chain_config.coin_collection_name,
            *description,
            on_chain_config.coin_mutability_config,
            *name,
            option::none(),
            *uri
        );
        let token_signer = object::generate_signer(&cctor_ref);
        move_to(
            &token_signer, 
            Coin{
                design: option::none()
            }
        );
        let obj = object::address_to_object(signer::address_of(&token_signer));
        register_all(creator);
        token_objects_holder::add_to_holder(creator_addr, obj);
        obj
    }

    public entry fun mint_design(
        creator: &signer,
        description: String,
        name: String,
        attribute: String,
        uri: String
    )
    acquires CoinsOnChainConfig {
        _ = create_design(
            creator,
            &description,
            &name,
            &attribute,
            &uri
        );
    }

    fun create_design(
        creator: &signer,
        description: &String,
        name: &String,
        design_attribute: &String,
        uri: &String,
    ): Object<Design>
    acquires CoinsOnChainConfig {
        assert!(
            string::length(description) <= MAX_DESC &&
            string::length(name) <= MAX_NAME &&
            string::length(uri) <= MAX_URL,
            error::invalid_argument(E_TOO_LONG_INPUT)
        );
        
        let creator_addr = signer::address_of(creator);
        let on_chain_config = borrow_global<CoinsOnChainConfig>(
            @flex_token
        );
        let cctor_ref = token::create_token(
            creator,
            on_chain_config.design_collection_name,
            *description,
            on_chain_config.design_mutability_config,
            *name,
            option::none(),
            *uri
        );
        let transfer_ref = object::generate_transfer_ref(&cctor_ref);
        object::disable_ungated_transfer(&transfer_ref);

        let token_signer = object::generate_signer(&cctor_ref);
        move_to(
            &token_signer,
            Design{
                attribute: *design_attribute,
                transfer_config: transfer_ref
            }
        );
        let obj = object::address_to_object(signer::address_of(&token_signer));
        register_all(creator);
        token_objects_holder::add_to_holder(creator_addr, obj);
        obj
    }

    public entry fun transfer_coin(
        owner: &signer,
        coin_address: address,
        receiver: address 
    ) {
        let coin_obj = object::address_to_object<Coin>(coin_address);
        managed_transfer_coin(owner, coin_obj, receiver);
    }

    fun managed_transfer_coin(
        owner: &signer,
        coin_obj: Object<Coin>,
        receiver: address
    ) {
        let owner_addr = signer::address_of(owner);
        assert!(
            exists<Coin>(object::object_address(&coin_obj)),
            error::not_found(E_NO_SUCH_COINS)
        );
        assert!(
            object::is_owner(coin_obj, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            token_objects_holder::holds(owner_addr, coin_obj),
            error::permission_denied(E_NOT_OWNER)
        );

        object::transfer(owner, coin_obj, receiver);
        token_objects_holder::remove_from_holder(owner, coin_obj);
        token_objects_holder::add_to_holder(receiver, coin_obj);
    }

    public entry fun compose(
        owner: &signer,
        coin_address: address,
        design_address: address
    )
    acquires Coin, Design {
        let coin_obj =  object::address_to_object<Coin>(coin_address);
        let design_obj = object::address_to_object<Design>(design_address);
        compose_coin(owner, coin_obj, design_obj);
    }

    fun compose_coin(
        owner: &signer,
        coin_obj: Object<Coin>,
        design_obj: Object<Design>
    )
    acquires Coin, Design {
        assert!(
            exists<Coin>(object::object_address(&coin_obj)),
            error::not_found(E_NO_SUCH_COINS)
        );
        assert!(
            exists<Design>(object::object_address(&design_obj)),
            error::not_found(E_NO_SUCH_DESIGN)
        );
        let owner_addr = signer::address_of(owner);
        assert!(
            object::is_owner(coin_obj, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            object::is_owner(design_obj, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            token_objects_holder::holds(owner_addr, coin_obj),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            token_objects_holder::holds(owner_addr, design_obj),
            error::permission_denied(E_NOT_OWNER)
        );

        let coin = borrow_global_mut<Coin>(
            object::object_address(&coin_obj)
        );
        let design = borrow_global_mut<Design>(
            object::object_address(&design_obj)
        );
        object::enable_ungated_transfer(&design.transfer_config);
        option::fill(&mut coin.design, design_obj);
        object::transfer_to_object(owner, design_obj, coin_obj);
        token_objects_holder::remove_from_holder(owner, design_obj);
    }

    public entry fun decompose(
        owner: &signer,
        coin_address: address,
        design_address: address
    )
    acquires Coin, Design {
        let coin_obj = object::address_to_object(coin_address);
        let design_obj = object::address_to_object(design_address);
        decompose_coin(owner, coin_obj, design_obj);
    }

    fun decompose_coin(
        owner: &signer,
        coin_obj: Object<Coin>,
        design_obj: Object<Design>
    )
    acquires Coin, Design {
        let coin_obj_addr = object::object_address(&coin_obj);
        assert!(
            exists<Coin>(coin_obj_addr),
            error::not_found(E_NO_SUCH_COINS)
        );
        let owner_addr = signer::address_of(owner);
        assert!(
            object::is_owner(coin_obj, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            token_objects_holder::holds(owner_addr, coin_obj),
            error::permission_denied(E_NOT_OWNER)
        );

        let coin = borrow_global_mut<Coin>(coin_obj_addr);
        let stored_design = option::extract(&mut coin.design);
        assert!(
            stored_design == design_obj,
            error::invalid_argument(E_INVALID_DESIGN)
        );
        assert!(
            object::is_owner(design_obj, coin_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        let design = borrow_global_mut<Design>(
            object::object_address(&stored_design)
        );
        object::transfer(owner, design_obj, owner_addr);
        object::disable_ungated_transfer(&design.transfer_config);
        token_objects_holder::add_to_holder(owner_addr, design_obj);
    }

    #[test_only]
    use std::vector;
    #[test_only]
    use aptos_framework::account;

    #[test_only]
    fun setup_test(caller: &signer, resource_signer: &signer) {
        account::create_account_for_test(signer::address_of(caller));
        resource_account::create_resource_account(
            caller,
            vector::empty<u8>(),
            vector::empty<u8>()
        );
        init_module(resource_signer);
    }

    #[test(
        account = @admin,
        resource = @flex_token,
        other = @234
    )]
    #[expected_failure]
    fun test_transfer_design_not_composed(
        account: &signer, 
        resource: &signer, 
        other: &signer
    )
    acquires CoinsOnChainConfig {
        setup_test(account, resource);

        let design_obj = create_design(
            account,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")    
        );
        object::transfer(account, design_obj, signer::address_of(other));
    }

    #[test(
        account = @admin,
        resource = @flex_token,
        other = @234
    )]
    #[expected_failure]
    fun test_transfer_design_after_decomposed(
        account: &signer, 
        resource: &signer, 
        other: &signer
    )
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);
        
        let coin_obj = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
            
        );
        let design_obj = create_design(
            account,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")    
        );
        compose_coin(account, coin_obj, design_obj);
        decompose_coin(account, coin_obj, design_obj);
        object::transfer(account, design_obj, signer::address_of(other));
    }

    #[test(
        account = @admin,
        resource = @flex_token,
        other = @234
    )]
    fun test_getter(account: &signer, resource: &signer, other: &signer)
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);

        let coin_obj = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
            
        );
        let design_obj = create_design(
            other,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")    
        );
        let coin_addr = object::object_address(&coin_obj);
        let design_addr = object::object_address(&design_obj);

        assert!(coin_creator(coin_addr) == @admin, 0);
        assert!(design_creator(design_addr) == @234, 1);
        assert!(
            coin_info(coin_addr) == 
            utf8(b"flex-coin,user-customizable-coin-00,coin-00,coin-00-url"), 
            2
        );
        assert!(
            design_info(design_addr) == 
            utf8(b"flex-coin-design-collection,coin-design-00,design-00,happy-birthdday,design-00-url"), 
            3
        );
        assert!(coin_collection_creator() == @flex_token, 4);
        assert!(design_collection_creator() == @flex_token, 5);
        assert!(
            coin_collection_info() ==
            utf8(b"user-customizable-coin,flex-coin,coin-collection-url"),
            6
        );
        assert!(
            design_collection_info() ==
            utf8(b"design-collection-for-user-customizable-coin,flex-coin-design-collection,design-collection-url"),
            7
        );

        let design_obj = create_design(
            account,
            &utf8(b"coin-design-01"),
            &utf8(b"design-01"),
            &utf8(b"happy-graduation"),
            &utf8(b"design-01-url")    
        );
        compose_coin(account, coin_obj, design_obj);
        assert!(
            option::contains(
                &coin_design(coin_addr), 
                &object::object_address(&design_obj)
            ),
            8
        );
    }

    #[test(
        account = @admin,
        resource = @flex_token,
        receiver = @234
    )]
    fun test_entry(account: &signer, resource: &signer, receiver: &signer)
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);

        mint_coin(
            account,
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
            
        );
        let addr = signer::address_of(account);
        let coin_addr = token::create_token_address(
            &addr,
            &utf8(b"flex-coin"),
            &utf8(b"coin-00")
        );
        let coin_obj = object::address_to_object<Coin>(coin_addr);
        assert!(object::is_owner(coin_obj, addr), 0);
        assert!(token_objects_holder::holds(addr, coin_obj), 1);
        register(receiver);
        let receiver_addr = signer::address_of(receiver);
        transfer_coin(account, coin_addr, receiver_addr);
        assert!(object::is_owner(coin_obj, receiver_addr), 2);
        assert!(token_objects_holder::holds(receiver_addr, coin_obj), 3);
    
        mint_design(
            account,
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")    
        );
        let design_addr = token::create_token_address(
            &addr,
            &utf8(b"flex-coin-design-collection"),
            &utf8(b"design-00")
        );
        let design_obj = object::address_to_object<Design>(design_addr);
        assert!(object::is_owner(design_obj, addr), 4);
        assert!(token_objects_holder::holds(addr, design_obj), 5);

        transfer_coin(receiver, coin_addr, addr);
        compose(account, coin_addr, design_addr);
        assert!(object::is_owner(design_obj, coin_addr), 6);
        assert!(!token_objects_holder::holds(addr, design_obj), 7);
        
        transfer_coin(account, coin_addr, receiver_addr);
        assert!(object::is_owner(design_obj, coin_addr), 8);
        assert!(!token_objects_holder::holds(receiver_addr, design_obj), 9);
        decompose(receiver, coin_addr, design_addr);
        assert!(object::is_owner(design_obj, receiver_addr), 10);
        assert!(token_objects_holder::holds(receiver_addr, design_obj), 11);
    }

    #[test(account = @admin, resource = @flex_token)]
    fun test_coin_compose_decompose(account: &signer, resource: &signer)
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);

        let coin = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let design_birthday = create_design(
            account,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
        let addr = signer::address_of(account);
        assert!(object::is_owner(coin, addr), 0);
        assert!(object::is_owner(design_birthday, addr), 1);
        assert!(token_objects_holder::holds(addr, coin), 9);
        assert!(token_objects_holder::holds(addr, design_birthday), 10);

        let coin_obj_addr = object::object_address(&coin);
        compose_coin(account, coin, design_birthday);
        assert!(object::is_owner(coin, addr), 2);
        assert!(object::is_owner(design_birthday, coin_obj_addr), 3);
        assert!(token_objects_holder::holds(addr, coin), 11);
        assert!(!token_objects_holder::holds(addr, design_birthday), 12);

        decompose_coin(account, coin, design_birthday);
        assert!(object::is_owner(coin, addr), 4);
        assert!(object::is_owner(design_birthday, addr), 5);
        assert!(token_objects_holder::holds(addr, coin), 13);
        assert!(token_objects_holder::holds(addr, design_birthday), 14);


        let design_graduation = create_design(
            account,
            &utf8(b"coin-design-01"),
            &utf8(b"design-01"),
            &utf8(b"happy-graduation"),
            &utf8(b"design-01-url")
        );
        assert!(object::is_owner(design_graduation, addr), 6);
        assert!(token_objects_holder::holds(addr, design_graduation), 15);

        compose_coin(account, coin, design_graduation);
        assert!(object::is_owner(coin, addr), 7);
        assert!(object::is_owner(design_graduation, coin_obj_addr), 8);
        assert!(!token_objects_holder::holds(addr, design_graduation), 16);
    }

    #[test(
        account = @admin, 
        resource = @flex_token,
        other = @0x234
    )]
    fun test_raw_transfer(account: &signer, resource: &signer, other: &signer)
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);

        let coin = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let design = create_design(
            account,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
        compose_coin(account, coin, design);
        let recipient_addr = signer::address_of(other);
        object::transfer(account, coin, recipient_addr);
        assert!(object::is_owner(coin, recipient_addr), 0);
        assert!(object::is_owner(design, object::object_address(&coin)), 1);
    }

    #[test(account = @admin, resource = @flex_token)]
    #[expected_failure]
    fun test_compose_not_exist_design(account: &signer, resource: &signer)
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);

        let coin = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let design = object::address_to_object<Design>(@0xbad);
        compose_coin(account, coin, design);
    }

    #[test(
        account = @admin,
        resource = @flex_token,
        other = @0x234
    )]
    #[expected_failure(
        abort_code = 0x50004,
        location = Self
    )]
    fun test_compose_not_owner_coin(
        account: &signer, 
        resource: &signer, 
        other: &signer
    )
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);
        
        let coin = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let design = create_design(
            account,
            &utf8(b"coin-design-01"),
            &utf8(b"design-01"),
            &utf8(b"happy-graduation"),
            &utf8(b"design-01-url")
        );
        object::transfer(account, coin, signer::address_of(other));
        compose_coin(account, coin, design);
    }

    #[test(
        account = @admin,
        resource = @flex_token,
        other = @0x234
    )]
    #[expected_failure(
        abort_code = 0x50004,
        location = Self
    )]
    fun test_compose_not_owner_design(
        account: &signer, 
        resource: &signer,
        other: &signer
    )
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);
        
        let coin = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let design = create_design(
            other,
            &utf8(b"coin-design-01"),
            &utf8(b"design-01"),
            &utf8(b"happy-graduation"),
            &utf8(b"design-01-url")
        );
        compose_coin(account, coin, design);
    }

    #[test(
        account = @admin,
        resource = @flex_token,
        other = @0x234
    )]
    #[expected_failure(
        abort_code = 0x50004,
        location = Self
    )]
    fun test_decompose_not_owner_coin(
        account: &signer,
        resource: &signer, 
        other: &signer
    )
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);
        
        let coin = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let design = create_design(
            account,
            &utf8(b"coin-design-01"),
            &utf8(b"design-01"),
            &utf8(b"happy-graduation"),
            &utf8(b"design-01-url")
        );
        compose_coin(account, coin, design);
        object::transfer(account, coin, signer::address_of(other));
        decompose_coin(account, coin, design);
    }

    #[test(account = @admin, resource = @flex_token)]
    #[expected_failure(
        abort_code = 0x10003,
        location = Self
    )]
    fun test_decompose_invalid_design(account: &signer, resource: &signer)
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);
        
        let coin = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let design_birthday = create_design(
            account,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
        compose_coin(account, coin, design_birthday);
        let design_birthday_mistake = create_design(
            account,
            &utf8(b"coin-design-01"),
            &utf8(b"design-01"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-01-url")
        );
        decompose_coin(account, coin, design_birthday_mistake);
    }

    #[test(
        account = @admin,
        resource = @flex_token,
        fake = @234    
    )]
    #[expected_failure]
    fun test_invalid_caller_coin(
        account: &signer, 
        resource: &signer,
        fake: &signer
    )
    acquires CoinsOnChainConfig {
        setup_test(account, resource);
        
        let _coin = create_coin(
            fake,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let _design = create_design(
            fake,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
    }

    #[test(
        account = @admin,
        resource = @flex_token,
        fake = @234    
    )]
    fun test_any_caller_design(
        account: &signer, 
        resource: &signer,
        fake: &signer)
    acquires CoinsOnChainConfig {
        setup_test(account, resource);
        
        let _design = create_design(
            fake,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
    }

    #[test(
        account = @admin,
        resource = @flex_token,
        fake = @234    
    )]
    #[expected_failure]
    fun test_invalid_caller_compose(
        account: &signer, 
        resource: &signer,
        fake: &signer
    )
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);
        
        let coin = create_coin(
            fake,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let design = create_design(
            fake,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
        compose_coin(fake, coin, design);
    }

    #[test(
        account = @admin,
        resource = @flex_token,
        fake = @234    
    )]
    #[expected_failure]
    fun test_invalid_caller_decompose(
        account: &signer, 
        resource: &signer,
        fake: &signer)
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);

        let coin = create_coin(
            fake,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let design = create_design(
            fake,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
        compose_coin(account, coin, design);
        decompose_coin(fake, coin, design);
    }

    #[test(account = @admin, resource = @flex_token)]
    #[expected_failure]
    fun test_create_twice_coin(account: &signer, resource: &signer)
    acquires CoinsOnChainConfig {
        setup_test(account, resource);
        
        let _coin = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let _coin2 = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );

    }

    #[test(account = @admin, resource = @flex_token)]
    #[expected_failure]
    fun test_create_twice_design(account: &signer, resource: &signer)
    acquires CoinsOnChainConfig {
        setup_test(account, resource);
        
        let _design = create_design(
            account,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
        let _design2 = create_design(
            account,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
    }

    #[test(account = @admin, resource = @flex_token)]
    #[expected_failure]
    fun test_compose_twice(account: &signer, resource: &signer)
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);
        
        let coin = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let design = create_design(
            account,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
        compose_coin(account, coin, design);
        compose_coin(account, coin, design);
    }

    #[test(account = @admin, resource = @flex_token)]
    #[expected_failure]
    fun test_decompose_twice(account: &signer, resource: &signer)
    acquires CoinsOnChainConfig, Coin, Design {
        setup_test(account, resource);
        
        let coin = create_coin(
            account,
            &utf8(b"user-customizable-coin-00"),
            &utf8(b"coin-00"),
            &utf8(b"coin-00-url"),
        );
        let design = create_design(
            account,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
        compose_coin(account, coin, design);
        decompose_coin(account, coin, design);
        decompose_coin(account, coin, design);
    }
}