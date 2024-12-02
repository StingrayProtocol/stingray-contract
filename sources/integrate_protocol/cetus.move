module stingray::cetus{

    use sui::{
        clock::Clock,
        balance::{Self, Balance},
        event::{Self},
    };
    
    use std::{
        type_name::{Self, TypeName},
        string::{Self, String},
    };

    use cetus_clmm::{
        config::GlobalConfig,
        pool::{Self, Pool},
        position::{Position},
    };

    use stingray::{
        fund:: { 
            Take_1_Liquidity_For_1_Liquidity_Request, 
            Take_2_Liquidity_For_1_NonLiquidity_Request,
            Take_1_NonLiquidity_For_2_Liquidity_Request},
    };

    public struct Swap has copy, drop{
        protocol: String,
        fund: ID,
        input_coin_type: TypeName,
        input_amount: u64,
        output_coin_type: TypeName,
        output_amount: u64,
    }
    
    // To be noted: This function doesn't take care of slippage
    // To swap CoinX for CoinY, input the coin you are swapping in one of the args, and input zero balance for the coin you want to receive.
    public fun swap<TakeCoinType, PutCoinType, X, Y>(
        request: &mut Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>,
        input_x: &mut Balance<X>,
        input_y: &mut Balance<Y>,
        config: &GlobalConfig,
        pool: &mut Pool<X, Y>,
        x2y: bool,
        by_amount_in: bool,
        clock: &Clock,
    ){
        let input_amount;
        let input_coin_type;
        
        if (input_x.value() == 0){
            input_amount = input_y.value();
            input_coin_type =type_name::get<Y>();
        }else{
            input_amount = input_x.value();
            input_coin_type =type_name::get<X>();
        };

        let amount = if(x2y) input_x.value() else input_y.value();
        let sqrt_price_limit = if(x2y) 4295048016_u128 else 79226673515401279992447579055_u128;
        let (receive_x, receive_y, flash_receipt) = pool::flash_swap<X, Y>(
            config,
            pool,
            x2y,
            by_amount_in,
            amount,
            sqrt_price_limit,
            clock
        );
        let (in_amount, _out_amount) = (
            flash_receipt.swap_pay_amount(),
            if (x2y) receive_x.value() else receive_y.value()
        );

        // pay for flash swap
        let (repaid_x, repaid_y) = if (x2y) {
            (input_x.split(in_amount), balance::zero<Y>())
        } else {
            (balance::zero<X>(), input_y.split(in_amount))
        };

        pool::repay_flash_swap<X, Y>(
            config,
            pool,
            repaid_x,
            repaid_y,
            flash_receipt
        );

        input_x.join(receive_x);
        input_y.join(receive_y);


        let output_amount;
        let output_coin_type;
        
        if (input_x.value() < input_y.value()){
            output_amount = input_y.value();
            output_coin_type =type_name::get<Y>();
        }else{
            output_amount = input_x.value();
            output_coin_type =type_name::get<X>();
        };

        request.supported_defi_confirm_1l_for_1l(output_amount);
        
        event::emit(Swap{
            protocol: string::utf8(b"Cetus"),
            fund: request.fund_id_of_1l_for_1l_req(),
            input_coin_type,
            input_amount: input_amount,
            output_coin_type,
            output_amount,
            } 
        );
    }

    public fun open_position_and_add_liquidity<TakeCoinType1, TakeCoinType2, PutAsset, X, Y>(
        request: &mut Take_2_Liquidity_For_1_NonLiquidity_Request<TakeCoinType1, TakeCoinType2, PutAsset>,
        input_x: Balance<X>,
        input_y: Balance<Y>,
        config: &GlobalConfig,
        pool: &mut Pool<X, Y>,
        tick_lower: u32,
        tick_upper: u32,
        delta_liquidity: u128,
        clock: &Clock,
        ctx: &mut TxContext
    ): Position{
        let mut position_nft = pool::open_position(
            config,
            pool,
            tick_lower,
            tick_upper,
            ctx,
        );
        
        let receipt = pool::add_liquidity<X, Y>(
            config,
            pool,
            &mut position_nft,
            delta_liquidity,
            clock
        );
        pool::repay_add_liquidity(config, pool, input_x, input_y, receipt);

        request.supported_defi_confirm_2l_for_1nl(1);

        position_nft
    }

    public fun close_position_and_remove_liquidity<TakeAsset: store , PutCoinType1, PutCoinType2, X, Y>(
        request: &mut Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>,
        config: &GlobalConfig,
        pool: &mut Pool<X, Y>,
        mut position_nft: Position,
        delta_liquidity: u128,
        clock: &Clock,
    ): (Balance<X>, Balance<Y>){

        let (mut balance_a, mut balance_b) = pool::remove_liquidity<X, Y>(
            config,
            pool,
            &mut position_nft,
            delta_liquidity,
            clock
        );

        let (fee_a, fee_b) = pool::collect_fee(
            config,
            pool,
            &position_nft,
            false
        );

        // you can implentment these methods by yourself methods.
        balance_a.join(fee_a);
        balance_b.join(fee_b);

        pool::close_position<X, Y>(config, pool, position_nft);

        request.supported_defi_confirm_1nl_for_2l<TakeAsset, PutCoinType1, PutCoinType2>(balance_a.value(), balance_b.value());

       ( balance_a, balance_b)


    }

    public fun take_zero_balance<CoinType>(): Balance<CoinType>{
        balance::zero<CoinType>()
    }

    public fun drop_zero_balance<CoinType>(
        balance: Balance<CoinType>,
    ){
        balance.destroy_zero();
    }

    public fun get_position_liquidity(
        position_nft: &Position,
    ): u128{
        position_nft.liquidity()
    }
    
}
