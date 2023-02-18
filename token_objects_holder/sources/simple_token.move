module garage_token::simple_token {
    use std::string::{String};
    use aptos_framework::object;
    use garage_token::token_objects_holder::{TokenObjectsHolder};

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct SimpleToken has key {
        attribute: String
    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct SimpleTokenHolder has key {
        simple_tokens: TokenObjectsHolder<SimpleToken>
    }
}