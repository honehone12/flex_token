module flex_token_coins::royalties {
    use std::option::{Self, Option};
    use token_objects::royalty::{Self, Royalty};

    const ROYALTY_COLLECTION_NUMERATOR: u64 = 30;
    const ROYALTY_COIN_NUMERATOR: u64 = 10;
    const ROYALTY_DESIGN_NUMERATOR: u64 = 5;
    const ROYALTY_DENOMINATOR: u64 = 100;

    // collection is also object
    public fun create_collection_royalty(): Option<Royalty> {
        option::some(
            royalty::create(
                ROYALTY_COLLECTION_NUMERATOR,
                ROYALTY_DENOMINATOR,
                @admin
            )
        )
    }

    public fun create_coin_royalty(): Option<Royalty> {
        option::some(
            royalty::create(
                ROYALTY_COIN_NUMERATOR,
                ROYALTY_DENOMINATOR,
                @admin
            )
        )
    }

    public fun create_design_royalty(): Option<Royalty> {
        option::some(
            royalty::create(
                ROYALTY_DESIGN_NUMERATOR,
                ROYALTY_DENOMINATOR,
                @admin
            )
        )
    }
}