// currently everyone can mint design
// only admin can mint coin

// future:
// supply info
// royality info
// mutator

module flex_token_coins::coins {
    use std::signer;
    use std::error;
    use std::option::{Self, Option};
    use std::string::{Self, String, utf8};
    use aptos_framework::object::{Self, Object, TransferRef};
    use aptos_framework::resource_account;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::event::{Self, EventHandle};
    use token_objects::collection::{Self, Collection};
    use token_objects::token::{Self, MutabilityConfig};
    use token_objects_holder::token_objects_holder;
    use flex_token_coins::royalties;
    use flex_token_coins::events::{Self, TransferEvent};

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

        coin_mutability_config: MutabilityConfig,
        coin_collection_object: Object<Collection>,
        design_mutability_config: MutabilityConfig,
        design_collection_object: Object<Collection>,

        transfer_events: EventHandle<TransferEvent> 
    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct Coin has key {
        design: Option<Object<Design>>,
        transfer_config: TransferRef, 
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

        let coin_collection_cctor = collection::create_fixed_collection(
            resource_signer,
            utf8(b"user-customizable-coin"),
            1000_000,
            collection::create_mutability_config(false, false),
            utf8(b"flex-coin"),
            royalties::create_collection_royalty(),
            utf8(b"coin-collection-url")
        );
        let design_collection_cctor = collection::create_untracked_collection(
            resource_signer,
            utf8(b"design-collection-for-user-customizable-coin"),
            collection::create_mutability_config(false, false),
            utf8(b"flex-coin-design-collection"),
            royalties::create_collection_royalty(),
            utf8(b"design-collection-url")
        );
        move_to(
            resource_signer, 
            CoinsOnChainConfig {
                signer_capability,
                coin_mutability_config: token::create_mutability_config(
                    false, false, false
                ),
                coin_collection_object: object::object_from_constructor_ref<Collection>(
                    &coin_collection_cctor
                ), 
                design_mutability_config: token::create_mutability_config(
                    false, false, false
                ),
                design_collection_object: object::object_from_constructor_ref<Collection>(
                    &design_collection_cctor
                ),
                transfer_events: account::new_event_handle<TransferEvent>(resource_signer)
            }
        );
    }

    inline fun verify_address<T: key> (obj_addr: address): Object<T> {
        assert!(exists<T>(obj_addr), error::not_found(E_INVALID_OBJECT_ADDRESS));
        object::address_to_object<T>(obj_addr)
    }

    // !!!
    // anyone can view
    #[view]
    public fun coin_design(object_address: address): Option<address>
    acquires Coin {
        _ = verify_address<Coin>(object_address);
        let coin = borrow_global<Coin>(object_address);
        extract_option_object(&coin.design)
    }

    inline fun extract_option_object<T: key>(op: &Option<Object<T>>)
    : Option<address> {
        if (option::is_some(op)) {
            option::some(
                object::object_address(option::borrow(op))
            )
        } else {
            option::none()
        }
    }

    #[view]
    public fun coin_creator(object_address: address): address {
        let obj = verify_address<Coin>(object_address);
        token::creator(obj)
    }

    // !!!
    // simply vector<String> looks better when client is JS.
    // but how about when client is C# or even C++ ??
    // might be happier to just split string than to parse JSON.
    // try vec in another module anyway.
    #[view]
    public fun coin_info(object_address: address): String {
        let obj = verify_address<Coin>(object_address);
        let info = token::collection(obj);
        let separator = utf8(b"||");
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
        let obj = verify_address<Design>(object_address);
        token::creator(obj)
    }

    #[view]
    public fun design_info(object_address: address): String
    acquires Design {
        let obj = verify_address<Design>(object_address);
        let design = borrow_global<Design>(object_address);
        let info = token::collection(obj);
        let separator = utf8(b"||");
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
        let on_chain_config = borrow_global<CoinsOnChainConfig>(@flex_token_coins);
        collection::creator(on_chain_config.coin_collection_object)
    }

    #[view]
    public fun coin_collection_info(): String
    acquires CoinsOnChainConfig {
        let on_chain_config = borrow_global<CoinsOnChainConfig>(@flex_token_coins);
        let info = collection::description(on_chain_config.coin_collection_object);
        let separator = utf8(b"||");
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
        let on_chain_config = borrow_global<CoinsOnChainConfig>(@flex_token_coins);
        collection::creator(on_chain_config.design_collection_object)
    }

    #[view]
    public fun design_collection_info(): String
    acquires CoinsOnChainConfig {
        let on_chain_config = borrow_global<CoinsOnChainConfig>(@flex_token_coins);
        let info = collection::description(on_chain_config.design_collection_object);
        let separator = utf8(b"||");
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

    entry fun mint_coin(
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

        let on_chain_config = borrow_global<CoinsOnChainConfig>(@flex_token_coins);
        let resource_signer = account::create_signer_with_capability(&on_chain_config.signer_capability);

        let cctor_ref = token::create_token(
            &resource_signer,
            collection::name(on_chain_config.coin_collection_object),
            *description,
            on_chain_config.coin_mutability_config,
            *name,
            royalties::create_coin_royalty(),
            *uri
        );
        let transfer_ref = object::generate_transfer_ref(&cctor_ref);
        object::disable_ungated_transfer(&transfer_ref);
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        let token_signer = object::generate_signer(&cctor_ref);
        
        register_all(creator);
        move_to(
            &token_signer, 
            Coin{
                design: option::none(),
                transfer_config: transfer_ref 
            }
        );
        object::transfer_with_ref(linear_transfer_ref, creator_addr);
        let obj = object::address_to_object(signer::address_of(&token_signer));
        token_objects_holder::add_to_holder(creator_addr, obj);
        obj
    }

    entry fun mint_design(
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
            string::length(uri) <= MAX_URL &&
            string::length(design_attribute) <= MAX_NAME,
            error::invalid_argument(E_TOO_LONG_INPUT)
        );
        
        let creator_addr = signer::address_of(creator);
        let on_chain_config = borrow_global<CoinsOnChainConfig>(@flex_token_coins);
        let resource_signer = account::create_signer_with_capability(&on_chain_config.signer_capability);

        let cctor_ref = token::create_token(
            &resource_signer,
            collection::name(on_chain_config.design_collection_object),
            *description,
            on_chain_config.design_mutability_config,
            *name,
            royalties::create_design_royalty(),
            *uri
        );
        let transfer_ref = object::generate_transfer_ref(&cctor_ref);
        object::disable_ungated_transfer(&transfer_ref);
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        let token_signer = object::generate_signer(&cctor_ref);

        register_all(creator);
        move_to(
            &token_signer,
            Design{
                attribute: *design_attribute,
                transfer_config: transfer_ref
            }
        );
        object::transfer_with_ref(linear_transfer_ref, creator_addr);
        let obj = object::address_to_object(signer::address_of(&token_signer));
        token_objects_holder::add_to_holder(creator_addr, obj);
        obj
    }

    entry fun compose(
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
        let design = borrow_global<Design>(
            object::object_address(&design_obj)
        );
        object::enable_ungated_transfer(&design.transfer_config);
        option::fill(&mut coin.design, design_obj);
        object::transfer_to_object(owner, design_obj, coin_obj);
        token_objects_holder::remove_from_holder(owner, design_obj);
    }

    entry fun decompose(
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
        let design = borrow_global<Design>(
            object::object_address(&stored_design)
        );
        object::enable_ungated_transfer(&coin.transfer_config);
        object::transfer(owner, design_obj, owner_addr);
        object::disable_ungated_transfer(&coin.transfer_config);
        object::disable_ungated_transfer(&design.transfer_config);
        token_objects_holder::add_to_holder(owner_addr, design_obj);
    }

    public entry fun register(account: &signer) {
        register_all(account);
    }

    fun register_all(account: &signer) {
        token_objects_holder::register<Coin>(account);
        token_objects_holder::register<Design>(account);
    }

    public entry fun transfer(
        owner: &signer,
        coin_address: address,
        receiver: address 
    )
    acquires CoinsOnChainConfig, Coin {
        let coin_obj = object::address_to_object<Coin>(coin_address);
        managed_transfer(owner, coin_obj, receiver);
    }

    fun managed_transfer(
        owner: &signer,
        coin_obj: Object<Coin>,
        receiver: address
    )
    acquires CoinsOnChainConfig, Coin {
        let owner_addr = signer::address_of(owner);
        let obj_addr = object::object_address(&coin_obj);
        assert!(
            exists<Coin>(obj_addr),
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

        let coin = borrow_global<Coin>(obj_addr);
        object::enable_ungated_transfer(&coin.transfer_config);
        let config = borrow_global_mut<CoinsOnChainConfig>(@flex_token_coins);
        event::emit_event(
            &mut config.transfer_events, 
            events::create_transfer_event(
                owner_addr,
                receiver,
                obj_addr,
                extract_option_object(&coin.design)
            )    
        );

        object::transfer(owner, coin_obj, receiver);
        object::disable_ungated_transfer(&coin.transfer_config);
        token_objects_holder::remove_from_holder(owner, coin_obj);
        token_objects_holder::add_to_holder(receiver, coin_obj);
    }

    // !!!
    // this should be called after 3rd party transfer
    public entry fun update(account: &signer) {
        manual_update(account);
    }

    fun manual_update(account: &signer) {
        token_objects_holder::update<Coin>(account);
        token_objects_holder::update<Design>(account);
    }

    // !!!
    // when someone transfer coin with 3rd party,
    // receiver's holder will simply lost it.
    entry fun recover(owner: &signer, coin_address: address) {
        recover(owner, coin_address);
    }

    fun recover_coin(owner: &signer, coin_address: address) {
        token_objects_holder::recover<Coin>(owner, coin_address);
    }

    // !!!
    // 3rd party transfer configs
    public entry fun enable_trading(owner: &signer, coin_address: address)
    acquires Coin {
        enable_ungated_transfer(owner, coin_address);
    }

    public entry fun disable_trading(owner: &signer, coin_address: address)
    acquires Coin {
        disable_ungated_transfer(owner, coin_address)
    }

    fun enable_ungated_transfer(owner: &signer, coin_addr: address)
    acquires Coin {
        let owner_addr = signer::address_of(owner);
        let coin_obj = object::address_to_object<Coin>(coin_addr);
        assert!(
            object::is_owner(coin_obj, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            token_objects_holder::holds(owner_addr, coin_obj),
            error::permission_denied(E_NOT_OWNER)
        );
        let coin = borrow_global<Coin>(coin_addr);
        object::enable_ungated_transfer(&coin.transfer_config);
    }

    fun disable_ungated_transfer(owner: &signer, coin_addr: address)
    acquires Coin {
        let owner_addr = signer::address_of(owner);
        let coin_obj = object::address_to_object<Coin>(coin_addr);
        assert!(
            object::is_owner(coin_obj, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            token_objects_holder::holds(owner_addr, coin_obj),
            error::permission_denied(E_NOT_OWNER)
        );
        let coin = borrow_global<Coin>(coin_addr);
        object::disable_ungated_transfer(&coin.transfer_config);
    }

    #[test_only]
    use std::vector;

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
        resource = @flex_token_coins,
        other = @0x234
    )]
    #[expected_failure(
        abort_code = 327683,
        location = aptos_framework::object
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
    }

    #[test(
        account = @admin,
        resource = @flex_token_coins,
        other = @234
    )]
    #[expected_failure(
        abort_code = 327683,
        location = aptos_framework::object
    )]
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
        resource = @flex_token_coins,
        other = @234
    )]
    #[expected_failure(
        abort_code = 327683,
        location = aptos_framework::object
    )]
    fun test_transfer_design_after_composed(
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
        object::transfer(account, design_obj, signer::address_of(other));
    }

    #[test(
        account = @admin,
        resource = @flex_token_coins,
        other = @234
    )]
    #[expected_failure(
        abort_code = 327683,
        location = aptos_framework::object
    )]
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
        resource = @flex_token_coins,
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

        assert!(coin_creator(coin_addr) == @flex_token_coins, 0);
        assert!(design_creator(design_addr) == @flex_token_coins, 1);
        assert!(
            coin_info(coin_addr) == 
            utf8(b"flex-coin||user-customizable-coin-00||coin-00||coin-00-url"), 
            2
        );
        assert!(
            design_info(design_addr) == 
            utf8(b"flex-coin-design-collection||coin-design-00||design-00||happy-birthdday||design-00-url"), 
            3
        );
        assert!(coin_collection_creator() == @flex_token_coins, 4);
        assert!(design_collection_creator() == @flex_token_coins, 5);
        assert!(
            coin_collection_info() ==
            utf8(b"user-customizable-coin||flex-coin||coin-collection-url"),
            6
        );
        assert!(
            design_collection_info() ==
            utf8(b"design-collection-for-user-customizable-coin||flex-coin-design-collection||design-collection-url"),
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
        resource = @flex_token_coins,
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
            &@flex_token_coins,
            &utf8(b"flex-coin"),
            &utf8(b"coin-00")
        );
        let coin_obj = object::address_to_object<Coin>(coin_addr);
        assert!(object::is_owner(coin_obj, addr), 0);
        assert!(token_objects_holder::holds(addr, coin_obj), 1);
        register(receiver);
        let receiver_addr = signer::address_of(receiver);
        transfer(account, coin_addr, receiver_addr);
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
            &@flex_token_coins,
            &utf8(b"flex-coin-design-collection"),
            &utf8(b"design-00")
        );
        let design_obj = object::address_to_object<Design>(design_addr);
        assert!(object::is_owner(design_obj, addr), 4);
        assert!(token_objects_holder::holds(addr, design_obj), 5);

        transfer(receiver, coin_addr, addr);
        compose(account, coin_addr, design_addr);
        assert!(object::is_owner(design_obj, coin_addr), 6);
        assert!(!token_objects_holder::holds(addr, design_obj), 7);
        
        transfer(account, coin_addr, receiver_addr);
        assert!(object::is_owner(design_obj, coin_addr), 8);
        assert!(!token_objects_holder::holds(receiver_addr, design_obj), 9);
        decompose(receiver, coin_addr, design_addr);
        assert!(object::is_owner(design_obj, receiver_addr), 10);
        assert!(token_objects_holder::holds(receiver_addr, design_obj), 11);
    }

    #[test(account = @admin, resource = @flex_token_coins)]
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

    #[test(account = @admin, resource = @flex_token_coins)]
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
        resource = @flex_token_coins,
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
        register_all(other);
        managed_transfer(account, coin, signer::address_of(other));
        compose_coin(account, coin, design);
    }

    #[test(
        account = @admin,
        resource = @flex_token_coins,
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
        resource = @flex_token_coins,
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
        register_all(other);
        managed_transfer(account, coin, signer::address_of(other));
        decompose_coin(account, coin, design);
    }

    #[test(account = @admin, resource = @flex_token_coins)]
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
        resource = @flex_token_coins,
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
        resource = @flex_token_coins,
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
        resource = @flex_token_coins,
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
        resource = @flex_token_coins,
        fake = @234    
    )]
    #[expected_failure]
    fun test_invalid_caller_decompose(
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
        compose_coin(account, coin, design);
        decompose_coin(fake, coin, design);
    }

    #[test(account = @admin, resource = @flex_token_coins)]
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

    #[test(account = @admin, resource = @flex_token_coins)]
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

    #[test(account = @admin, resource = @flex_token_coins)]
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

    #[test(account = @admin, resource = @flex_token_coins)]
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
