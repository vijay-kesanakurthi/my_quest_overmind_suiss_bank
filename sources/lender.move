/* 
    This quest features a portion of a simple lending protocol. This module provides the functionality
    for users to deposit and withdraw collateral, borrow and repay coins, and calculate their borrowing
    health factor. This lending protocol is based on the NAVI lending protocol on the Sui network. 

    Lending protocol: 
        A lending protocol is a smart contract system that allows users to lend and borrow coins. 
        Users can lend out their coins by supplying the liquidity pools, and can borrow coins from the
        liquidity pools. 

        This module is the basis for an overcollateralized lending protocol. This means that borrowers
        need to have lended more coins than they are borrowing. This is to ensure that the lenders are
        protected. 

    Depositing: 
        Lenders can deposit their coins to the liquidity pools at anytime with the deposit function.
    
    Withdrawing: 
        Lenders can withdraw the coins that they have lended out with the withdrawal function.

        In production, the withdrawal function should ensure that withdrawing their collateral does 
        not result in the user's health factor falling below a certain threshold. More on this below.

    Borrowing: 
        Borrowers can borrow coins from any available liquidity pools with the borrow function.

        In production, the borrowing function should ensure that the borrower has enough collateral 
        to cover the borrowed amount. Ensuring that the health factor of this use is above a certain 
        threshold after the borrowing is typically good practice. More on this below.

    Repaying: 
        Borrowers can repay coins they have borrowed with the repay function.

    Admin: 
        Only the admin is able to create new pools. Whoever holds the AdminCap capablity resource can
        use create_pool to create a pool for a new coin type. 

    Health factor: 
        To learn more about the health factor, please refer to Navi's documentation on health factors 
        here: https://naviprotocol.gitbook.io/navi-protocol-docs/getting-started/liquidations#what-is-the-health-factor

        Note that the health factor should be calculated with a decimal precision of 2. This means that
        a health factor of 1.34 should be represented as 134, and a health factor of 0.34 should be
        represented as 34.

        Example: 
            If a user has 1000 SUI as collateral and has borrowed 500 SUI, and the price of SUI is $1,
            the health factor of the user would be 1.6 (returned as 160). This is with a liquidation
            threshold of 80% (see below).

            if a user has 1000 SUI and 34000 USDC as collateral and has borrowed 14000 FUD, and the 
            price of SUI is $7.13, the price of USDC is $1, and the price of FUD is $2.20, the health 
            factor of the user would be 1.06 (returned as 106). This is with a liquidationthreshold 
            of 80% (see below).

    Liquidation threshold: 
        In production, each coin can have it's own liquidation threshold. These thresholds are considered
        when calculating the health factor of a user.

        In this module, the liquidation threshold is hardcoded to 80% for every coin. 

        More information on liquidation thresholds can be found in Navi's documentation here:
        https://naviprotocol.gitbook.io/navi-protocol-docs/getting-started/liquidations#liquidation-threshold

    Liquidation: 
        In production, if a user's health factor falls below the liquidation threshold, the user's 
        collateral is liquidated. This means that the user's collateral is sold off to repay the borrowed
        amount. 

        In this module, the liquidation function is not implemented as it is out of scope. However, 
        being able to calculate the health factor of user is a crucial part of the liquidation process.

    Price feed:
        This module uses a dummy oracle to get the price of each coin. In production, the price feed 
        should be a reliable source of the price of each coin. 

        The price feed is used to calculate the health factor of a user.

        The price and decimal precision of each coin can be fetched from the price feed with the 
        get_price_and_decimals function. The coin's asset number is used to fetch the price and
        decimal precision of the coin.

    Decimal precision: 
        When relating USD values of different coins, it is important to consider the decimal precision
        of each coin. This is because different coins have different decimal precisions. For this quest, 
        we assume that the decimal precision of each coin is between 0 and 9 (inclusive).

        The decimal precision of each coin is fetched from the price feed with the get_price_and_decimals
        function.
*/
module quest_overmind::lending {
    //==============================================================================================
    // Dependencies
    //==============================================================================================
    use sui::math;
    use sui::transfer;
    use quest_overmind::dummy_oracle;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};

    //==============================================================================================
    // Constants - Add your constants here (if any)
    //==============================================================================================

    //==============================================================================================
    // Error codes - DO NOT MODIFY
    //==============================================================================================
    
    //==============================================================================================
    // Module Structs - DO NOT MODIFY
    //==============================================================================================

    /*
        This is the capability resource that is used to create new pools. The AdminCap should be created
        and transferred to the publisher of the protocol.
    */
    struct AdminCap has key, store {
        id: UID,
    }

    /*
        This is the state of the protocol. It contains the number of pools and the users of the protocol.
        This should be created and shared globally when the protocol is initialized.
    */
    struct ProtocolState has key {
        id: UID, 
        number_of_pools: u64, // The number of pools in the protocol. Default is 0.
        users: Table<address, UserData> // All user data of the protocol.
    }

    /*
        This is the pool resource. It contains the asset number of the pool, and the reserve of the pool.
        When a pool is created, it should be shared globally.
    */
    struct Pool<phantom CoinType> has key {
        id: UID, 
        /* 
            The asset number of the pool. This aligns with the index of collateral and borrow amounts in 
            the user data. This is also used to fetch the price and decimal precision of the coin from
            the price feed with the dummy_oracle::get_price_and_decimals function.
        */
        asset_number: u64, 
        /*
            The reserve of the pool. This is the total amount of the coin in the pool that are 
            available for borrowing or withdrawing.
        */
        reserve: Balance<CoinType>
    }

    /* 
        This is the user data resource. It contains the collateral and borrowed amounts of the user.
    */
    struct UserData has store {
        /* 
            The amount of collateral the user has in each pool. the index of the collateral amount
            aligns with the asset number of the pool.
        */
        collateral_amount: Table<u64, u64>, 
        /* 
            The amount of coins the user has borrowed in each pool. the index of the borrowed amount
            aligns with the asset number of the pool.
        */
        borrowed_amount: Table<u64, u64>,
    }

    //==============================================================================================
    // Functions
    //==============================================================================================

    /*
        Initializes the protocol by creating the admin capability and the protocol state.
    */
    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, sender);

        let users = table::new<address, UserData>(ctx);

        transfer::share_object(ProtocolState{
            id: object::new(ctx),
            number_of_pools: 0,
            users,
        });
    }

    /*
        Creates a new pool for a new coin type. This function can only be called by the admin.
    */
    public fun create_pool<CoinType>(
        _: &mut AdminCap,
        state: &mut ProtocolState,
        ctx: &mut TxContext
    ) {
        transfer::share_object(Pool{
            id: object::new(ctx),
            asset_number: state.number_of_pools,
            reserve: balance::zero<CoinType>(),
        });

        state.number_of_pools = state.number_of_pools + 1;
    }

    /*
        Deposits a coin to a pool. This function increases the user's collateral amount in the pool
        and adds the coin to the pool's reserve.
    */
    public fun deposit<CoinType>(
        coin_to_deposit: Coin<CoinType>,
        pool: &mut Pool<CoinType>,
        state: &mut ProtocolState,
        ctx: &mut TxContext
    ) { 
        let coin_to_deposit_balance = coin::into_balance(coin_to_deposit);
        let value = balance::value(&coin_to_deposit_balance);
        balance::join(&mut pool.reserve, coin_to_deposit_balance);

        let sender = tx_context::sender(ctx);

        if (table::contains(&state.users, sender)) {
            let userData = table::borrow_mut(&mut state.users, sender);

            if (table::contains(&userData.collateral_amount, pool.asset_number)) {
                let amount = table::borrow_mut(&mut userData.collateral_amount, 
                    pool.asset_number);
                *amount = *amount + value;
            } else {
                table::add(&mut userData.collateral_amount, pool.asset_number, value);
            }
        } else {
            let collateral_amount = table::new<u64, u64>(ctx);
            let borrowed_amount = table::new<u64, u64>(ctx);
            table::add(&mut collateral_amount, pool.asset_number, value);

            let userData = UserData{
                collateral_amount,
                borrowed_amount,
            };

            table::add(&mut state.users, sender, userData);
        }
    }

    /*
        Withdraws a coin from a pool. This function decreases the user's collateral amount in the pool
        and removes the coin from the pool's reserve.
    */
    public fun withdraw<CoinType>(
        amount_to_withdraw: u64, 
        pool: &mut Pool<CoinType>,
        state: &mut ProtocolState,
        ctx: &mut TxContext
    ): Coin<CoinType> {

        let sender = tx_context::sender(ctx);

        let real_amount_to_withdraw = 0;

        if (table::contains(&state.users, sender)) {

            let userData = table::borrow_mut(&mut state.users, sender);

            if (table::contains(&userData.collateral_amount, pool.asset_number)) {
                let amount = table::borrow_mut(&mut userData.collateral_amount, pool.asset_number);

                assert!(*amount >= amount_to_withdraw, 1);

                *amount = *amount - amount_to_withdraw;

                real_amount_to_withdraw = amount_to_withdraw;
            }
        };

        let amount_to_withdraw_balance = balance::split(
            &mut pool.reserve, real_amount_to_withdraw);

        coin::from_balance(amount_to_withdraw_balance, ctx)
    }

    /*
        Borrows a coin from a pool. This function increases the user's borrowed amount in the pool
        and removes and returns the coin from the pool's reserve.
    */
    public fun borrow<CoinType>(
        amount_to_borrow: u64, 
        pool: &mut Pool<CoinType>,
        state: &mut ProtocolState,
        ctx: &mut TxContext
    ): Coin<CoinType> {

         let sender = tx_context::sender(ctx);

         let real_amount_to_borrow = 0;

         if (table::contains(&state.users, sender)) {
            let userData = table::borrow_mut(&mut state.users, sender);

            if (table::contains(&userData.borrowed_amount, pool.asset_number)) {
                let amount = table::borrow_mut(&mut userData.borrowed_amount, pool.asset_number);
                *amount = *amount + amount_to_borrow
            } else {
                table::add(&mut userData.borrowed_amount, pool.asset_number, amount_to_borrow);
            };

            real_amount_to_borrow = amount_to_borrow;
         };

         let amount_to_borrow_balance = balance::split(
            &mut pool.reserve, real_amount_to_borrow);

         coin::from_balance(amount_to_borrow_balance, ctx)
    }

    /*
        Repays a coin to a pool. This function decreases the user's borrowed amount in the pool
        and adds the coin to the pool's reserve.
    */
    public fun repay<CoinType>(
        coin_to_repay: Coin<CoinType>,
        pool: &mut Pool<CoinType>,
        state: &mut ProtocolState,
        ctx: &mut TxContext
    ) {

        let sender = tx_context::sender(ctx);
        let coin_to_repay_balance = coin::into_balance(coin_to_repay);
        let value = balance::value(&coin_to_repay_balance);
        balance::join(&mut pool.reserve, coin_to_repay_balance);

        if (table::contains(&state.users, sender)) {
            let userData = table::borrow_mut(&mut state.users, sender);

            if (table::contains(&userData.borrowed_amount, pool.asset_number)) {
                let amount = table::borrow_mut(
                    &mut userData.borrowed_amount, pool.asset_number);

                assert!(*amount >= value, 2);
                *amount = *amount - value;
            }
        };
    }

    /*  
        Calculates the health factor of a user. The health factor is the ratio of the user's collateral
        to the user's borrowed amount. The health factor is calculated with a decimal precision of 2. 
        This means that a health factor of 1.34 should be represented as 134, and a health factor of 0.34
        should be represented as 34.

        See above for more information on how to calculate the health factor.
    */
    public fun calculate_health_factor(
        user: address,
        state: &ProtocolState,
        price_feed: &dummy_oracle::PriceFeed
    ): u64 {
        let collateral_total_amount = 0;
        let borrowed_total_amount = 0;

        if (table::contains(&state.users, user)) {

            let userData = table::borrow(&state.users, user);

            let i = 0;
            while(i < state.number_of_pools) {

                let (price, decimals) = dummy_oracle::get_price_and_decimals(i, price_feed);

                if (table::contains(&userData.collateral_amount, i)) {
                    let amount = table::borrow(&userData.collateral_amount, i);
                    collateral_total_amount = collateral_total_amount + *amount / math::pow(10, decimals) * price ;
                };

                if (table::contains(&userData.borrowed_amount, i)) {
                    let amount = table::borrow(&userData.borrowed_amount, i);
                    borrowed_total_amount = borrowed_total_amount + *amount / math::pow(10, decimals) * price;
                };

                i = i+1;
            }
        };

        assert!(borrowed_total_amount != 0, 3);

        collateral_total_amount * 80 / borrowed_total_amount
    }

    public fun get_number_of_pools(state: &ProtocolState): u64 {
        state.number_of_pools
    }

    public fun get_users(state: &ProtocolState): &Table<address, UserData> {
        &state.users
    }

    public fun get_pool_reserve<CoinType>(pool: &Pool<CoinType>): &Balance<CoinType>{
        &pool.reserve
    }

    public fun get_user_data_borrowed_amount(data: &UserData): &Table<u64, u64> {
        &data.borrowed_amount
    }

    public fun get_user_data_collateral_amount(data: &UserData): &Table<u64, u64> {
        &data.collateral_amount
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(ctx)
    }
}

module quest_overmind::dummy_oracle {

    //==============================================================================================
    // Dependencies
    //==============================================================================================
    use std::vector;
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    struct PriceFeed has key {
        id: UID, 
        prices: vector<u64>,
        decimals: vector<u8>
    }

    public fun init_module(ctx: &mut TxContext) {
        transfer::share_object(
            PriceFeed {
                id: object::new(ctx),
                prices: vector::empty(),
                decimals: vector::empty()
            }
        );
    }

    public fun add_new_coin(
        price: u64,
        decimals: u8,
        feed: &mut PriceFeed
    ) {
        vector::push_back(&mut feed.prices, price);
        vector::push_back(&mut feed.decimals, decimals);
    }

    public fun update_price(
        new_price: u64,
        coin_number: u64,
        feed: &mut PriceFeed
    ) {
        let existing_price = vector::borrow_mut(&mut feed.prices, coin_number);
        *existing_price = new_price;
    }

    public fun get_price_and_decimals(
        coin_number: u64,
        feed: &PriceFeed
    ): (u64, u8) {
        (*vector::borrow(&feed.prices, coin_number), *vector::borrow(&feed.decimals, coin_number))
    }
}