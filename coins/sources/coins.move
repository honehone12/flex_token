// now only module owner can mint,
// need to publish to resource account

module flex_token::coins {
    use std::signer;
    use std::error;
    use std::option::{Self, Option};
    use std::string::{Self, String, utf8};
    use aptos_framework::object::{Self, Object};
    use token_objects::collection;
    use token_objects::token::{Self, MutabilityConfig};
    use flex_token::token_objects_holder;

    const E_NO_SUCH_COINS: u64 = 1;
    const E_NO_SUCH_DESIGN: u64 = 2;
    const E_INVALID_DESIGN: u64 = 3;
    const E_NOT_OWNER: u64 = 4; 
    const E_TOO_LONG_INPUT: u64 = 5;

    const MAX_NMAE: u64 = 64;
    const MAX_DESC: u64 = 128;
    const MAX_URL: u64 = 128;

    struct CoinsOnChainConfig has key {
        coin_collection_name: String,
        coin_mutability_config: MutabilityConfig,
        design_collection_name: String,
        design_mutability_config: MutabilityConfig 
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
        attribute: String
    }

    fun init_module(caller: &signer) {
        //want object root ??
        // -root
        //  -coin
        //  -design

        let coin_collection_name = utf8(b"garage-coin");
        let design_collection_name = utf8(b"garage-coin-design-collection");
        _ = collection::create_fixed_collection(
            caller,
            utf8(b"user-customizable-coin"),
            1000_000,
            collection::create_mutability_config(false, false),
            coin_collection_name,
            option::none(),
            utf8(b"coin-collection-url")
        );
        _ = collection::create_aggregable_collection(
            caller,
            utf8(b"design-collection-for-user-customizable-coin"),
            collection::create_mutability_config(false, false),
            design_collection_name,
            option::none(),
            utf8(b"design-collection-url")
        );
        move_to(
            caller, 
            CoinsOnChainConfig {
                coin_collection_name,
                coin_mutability_config: token::create_mutability_config(
                    false, false, false
                ),
                design_collection_name,
                design_mutability_config: token::create_mutability_config(
                    false, false, false
                )
            }
        );
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
        assert!(
            string::length(description) <= MAX_DESC &&
            string::length(name) <= MAX_NMAE &&
            string::length(uri) <= MAX_URL,
            error::invalid_argument(E_TOO_LONG_INPUT)
        );

        let creator_addr = signer::address_of(creator); 
        let on_chain_config = borrow_global<CoinsOnChainConfig>(
            creator_addr
        );
        let creator_ref = token::create_token(
            creator,
            on_chain_config.coin_collection_name,
            *description,
            on_chain_config.coin_mutability_config,
            *name,
            option::none(),
            *uri
        );
        let token_signer = object::generate_signer(&creator_ref);
        move_to(
            &token_signer, 
            Coin{
                design: option::none()
            }
        );
        let obj = object::address_to_object(signer::address_of(&token_signer));
        token_objects_holder::register<Coin>(creator);
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
            string::length(name) <= MAX_NMAE &&
            string::length(uri) <= MAX_URL,
            error::invalid_argument(E_TOO_LONG_INPUT)
        );
        
        let creator_addr = signer::address_of(creator);
        let on_chain_config = borrow_global<CoinsOnChainConfig>(
            creator_addr
        );
        let creator_ref = token::create_token(
            creator,
            on_chain_config.design_collection_name,
            *description,
            on_chain_config.design_mutability_config,
            *name,
            option::none(),
            *uri
        );
        let token_signer = object::generate_signer(&creator_ref);
        move_to(
            &token_signer,
            Design{
                attribute: *design_attribute
            }
        );
        let obj = object::address_to_object(signer::address_of(&token_signer));
        token_objects_holder::register<Design>(creator);
        token_objects_holder::add_to_holder(creator_addr, obj);
        obj
    }

    public entry fun register(account: &signer) {
        token_objects_holder::register<Coin>(account);
        token_objects_holder::register<Design>(account);
    }

    public entry fun transfer(
        owner: &signer,
        coin_address: address,
        receiver: address 
    ) {
        let coin_obj = object::address_to_object<Coin>(coin_address);
        transfer_coin(owner, coin_obj, receiver);
    }

    fun transfer_coin(
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
    acquires Coin {
        let coin_obj =  object::address_to_object<Coin>(coin_address);
        let design_obj = object::address_to_object<Design>(design_address);
        compose_coin(owner, coin_obj, design_obj);
    }

    fun compose_coin(
        owner: &signer,
        coin_obj: Object<Coin>,
        design_obj: Object<Design>
    )
    acquires Coin {
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
        option::fill(&mut coin.design, design_obj);
        object::transfer_to_object(owner, design_obj, coin_obj);
        token_objects_holder::remove_from_holder(owner, design_obj);
    }

    public entry fun decompose(
        owner: &signer,
        coin_address: address,
        design_address: address
    )
    acquires Coin {
        let coin_obj = object::address_to_object(coin_address);
        let design_obj = object::address_to_object(design_address);
        decompose_coin(owner, coin_obj, design_obj);
    }

    fun decompose_coin(
        owner: &signer,
        coin_obj: Object<Coin>,
        design_obj: Object<Design>
    )
    acquires Coin {
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
        object::transfer(owner, design_obj, owner_addr);
        token_objects_holder::add_to_holder(owner_addr, design_obj);
    }

    #[test(
        account = @123,
        receiver = @234
    )]
    fun test_entry(account: &signer, receiver: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
        mint_coin(
            account,
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
            
        );
        let addr = signer::address_of(account);
        let coin_addr = token::create_token_address(
            &addr,
            &utf8(b"garage-coin"),
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
            &addr,
            &utf8(b"garage-coin-design-collection"),
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

    #[test(account = @123)]
    fun test_coin_compose_decompose(account: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);

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
        account = @123, 
        other = @0x234
    )]
    fun test_transfer(account: &signer, other: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);

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

    #[test(account = @0x123)]
    #[expected_failure]
    fun test_compose_not_exist_design(account: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
        
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
        account = @0x123,
        other = @0x234
    )]
    #[expected_failure(
        abort_code = 0x50004,
        location = Self
    )]
    fun test_compose_not_owner_coin(account: &signer, other: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
        
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
        account = @0x123,
        other = @0x234
    )]
    #[expected_failure(
        abort_code = 0x50004,
        location = Self
    )]
    fun test_compose_not_owner_design(account: &signer, other: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
        
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
        object::transfer(account, design, signer::address_of(other));
        compose_coin(account, coin, design);
    }

    #[test(
        account = @0x123,
        other = @0x234
    )]
    #[expected_failure(
        abort_code = 0x50004,
        location = Self
    )]
    fun test_decompose_not_owner_coin(account: &signer, other: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
        
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

    #[test(account = @0x123)]
    #[expected_failure(
        abort_code = 0x10003,
        location = Self
    )]
    fun test_decompose_invalid_design(account: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
        
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
        account = @0x123,
        fake = @234    
    )]
    #[expected_failure]
    fun test_invalid_caller_coin(account: &signer, fake: &signer)
    acquires CoinsOnChainConfig {
        init_module(account);
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
        account = @0x123,
        fake = @234    
    )]
    #[expected_failure]
    fun test_invalid_caller_design(account: &signer, fake: &signer)
    acquires CoinsOnChainConfig {
        init_module(account);
        let _design = create_design(
            fake,
            &utf8(b"coin-design-00"),
            &utf8(b"design-00"),
            &utf8(b"happy-birthdday"),
            &utf8(b"design-00-url")
        );
    }

    #[test(
        account = @0x123,
        fake = @234    
    )]
    #[expected_failure]
    fun test_invalid_caller_compose(account: &signer, fake: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
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
        account = @0x123,
        fake = @234    
    )]
    #[expected_failure]
    fun test_invalid_caller_decompose(account: &signer, fake: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
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

    #[test(account = @0x123)]
    #[expected_failure]
    fun test_create_twice_coin(account: &signer)
    acquires CoinsOnChainConfig {
        init_module(account);
        
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

    #[test(account = @0x123)]
    #[expected_failure]
    fun test_create_twice_design(account: &signer)
    acquires CoinsOnChainConfig {
        init_module(account);
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

    #[test(account = @0x123)]
    #[expected_failure]
    fun test_compose_twice(account: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
        
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

    #[test(account = @0x123)]
    #[expected_failure]
    fun test_decompose_twice(account: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
        
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