module flex_token_coins::events {
    use std::option::Option;
    struct TransferEvent has drop, store {
        from: address,
        to: address,
        coin: address,
        design: Option<address>
    }

    public fun create_transfer_event(
        from: address,
        to: address,
        coin: address,
        design: Option<address>
    ): TransferEvent {
        TransferEvent{
            from,
            to,
            coin,
            design
        }
    }
}