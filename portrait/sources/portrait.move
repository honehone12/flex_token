module garage_token::portrait {
    use std::string::{String, utf8};
    use aptos_framework::object::{Self, ObjectId};
    use token_objects::collection;
    use token_objects::token::{Self, MutabilityConfig};

    struct PortraitOnChainConfig has key {
        portrait_collection_name: String,
        portrait_mutability_config: MutabilityConfig,
        parts_collection_name: String,
        parts_mutability_config: MutabilityConfig
    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct PortraitBase has key {

    }

    #[resource_group_member(
        group = object::ObjectGroup
    )]
    struct Face has key {
        
    }
}