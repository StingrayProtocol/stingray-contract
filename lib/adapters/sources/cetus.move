module adapters::cetus{
    use sui::clock::Clock;
    use sui::balance::{Self, Balance};

    use cetus_clmm::config::GlobalConfig;
    use cetus_clmm::pool::{Self, Pool};
    
    // To be noted: This function doesn't take care of slippage
    // To swap CoinX for CoinY, input the coin you are swapping in one of the args, and input zero balance for the coin you want to receive.
    public fun swap<X, Y>(
        input_x: &mut Balance<X>,
        input_y: &mut Balance<Y>,
        config: &GlobalConfig,
        pool: &mut Pool<X, Y>,
        x2y: bool,
        by_amount_in: bool,
        clock: &Clock,
    ){
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
    }
}
