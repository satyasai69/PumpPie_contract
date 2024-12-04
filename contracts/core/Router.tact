import "@stdlib/deploy";
import "@stdlib/ownable";
import "./Factory";
import "./Pool";

// Messages for router operations
message BuyTokensRoute {
    tokenAddress: Address;  // Address of the token to buy
    minTokensToReceive: Int;  // Minimum amount of tokens to receive
}

message SellTokensRoute {
    tokenAddress: Address;  // Address of the token to sell
    amount: Int;  // Amount of tokens to sell
    minTonToReceive: Int;  // Minimum amount of TON to receive
}

contract Router with Deployable, Ownable {
    factory: Address;  // Factory contract address
    owner: Address;  // Owner of the router
    
    init(factory: Address) {
        self.factory = factory;
        self.owner = sender();
    }

    // Buy tokens through the pool
    receive(msg: BuyTokensRoute) {
        // Get pool address from factory
        let factoryContract: Factory = Factory.fromAddress(self.factory);
        let poolAddress: Address? = factoryContract.getPool(msg.tokenAddress);
        require(poolAddress != null, "Pool not found for token");

        // Calculate amount based on sent TON
        let amountToSend: Int = context().value - ton("0.1"); // Reserve some TON for gas
        require(amountToSend > 0, "Not enough TON sent");

        // Forward buy request to pool
        send(SendParameters{
            to: poolAddress!!,
            value: amountToSend,
            mode: SendIgnoreErrors,
            body: BuyTokens{
                tokenAmount: msg.minTokensToReceive
            }.toCell()
        });
    }

    // Sell tokens through the pool
    receive(msg: SellTokensRoute) {
        // Get pool address from factory
        let factoryContract: Factory = Factory.fromAddress(self.factory);
        let poolAddress: Address? = factoryContract.getPool(msg.tokenAddress);
        require(poolAddress != null, "Pool not found for token");

        // Forward sell request to pool
        send(SendParameters{
            to: poolAddress!!,
            value: context().value,
            mode: SendIgnoreErrors,
            body: SellTokens{
                amount: msg.amount,
                from: sender()
            }.toCell()
        });
    }

    // Getter for factory address
    get fun getFactory(): Address {
        return self.factory;
    }

    // Getter for owner address
    get fun getOwner(): Address {
        return self.owner;
    }

    // Function to calculate token amount from TON amount (optional helper)
    get fun calculateTokenAmount(tokenAddress: Address, tonAmount: Int): Int {
        let factoryContract: Factory = Factory.fromAddress(self.factory);
        let poolAddress: Address? = factoryContract.getPool(tokenAddress);
        require(poolAddress != null, "Pool not found for token");
        
        let pool: Pool = Pool.fromAddress(poolAddress!!);
        return pool.calculateCost(pool.getTokenSupply(), tonAmount);
    }
}