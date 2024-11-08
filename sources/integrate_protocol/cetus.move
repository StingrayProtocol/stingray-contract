module stingray::cetus{
    use sui::clock::Clock;
    use sui::balance::{Self, Balance};
    use sui::event::{Self};
    use std::{
        type_name::{Self, TypeName},
        string::{Self, String},
    };

    use cetus_clmm::config::GlobalConfig;
    use cetus_clmm::pool::{Self, Pool};

    use stingray::{
        fund:: { Take_1_Liquidity_For_2_Liquidity_Request,},
    };

    public struct Swap has copy, drop{
        protocol: String,
        input_coin_type: TypeName,
        input_amount: u64,
        output_coin_type: TypeName,
        output_amount: u64,
    }
    
    // To be noted: This function doesn't take care of slippage
    // To swap CoinX for CoinY, input the coin you are swapping in one of the args, and input zero balance for the coin you want to receive.
    public fun swap<TakeCoinType, PutCoinType1, PutCoinType2, X, Y>(
        request: &mut Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>,
        input_x: &mut Balance<X>,
        input_y: &mut Balance<Y>,
        config: &GlobalConfig,
        pool: &mut Pool<X, Y>,
        x2y: bool,
        by_amount_in: bool,
        clock: &Clock,
    ){
        let org_input_amount;
        let input_coin_type;
        
        if (input_x.value() == 0){
            org_input_amount = input_y.value();
            input_coin_type =type_name::get<Y>();
        }else{
            org_input_amount = input_x.value();
            input_coin_type =type_name::get<X>();
        };

        let amount = if(by_amount_in) input_x.value() else input_y.value();
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
        let curr_input_amount;
        
        if (input_x.value() < input_y.value()){
            output_amount = input_y.value();
            output_coin_type =type_name::get<Y>();
            curr_input_amount = input_x.value();
        }else{
            output_amount = input_x.value();
            output_coin_type =type_name::get<X>();
            curr_input_amount = input_y.value();
        };

        request.supported_defi_confirm_1l_for_2l(curr_input_amount,output_amount);
        
        event::emit(Swap{
            protocol: string::utf8(b"Cetus"),
            input_coin_type,
            input_amount: org_input_amount,
            output_coin_type,
            output_amount,
            } 
        );

    }

    public fun take_zero_balance<CoinType>(): Balance<CoinType>{
        balance::zero<CoinType>()
    }

    public fun drop_zero_balance<CoinType>(
        balance: Balance<CoinType>,
    ){
        balance.destroy_zero();
    }
    
}
