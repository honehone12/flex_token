module garage_token::token_objects_holder {
    use std::string::{Self, String};
    use aptos_framework::object::{Self, Object};

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct Token has key {
        attribute: String
    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct TokenObjectHolder<T: key> has key {
        tokens: vector<Object<T>>
    }
}