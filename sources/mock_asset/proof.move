module stingray::proof{

    public struct Proof has key{
        id: UID,
    }

    public(package) fun mint( 
        ctx: &mut TxContext,
    ) : Proof{

        Proof{
            id: object::new(ctx,)
        }
    }

    public(package) fun burn(
        proof: Proof,
    ){
        let Proof{
            id,
        } = proof;

        object::delete(id);
    }

}