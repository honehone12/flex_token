// simple idea with move object model.
// "Coin" resource has fixed supply, so this is like NFTs
// that is reusable, and is tradable.
// "Design" resource does not have supply limitation, so
// this is like simply buy-able chat-stamps or game-items.

module garage_token::coins {
    use std::signer;
    use std::error;
    use std::option::{Self, Option};
    use std::string::{String, utf8};
    use aptos_framework::object::{Self, ObjectId};
    use token_objects::collection;
    use token_objects::token::{Self, MutabilityConfig};

    const E_NO_SUCH_COINS: u64 = 1;
    const E_NO_SUCH_DESIGN: u64 = 2;
    const E_INVALID_DESIGN: u64 = 3;
    const E_NOT_OWNER: u64 = 4; 

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
        design: Option<DesignObjectId> 
    }

    struct CoinObjectId has copy, drop {
        id: ObjectId
    }

    struct DesignObjectId has store, copy, drop {
        id: ObjectId
    }

    struct Design has key {
        attribute: String
    }

    public fun exists_coin(coin: &CoinObjectId): bool {
        exists<Coin>(object::object_id_address(&coin.id))
    }

    public fun exists_design(design: &DesignObjectId): bool {
        exists<Design>(object::object_id_address(&design.id))
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
            utf8(b"collection-uri")
        );
        _ = collection::create_aggregable_collection(
            caller,
            utf8(b"design-collection-for-user-customizable-coin"),
            collection::create_mutability_config(false, false),
            design_collection_name,
            option::none(),
            utf8(b"collection-uri")
        );
        let on_chain_config = CoinsOnChainConfig {
            coin_collection_name,
            coin_mutability_config: token::create_mutability_config(
                false, false, false
            ),
            design_collection_name,
            design_mutability_config: token::create_mutability_config(
                false, false, false
            )
        };
        move_to(caller, on_chain_config);
    }

    fun create_coin(
        creator: &signer,
        description: String,
        name: String,
        uri: String
    ): CoinObjectId
    acquires CoinsOnChainConfig {
        let on_chain_config = borrow_global<CoinsOnChainConfig>(
            signer::address_of(creator)
        );
        let creator_ref = token::create_token(
            creator,
            on_chain_config.coin_collection_name,
            description,
            on_chain_config.coin_mutability_config,
            name,
            option::none(),
            uri
        );
        let token_signer = object::generate_signer(&creator_ref);
        let coin = Coin{
            design: option::none()
        };
        move_to(&token_signer, coin);
        CoinObjectId{
            id: object::address_to_object_id(
                signer::address_of(&token_signer)
            )
        }
    }

    fun create_design(
        creator: &signer,
        description: String,
        name: String,
        attribute: String,
        uri: String,
    ): DesignObjectId
    acquires CoinsOnChainConfig {
        let on_chain_config = borrow_global<CoinsOnChainConfig>(
            signer::address_of(creator)
        );
        let creator_ref = token::create_token(
            creator,
            on_chain_config.design_collection_name,
            description,
            on_chain_config.design_mutability_config,
            name,
            option::none(),
            uri
        );
        let token_signer = object::generate_signer(&creator_ref);
        let design = Design{
            attribute
        };
        move_to(&token_signer, design);
        DesignObjectId{
            id: object::address_to_object_id(
               signer::address_of(&token_signer)
            )
        }
    }

    fun compose_coin(
        owner: &signer,
        coin: CoinObjectId,
        design: DesignObjectId
    )
    acquires Coin {
        assert!(
            exists_coin(&coin),
            error::not_found(E_NO_SUCH_COINS)
        );
        assert!(
            exists_design(&design),
            error::not_found(E_NO_SUCH_DESIGN)
        );
        let owner_addr = signer::address_of(owner);
        assert!(
            object::is_owner(coin.id, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        assert!(
            object::is_owner(design.id, owner_addr),
            error::permission_denied(E_NOT_OWNER)
        );

        let coin_obj = borrow_global_mut<Coin>(
            object::object_id_address(&coin.id)
        );
        option::fill(&mut coin_obj.design, design);
        object::transfer_to_object(
            owner,
            design.id,
            coin.id
        );
    }

    fun decompose_coin(
        owner: &signer,
        coin: CoinObjectId,
        design: DesignObjectId
    )
    acquires Coin {
        assert!(
            exists_coin(&coin),
            error::not_found(E_NO_SUCH_COINS)
        );
        let coin_obj_addr = object::object_id_address(&coin.id);
        let coin_obj = borrow_global_mut<Coin>(coin_obj_addr);
        assert!(
            object::is_owner(coin.id, signer::address_of(owner)),
            error::permission_denied(E_NOT_OWNER)
        );

        let stored_design = option::extract(&mut coin_obj.design);
        assert!(
            stored_design == design,
            error::invalid_argument(E_INVALID_DESIGN)
        );
        assert!(
            object::is_owner(design.id, coin_obj_addr),
            error::permission_denied(E_NOT_OWNER)
        );
        object::transfer(
            owner,
            design.id,
            signer::address_of(owner)
        );
    }

    #[test(account = @123)]
    fun test_coin_compose_decompose(account: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);

        let coin = create_coin(
            account,
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let design_birthday = create_design(
            account,
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")
        );
        let addr = signer::address_of(account);
        assert!(object::is_owner(coin.id, addr), 0);
        assert!(object::is_owner(design_birthday.id, addr), 1);

        let coin_obj_addr = object::object_id_address(&coin.id);
        compose_coin(account, coin, design_birthday);
        assert!(object::is_owner(coin.id, addr), 2);
        assert!(object::is_owner(design_birthday.id, coin_obj_addr), 3);
        
        decompose_coin(account, coin, design_birthday);
        assert!(object::is_owner(coin.id, addr), 4);
        assert!(object::is_owner(design_birthday.id, addr), 5);

        let design_graduation = create_design(
            account,
            utf8(b"coin-design-01"),
            utf8(b"design-01"),
            utf8(b"happy-graduation"),
            utf8(b"design-01-url")
        );
        assert!(object::is_owner(design_graduation.id, addr), 6);
        compose_coin(account, coin, design_graduation);
        assert!(object::is_owner(coin.id, addr), 7);
        assert!(object::is_owner(design_graduation.id, coin_obj_addr), 8);
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
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let design = create_design(
            account,
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")
        );
        compose_coin(account, coin, design);
        let recipient_addr = signer::address_of(other);
        object::transfer(account, coin.id, recipient_addr);
        assert!(object::is_owner(coin.id, recipient_addr), 0);
        assert!(object::is_owner(design.id, object::object_id_address(&coin.id)), 1);
    }

    #[test(account = @0x123)]
    #[expected_failure(
        abort_code = 0x60002,
        location = Self
    )]
    fun test_compose_invalid_design(account: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
        
        let coin = create_coin(
            account,
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let design = DesignObjectId{
            id: coin.id
        };
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
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let design = create_design(
            account,
            utf8(b"coin-design-01"),
            utf8(b"design-01"),
            utf8(b"happy-graduation"),
            utf8(b"design-01-url")
        );
        object::transfer(account, coin.id, signer::address_of(other));
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
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let design = create_design(
            account,
            utf8(b"coin-design-01"),
            utf8(b"design-01"),
            utf8(b"happy-graduation"),
            utf8(b"design-01-url")
        );
        object::transfer(account, design.id, signer::address_of(other));
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
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let design = create_design(
            account,
            utf8(b"coin-design-01"),
            utf8(b"design-01"),
            utf8(b"happy-graduation"),
            utf8(b"design-01-url")
        );
        compose_coin(account, coin, design);
        object::transfer(account, coin.id, signer::address_of(other));
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
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let design_birthday = create_design(
            account,
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")
        );
        compose_coin(account, coin, design_birthday);
        let design = DesignObjectId{
            id: coin.id
        };
        decompose_coin(account, coin, design);
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
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let _design = create_design(
            fake,
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")
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
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")
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
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let design = create_design(
            fake,
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")
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
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let design = create_design(
            fake,
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")
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
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let _coin2 = create_coin(
            account,
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );

    }

    #[test(account = @0x123)]
    #[expected_failure]
    fun test_create_twice_design(account: &signer)
    acquires CoinsOnChainConfig {
        init_module(account);
        let _design = create_design(
            account,
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")
        );
        let _design2 = create_design(
            account,
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")
        );
    }

    #[test(account = @0x123)]
    #[expected_failure]
    fun test_compose_twice(account: &signer)
    acquires CoinsOnChainConfig, Coin {
        init_module(account);
        
        let coin = create_coin(
            account,
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let design = create_design(
            account,
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")
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
            utf8(b"user-customizable-coin-00"),
            utf8(b"coin-00"),
            utf8(b"coin-00-url"),
        );
        let design = create_design(
            account,
            utf8(b"coin-design-00"),
            utf8(b"design-00"),
            utf8(b"happy-birthdday"),
            utf8(b"design-00-url")
        );
        compose_coin(account, coin, design);
        decompose_coin(account, coin, design);
        decompose_coin(account, coin, design);
    }
}